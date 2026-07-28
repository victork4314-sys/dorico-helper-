import Foundation

/// Reserved virtual-MIDI addresses used internally by the bridge for actions
/// whose final value is determined at execution time. The normal MIDI Learn
/// catalog currently occupies channels 1–4, so these channel-16 addresses do
/// not collide with user-facing MIDI slots.
public enum BridgeDynamicMIDI {
    public static let pitchDown = MIDIAddress(channel: 16, note: 125)
    public static let pitchUp = MIDIAddress(channel: 16, note: 126)
    public static let placeSelectedNote = MIDIAddress(channel: 16, note: 127)

    public static func isReserved(_ address: MIDIAddress) -> Bool {
        address == pitchDown || address == pitchUp || address == placeSelectedNote
    }
}
