#if os(macOS)
import AppKit
import SwiftUI
import DoricoBridgeCore

struct KeyboardShortcutRecorder: View {
    @Binding var shortcut: KeyChord?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ShortcutCaptureField(shortcut: $shortcut)
                .frame(height: 34)
            HStack {
                Text("Click the field, then press the real shortcut. All symbols, function keys, localized keys, Command, Shift, Option, Control, Fn/Globe, and Caps Lock are captured.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear") { shortcut = nil }
                    .disabled(shortcut == nil)
            }
        }
    }
}

private struct ShortcutCaptureField: NSViewRepresentable {
    @Binding var shortcut: KeyChord?

    func makeCoordinator() -> Coordinator { Coordinator(shortcut: $shortcut) }

    func makeNSView(context: Context) -> ShortcutTextField {
        let field = ShortcutTextField()
        field.onCapture = { context.coordinator.shortcut.wrappedValue = $0 }
        field.stringValue = shortcut?.displayName ?? "Click here and press a keyboard shortcut"
        return field
    }

    func updateNSView(_ field: ShortcutTextField, context: Context) {
        field.onCapture = { context.coordinator.shortcut.wrappedValue = $0 }
        field.stringValue = shortcut?.displayName ?? "Click here and press a keyboard shortcut"
        field.textColor = shortcut == nil ? .secondaryLabelColor : .labelColor
    }

    final class Coordinator {
        var shortcut: Binding<KeyChord?>
        init(shortcut: Binding<KeyChord?>) { self.shortcut = shortcut }
    }
}

private final class ShortcutTextField: NSTextField {
    var onCapture: ((KeyChord) -> Void)?
    private var peakModifiers = Set<KeyModifier>()
    private var capturedNonModifier = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isEditable = false
        isSelectable = false
        isBezeled = true
        bezelStyle = .roundedBezel
        alignment = .center
        font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        focusRingType = .default
        placeholderString = "Click here and press a keyboard shortcut"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            peakModifiers.removeAll()
            capturedNonModifier = false
            stringValue = "Recording…"
        }
        return result
    }

    override func resignFirstResponder() -> Bool {
        peakModifiers.removeAll()
        capturedNonModifier = false
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        guard !event.isARepeat else { return }
        capturedNonModifier = true
        let modifiers = Self.modifiers(from: event.modifierFlags)
        peakModifiers.formUnion(modifiers)
        let chord = KeyChord(
            capturedKeyCode: event.keyCode,
            characters: Self.displayCharacters(for: event),
            modifiers: modifiers
        )
        stringValue = chord.displayName
        onCapture?(chord)
    }

    override func flagsChanged(with event: NSEvent) {
        let modifiers = Self.modifiers(from: event.modifierFlags)
        if !modifiers.isEmpty {
            if peakModifiers.isEmpty { capturedNonModifier = false }
            peakModifiers.formUnion(modifiers)
            stringValue = KeyChord(modifiersOnly: peakModifiers).displayName + " …"
        } else if !peakModifiers.isEmpty {
            if !capturedNonModifier {
                let chord = KeyChord(modifiersOnly: peakModifiers)
                stringValue = chord.displayName
                onCapture?(chord)
            }
            peakModifiers.removeAll()
            capturedNonModifier = false
        }
    }

    private static func modifiers(from flags: NSEvent.ModifierFlags) -> Set<KeyModifier> {
        let flags = flags.intersection(.deviceIndependentFlagsMask)
        var output = Set<KeyModifier>()
        if flags.contains(.command) { output.insert(.command) }
        if flags.contains(.shift) { output.insert(.shift) }
        if flags.contains(.option) { output.insert(.option) }
        if flags.contains(.control) { output.insert(.control) }
        if flags.contains(.function) { output.insert(.function) }
        if flags.contains(.capsLock) { output.insert(.capsLock) }
        return output
    }

    private static func displayCharacters(for event: NSEvent) -> String {
        if let characters = event.characters,
           !characters.isEmpty,
           characters.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) {
            return characters
        }
        if let characters = event.charactersIgnoringModifiers,
           !characters.isEmpty,
           characters.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) {
            return characters
        }
        return specialKeyName(event.keyCode)
    }

    private static func specialKeyName(_ code: UInt16) -> String {
        let names: [UInt16: String] = [
            36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Escape",
            65: "Keypad .", 67: "Keypad *", 69: "Keypad +", 71: "Keypad Clear",
            75: "Keypad /", 76: "Keypad Enter", 78: "Keypad -", 81: "Keypad =",
            82: "Keypad 0", 83: "Keypad 1", 84: "Keypad 2", 85: "Keypad 3",
            86: "Keypad 4", 87: "Keypad 5", 88: "Keypad 6", 89: "Keypad 7",
            91: "Keypad 8", 92: "Keypad 9", 114: "Help", 115: "Home",
            116: "Page Up", 117: "Forward Delete", 119: "End", 121: "Page Down",
            123: "←", 124: "→", 125: "↓", 126: "↑",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5",
            97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
            103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15",
            106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20"
        ]
        return names[code] ?? "Key \(code)"
    }
}
#endif
