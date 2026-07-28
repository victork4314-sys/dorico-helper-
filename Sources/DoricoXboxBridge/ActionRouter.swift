#if os(macOS)
import AppKit
import ApplicationServices
import Foundation
import DoricoBridgeCore

@MainActor
final class ActionRouter {
    private let detector: DoricoDetector
    private let accessibility: DoricoAccessibility
    private let midi: VirtualMIDI
    private weak var model: AppModel?

    init(detector: DoricoDetector, accessibility: DoricoAccessibility, midi: VirtualMIDI, model: AppModel) {
        self.detector = detector
        self.accessibility = accessibility
        self.midi = midi
        self.model = model
    }

    func execute(_ action: CommandAction) async {
        do {
            try await executeThrowing(action)
        } catch {
            model?.captureMessage = error.localizedDescription
            model?.log("Action failed: \(error.localizedDescription)")
        }
    }

    private func executeThrowing(_ action: CommandAction) async throws {
        switch action {
        case .internalCommand(let command):
            model?.handleInternal(command)
            if model?.dashboardVisible == true {
                accessibility.hideFocusSelector()
            }
        case .controllerText(let route):
            guard let model else { return }
            accessibility.hideFocusSelector()
            DoricoTextRouteCoordinator.shared.begin(route, model: model)
        case .pointer(let operation):
            performPointer(operation)
        case .midiPulse(let address):
            guard prepareDoricoTarget() else { throw RouterError.doricoNotRunning }
            if address == BridgeDynamicMIDI.placeSelectedNote {
                let selected = NoteEntryState.shared
                midi.sendPulse(selected.midiAddress)
                model?.lastAction = "Place note \(selected.displayName)"
                model?.log("Placed selected note \(selected.displayName)")
            } else if address == BridgeDynamicMIDI.pitchUp {
                NoteEntryState.shared.move(1)
                KeyEmitter.send(KeyChord("up"))
                model?.lastAction = "Pitch up to \(NoteEntryState.shared.displayName)"
                await refreshFocusSelectorAfterDoricoAction()
            } else if address == BridgeDynamicMIDI.pitchDown {
                NoteEntryState.shared.move(-1)
                KeyEmitter.send(KeyChord("down"))
                model?.lastAction = "Pitch down to \(NoteEntryState.shared.displayName)"
                await refreshFocusSelectorAfterDoricoAction()
            } else {
                midi.sendPulse(address)
            }
        case .keyChord(let chord):
            guard prepareDoricoTarget() else { throw RouterError.doricoNotRunning }
            KeyEmitter.send(chord)
            await refreshFocusSelectorAfterDoricoAction()
        case .typeText(let text):
            if let routedAction = DoricoTextRouteCoordinator.shared.consumeAction(for: text) {
                try await executeThrowing(routedAction)
                return
            }
            guard prepareDoricoTarget() else { throw RouterError.doricoNotRunning }
            KeyEmitter.type(text)
        case .menuPath(let path):
            guard prepareDoricoTarget() else { throw RouterError.doricoNotRunning }
            try accessibility.performMenuPath(path, detector: detector)
            await refreshFocusSelectorAfterDoricoAction(delayMilliseconds: 90)
        case .accessibility(let operation):
            guard prepareDoricoTarget() else { throw RouterError.doricoNotRunning }
            try accessibility.perform(operation, detector: detector)
        case .sequence(let steps):
            for step in steps {
                if step.delayMilliseconds > 0 {
                    try? await Task.sleep(for: .milliseconds(step.delayMilliseconds))
                }
                try await executeThrowing(step.action)
            }
        case .none:
            break
        }
    }

    private func refreshFocusSelectorAfterDoricoAction(delayMilliseconds: UInt64 = 65) async {
        try? await Task.sleep(for: .milliseconds(delayMilliseconds))
        try? accessibility.refreshFocusSelector(detector: detector)
    }

    private func prepareDoricoTarget() -> Bool {
        guard detector.runningApplication() != nil else { return false }
        if model?.activeProfile.settings.onlyWhenDoricoFrontmost == true {
            return detector.isFrontmost()
        }
        if !detector.isFrontmost() {
            _ = detector.activate()
            RunLoop.current.run(until: Date().addingTimeInterval(0.04))
        }
        return true
    }

    private func performPointer(_ operation: PointerOperation) {
        switch operation {
        case .toggle:
            model?.setPointerMode(!(model?.pointerMode ?? false))
        case .move(let dx, let dy):
            let scale = (model?.activeProfile.settings.pointerSpeed ?? 18) / 18
            let current = CGEvent(source: nil)?.location ?? .zero
            let target = CGPoint(x: current.x + dx * scale, y: current.y - dy * scale)
            CGWarpMouseCursorPosition(target)
        case .scroll(let dx, let dy):
            let event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2, wheel1: Int32(dy), wheel2: Int32(dx), wheel3: 0)
            event?.post(tap: .cghidEventTap)
        case .leftClick:
            click(button: .left, count: 1)
        case .rightClick:
            click(button: .right, count: 1)
        case .doubleClick:
            click(button: .left, count: 2)
        }
    }

    private func click(button: CGMouseButton, count: Int64) {
        let location = CGEvent(source: nil)?.location ?? .zero
        let downType: CGEventType = button == .right ? .rightMouseDown : .leftMouseDown
        let upType: CGEventType = button == .right ? .rightMouseUp : .leftMouseUp
        let down = CGEvent(mouseEventSource: nil, mouseType: downType, mouseCursorPosition: location, mouseButton: button)
        let up = CGEvent(mouseEventSource: nil, mouseType: upType, mouseCursorPosition: location, mouseButton: button)
        down?.setIntegerValueField(.mouseEventClickState, value: count)
        up?.setIntegerValueField(.mouseEventClickState, value: count)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    enum RouterError: LocalizedError {
        case doricoNotRunning
        var errorDescription: String? { "Dorico Pro is not running or is not frontmost" }
    }
}

private enum KeyEmitter {
    static func send(_ chord: KeyChord) {
        guard let code = keyCode(for: chord.key) else { return }
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)
        let flags = eventFlags(for: chord.modifiers)
        down?.flags = flags
        up?.flags = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    static func type(_ text: String) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let units = Array(text.utf16)
        let unitCount = units.count
        let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        units.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            down?.keyboardSetUnicodeString(stringLength: unitCount, unicodeString: base)
            up?.keyboardSetUnicodeString(stringLength: unitCount, unicodeString: base)
        }
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private static func eventFlags(for modifiers: Set<KeyModifier>) -> CGEventFlags {
        var flags: CGEventFlags = []
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        if modifiers.contains(.shift) { flags.insert(.maskShift) }
        if modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        if modifiers.contains(.function) { flags.insert(.maskSecondaryFn) }
        return flags
    }

    private static func keyCode(for key: String) -> CGKeyCode? {
        let map: [String: CGKeyCode] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
            "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
            "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "equals": 24, "9": 25, "7": 26, "minus": 27, "8": 28, "0": 29,
            "rightbracket": 30, "o": 31, "u": 32, "leftbracket": 33, "i": 34, "p": 35,
            "return": 36, "l": 37, "j": 38, "quote": 39, "k": 40, "semicolon": 41, "backslash": 42, "comma": 43, "slash": 44, "n": 45, "m": 46, "period": 47,
            "tab": 48, "space": 49, "grave": 50, "delete": 51, "escape": 53,
            "left": 123, "right": 124, "down": 125, "up": 126,
            "home": 115, "end": 119, "pageup": 116, "pagedown": 121, "forwarddelete": 117
        ]
        return map[key.lowercased()]
    }
}
#endif
