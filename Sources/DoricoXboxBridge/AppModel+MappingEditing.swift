#if os(macOS)
import Foundation
import DoricoBridgeCore

@MainActor
extension AppModel {
    var activeProfileIdentity: String { "\(activeProfileIndex):\(activeProfile.id.uuidString)" }
    var activeProfileName: String { activeProfile.name }

    func enforceActiveProfileIsolation() {
        resetControllerState()
        captureMessage = "Only “\(activeProfile.name)” is active. No mappings from other layouts are applied."
        log("Activated exclusive mapping layout: \(activeProfile.name)")
    }

    func mappedAction(for inputs: Set<XboxInput>, pointerMode: Bool, gesture: BindingGesture) -> CommandAction? {
        guard !inputs.isEmpty else { return nil }
        return activeProfile.bindings[BindingKey(inputs: inputs, pointerMode: pointerMode, gesture: gesture)]
    }

    func mappedAction(for input: XboxInput, layer: MappingLayer, gesture: BindingGesture) -> CommandAction? {
        mappedAction(for: layer.modifierInputs.union([input]), pointerMode: layer == .pointer, gesture: gesture)
    }

    func assignAction(_ descriptor: ActionDescriptor, to inputs: Set<XboxInput>, pointerMode: Bool, gesture: BindingGesture) {
        guard !inputs.isEmpty else {
            captureMessage = "Choose at least one controller control."
            return
        }
        let key = BindingKey(inputs: inputs, pointerMode: pointerMode, gesture: gesture)
        var profile = activeProfile
        let replaced = profile.bindings.updateValue(descriptor.action, forKey: key)
        activeProfile = profile
        selectedLayer = pointerMode ? .pointer : .base
        selectedGesture = gesture
        let verb = replaced == nil ? "Added" : "Replaced"
        captureMessage = "\(verb) \(key.displayName) with \(descriptor.title) in “\(profile.name)” only."
        log("\(verb) exact combination in \(profile.name): \(key.displayName) · \(gesture.displayName) → \(descriptor.title)")
        testHaptic()
    }

    func removeDirectMapping(for inputs: Set<XboxInput>, pointerMode: Bool, gesture: BindingGesture) {
        guard !inputs.isEmpty else { return }
        let key = BindingKey(inputs: inputs, pointerMode: pointerMode, gesture: gesture)
        var profile = activeProfile
        guard let removed = profile.bindings.removeValue(forKey: key) else {
            captureMessage = "No mapping exists for \(key.displayName) · \(gesture.displayName)."
            return
        }
        activeProfile = profile
        captureMessage = "Removed \(removed.summary) from \(key.displayName) in “\(profile.name)” only."
        log("Removed exact combination from \(profile.name): \(key.displayName) · \(gesture.displayName)")
    }

    func customKeyDescriptor(key: String, modifiers: Set<KeyModifier>) -> ActionDescriptor? {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !modifiers.isEmpty else { return nil }
        let chord = trimmed.isEmpty ? KeyChord(modifiersOnly: modifiers) : KeyChord(trimmed, modifiers: modifiers)
        return customCapturedKeyDescriptor(chord)
    }

    func customCapturedKeyDescriptor(_ chord: KeyChord) -> ActionDescriptor {
        ActionDescriptor(
            id: "custom.key.\(UUID().uuidString)",
            title: "Keyboard shortcut: \(chord.displayName)",
            category: "Custom keyboard shortcut",
            detail: chord.isModifierOnly
                ? "Press and release the selected modifier keys"
                : "Replay the exact captured macOS key, symbols, and modifiers",
            action: .keyChord(chord)
        )
    }

    func customTextDescriptor(_ text: String) -> ActionDescriptor? {
        guard !text.isEmpty else { return nil }
        return ActionDescriptor(
            id: "custom.text.\(UUID().uuidString)",
            title: "Type custom text",
            category: "Custom action",
            detail: "Type “\(text)” into Dorico",
            action: .typeText(text)
        )
    }

    func customJumpBarDescriptor(_ command: String) -> ActionDescriptor? {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return ActionDescriptor(
            id: "custom.jump.\(UUID().uuidString)",
            title: "Jump Bar: \(trimmed)",
            category: "Custom action",
            detail: "Run the Dorico Jump Bar command “\(trimmed)”",
            action: .sequence([
                CommandStep(.keyChord(KeyChord("j"))),
                CommandStep(.keyChord(KeyChord("1", modifiers: [.control])), delayMilliseconds: 80),
                CommandStep(.typeText(trimmed), delayMilliseconds: 80),
                CommandStep(.keyChord(KeyChord("return")), delayMilliseconds: 30)
            ])
        )
    }

    func customMIDIDescriptor(channel: Int, note: Int) -> ActionDescriptor {
        let address = MIDIAddress(
            channel: UInt8(min(16, max(1, channel))),
            note: UInt8(min(127, max(0, note)))
        )
        return ActionDescriptor(
            id: "custom.midi.\(UUID().uuidString)",
            title: "MIDI \(address.noteName) · Channel \(address.channel)",
            category: "Custom MIDI action",
            detail: "Send \(address.noteName) on virtual MIDI channel \(address.channel)",
            action: .midiPulse(address)
        )
    }

    func customMacroDescriptor(name: String, chords: [KeyChord]) -> ActionDescriptor? {
        let steps = chords.enumerated().map { index, chord in
            CommandStep(.keyChord(chord), delayMilliseconds: index == 0 ? 0 : 70)
        }
        return customSequenceDescriptor(name: name, steps: steps)
    }

    func customSequenceDescriptor(name: String, steps: [CommandStep]) -> ActionDescriptor? {
        guard !steps.isEmpty else { return nil }
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = cleaned.isEmpty ? "Custom action sequence" : cleaned
        return ActionDescriptor(
            id: "custom.sequence.\(UUID().uuidString)",
            title: title,
            category: "Custom action sequence",
            detail: steps.enumerated().map { index, step in
                let wait = step.delayMilliseconds == 0 ? "" : " after \(step.delayMilliseconds) ms"
                return "\(index + 1). \(step.action.summary)\(wait)"
            }.joined(separator: " → "),
            action: .sequence(steps)
        )
    }
}
#endif
