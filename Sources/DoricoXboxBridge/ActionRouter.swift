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
        do { try await executeThrowing(action) }
        catch {
            model?.captureMessage = error.localizedDescription
            model?.log("Action failed: \(error.localizedDescription)")
        }
    }

    private func executeThrowing(_ action: CommandAction) async throws {
        switch action {
        case .internalCommand(let command):
            model?.handleInternal(command)
            if model?.dashboardVisible == true { accessibility.hideFocusSelector() }
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
                model?.lastAction = "MIDI \(address.displayName)"
            }
        case .keyChord(let chord):
            guard prepareDoricoTarget() else { throw RouterError.doricoNotRunning }
            guard KeyEmitter.send(chord) else { throw RouterError.unsupportedShortcut(chord.displayName) }
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
        if model?.activeProfile.settings.onlyWhenDoricoFrontmost == true { return detector.isFrontmost() }
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
            CGWarpMouseCursorPosition(CGPoint(x: current.x + dx * scale, y: current.y - dy * scale))
        case .scroll(let dx, let dy):
            CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2, wheel1: Int32(dy), wheel2: Int32(dx), wheel3: 0)?.post(tap: .cghidEventTap)
        case .leftClick: click(button: .left, count: 1)
        case .rightClick: click(button: .right, count: 1)
        case .doubleClick: click(button: .left, count: 2)
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
        case unsupportedShortcut(String)

        var errorDescription: String? {
            switch self {
            case .doricoNotRunning: "Dorico Pro is not running or is not frontmost"
            case .unsupportedShortcut(let shortcut): "The keyboard shortcut \(shortcut) could not be emitted"
            }
        }
    }
}

private enum KeyEmitter {
    private struct ResolvedKey {
        var code: CGKeyCode
        var implicitModifiers: Set<KeyModifier> = []
    }

