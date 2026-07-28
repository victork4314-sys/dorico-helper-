#if os(macOS)
import Foundation
import DoricoBridgeCore

@MainActor
extension AppModel {
    var activeProfileIdentity: String {
        "\(activeProfileIndex):\(activeProfile.id.uuidString)"
    }

    var activeProfileName: String { activeProfile.name }

    func enforceActiveProfileIsolation() {
        resetControllerState()
        captureMessage = "Only “\(activeProfile.name)” is active. No mappings from other layouts are applied."
        log("Activated exclusive mapping layout: \(activeProfile.name)")
    }

    func mappedAction(
        for input: XboxInput,
        layer: MappingLayer,
        gesture: BindingGesture
    ) -> CommandAction? {
        activeProfile.bindings[BindingKey(layer: layer, input: input, gesture: gesture)]
    }

    func assignAction(
        _ descriptor: ActionDescriptor,
        to input: XboxInput,
        layer: MappingLayer,
        gesture: BindingGesture
    ) {
        let key = BindingKey(layer: layer, input: input, gesture: gesture)
        var profile = activeProfile
        let replaced = profile.bindings.updateValue(descriptor.action, forKey: key)
        activeProfile = profile
        selectedLayer = layer
        selectedGesture = gesture
        let replacementText = replaced == nil ? "Added" : "Replaced"
        captureMessage = "\(replacementText) \(layer.displayName) · \(input.displayName) with \(descriptor.title) in “\(profile.name)” only."
        log("\(replacementText) mapping in \(profile.name): \(layer.displayName) · \(input.displayName) · \(gesture.displayName) → \(descriptor.title)")
        testHaptic()
    }

    func removeDirectMapping(
        for input: XboxInput,
        layer: MappingLayer,
        gesture: BindingGesture
    ) {
        let key = BindingKey(layer: layer, input: input, gesture: gesture)
        var profile = activeProfile
        guard let removed = profile.bindings.removeValue(forKey: key) else {
            captureMessage = "No mapping exists for \(layer.displayName) · \(input.displayName) · \(gesture.displayName)."
            return
        }
        activeProfile = profile
        captureMessage = "Removed \(removed.summary) from \(input.displayName) in “\(profile.name)” only."
        log("Removed mapping from \(profile.name): \(layer.displayName) · \(input.displayName) · \(gesture.displayName)")
    }

    func customKeyDescriptor(key: String, modifiers: Set<KeyModifier>) -> ActionDescriptor? {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        let chord = KeyChord(trimmed, modifiers: modifiers)
        return ActionDescriptor(
            id: "custom.key.\(UUID().uuidString)",
            title: "Custom shortcut: \(chord.displayName)",
            category: "Custom action",
            detail: "Send \(chord.displayName) to Dorico",
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
        let address = MIDIAddress(channel: UInt8(min(16, max(1, channel))), note: UInt8(min(127, max(0, note))))
        return ActionDescriptor(
            id: "custom.midi.\(UUID().uuidString)",
            title: "Custom MIDI ch \(address.channel), note \(address.note)",
            category: "Custom action",
            detail: "Send a MIDI note pulse through Dorico Xbox Bridge",
            action: .midiPulse(address)
        )
    }

    func customMacroDescriptor(name: String, chords: [KeyChord]) -> ActionDescriptor? {
        guard !chords.isEmpty else { return nil }
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = cleanedName.isEmpty ? "Custom macro" : cleanedName
        let steps = chords.enumerated().map { index, chord in
            CommandStep(.keyChord(chord), delayMilliseconds: index == 0 ? 0 : 70)
        }
        return ActionDescriptor(
            id: "custom.macro.\(UUID().uuidString)",
            title: title,
            category: "Custom action",
            detail: chords.map(\.displayName).joined(separator: " → "),
            action: .sequence(steps)
        )
    }
}
#endif