    @discardableResult
    static func send(_ chord: KeyChord) -> Bool {
        if chord.isModifierOnly {
            sendModifierOnly(chord.modifiers)
            return true
        }

        guard let resolved = resolve(chord) else { return false }
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: resolved.code, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: resolved.code, keyDown: false)
        let flags = eventFlags(for: chord.modifiers.union(resolved.implicitModifiers))
        down?.flags = flags
        up?.flags = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
        return down != nil && up != nil
    }

    static func type(_ text: String) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let units = Array(text.utf16)
        let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        units.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            down?.keyboardSetUnicodeString(stringLength: units.count, unicodeString: base)
            up?.keyboardSetUnicodeString(stringLength: units.count, unicodeString: base)
        }
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private static func resolve(_ chord: KeyChord) -> ResolvedKey? {
        if let captured = chord.virtualKeyCode { return ResolvedKey(code: CGKeyCode(captured)) }
        return keyCodeAndImplicitModifiers(for: chord.key)
    }

    private static func sendModifierOnly(_ modifiers: Set<KeyModifier>) {
        let order: [KeyModifier] = [.control, .option, .shift, .command, .function, .capsLock]
        let selected = order.filter(modifiers.contains)
        let source = CGEventSource(stateID: .combinedSessionState)
        var flags: CGEventFlags = []

        for modifier in selected {
            flags.insert(eventFlag(for: modifier))
            let event = CGEvent(keyboardEventSource: source, virtualKey: modifierKeyCode(modifier), keyDown: true)
            event?.flags = flags
            event?.post(tap: .cghidEventTap)
        }
        for modifier in selected.reversed() {
            let event = CGEvent(keyboardEventSource: source, virtualKey: modifierKeyCode(modifier), keyDown: false)
            event?.flags = flags
            event?.post(tap: .cghidEventTap)
            flags.remove(eventFlag(for: modifier))
        }
    }

    private static func eventFlags(for modifiers: Set<KeyModifier>) -> CGEventFlags {
        modifiers.reduce(into: CGEventFlags()) { $0.insert(eventFlag(for: $1)) }
    }

    private static func eventFlag(for modifier: KeyModifier) -> CGEventFlags {
        switch modifier {
        case .command: .maskCommand
        case .shift: .maskShift
        case .option: .maskAlternate
        case .control: .maskControl
        case .function: .maskSecondaryFn
        case .capsLock: .maskAlphaShift
        }
    }

    private static func modifierKeyCode(_ modifier: KeyModifier) -> CGKeyCode {
        switch modifier {
        case .command: 55
        case .shift: 56
        case .capsLock: 57
        case .option: 58
        case .control: 59
        case .function: 63
        }
    }

    private static func keyCodeAndImplicitModifiers(for key: String) -> ResolvedKey? {
        let raw = key.lowercased()
        let aliases: [String: String] = [
            "enter": "return", "esc": "escape", "backspace": "delete",
            "⌫": "delete", "⌦": "forwarddelete", "←": "left", "→": "right",
            "↑": "up", "↓": "down", "[": "leftbracket", "]": "rightbracket",
            "\\": "backslash", ";": "semicolon", "'": "quote", ",": "comma",
            ".": "period", "/": "slash", "`": "grave", "=": "equals", "-": "minus"
        ]
        let normalized = aliases[raw] ?? raw

        let shifted: [String: (String, KeyModifier)] = [
            "!": ("1", .shift), "@": ("2", .shift), "#": ("3", .shift), "$": ("4", .shift),
            "%": ("5", .shift), "^": ("6", .shift), "&": ("7", .shift), "*": ("8", .shift),
            "(": ("9", .shift), ")": ("0", .shift), "_": ("minus", .shift), "+": ("equals", .shift),
            "{": ("leftbracket", .shift), "}": ("rightbracket", .shift), "|": ("backslash", .shift),
            ":": ("semicolon", .shift), "\"": ("quote", .shift), "<": ("comma", .shift),
            ">": ("period", .shift), "?": ("slash", .shift), "~": ("grave", .shift)
        ]
        if let shifted = shifted[raw], let base = legacyKeyCodes[shifted.0] {
            return ResolvedKey(code: base, implicitModifiers: [shifted.1])
        }
        guard let code = legacyKeyCodes[normalized] else { return nil }
        return ResolvedKey(code: code)
    }

    private static let legacyKeyCodes: [String: CGKeyCode] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
        "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "equals": 24, "9": 25,
        "7": 26, "minus": 27, "8": 28, "0": 29, "rightbracket": 30, "o": 31, "u": 32,
        "leftbracket": 33, "i": 34, "p": 35, "return": 36, "l": 37, "j": 38, "quote": 39,
        "k": 40, "semicolon": 41, "backslash": 42, "comma": 43, "slash": 44, "n": 45, "m": 46,
        "period": 47, "tab": 48, "space": 49, "grave": 50, "delete": 51, "escape": 53,
        "f17": 64, "keypadperiod": 65, "keypadmultiply": 67, "keypadplus": 69, "keypadclear": 71,
        "keypaddivide": 75, "keypadenter": 76, "keypadminus": 78, "f18": 79, "f19": 80,
        "keypadequals": 81, "keypad0": 82, "keypad1": 83, "keypad2": 84, "keypad3": 85,
        "keypad4": 86, "keypad5": 87, "keypad6": 88, "keypad7": 89, "f20": 90,
        "keypad8": 91, "keypad9": 92, "f5": 96, "f6": 97, "f7": 98, "f3": 99, "f8": 100,
        "f9": 101, "f11": 103, "f13": 105, "f16": 106, "f14": 107, "f10": 109, "f12": 111,
        "f15": 113, "help": 114, "home": 115, "pageup": 116, "forwarddelete": 117, "f4": 118,
        "end": 119, "f2": 120, "pagedown": 121, "f1": 122, "left": 123, "right": 124,
        "down": 125, "up": 126
    ]
}
#endif
