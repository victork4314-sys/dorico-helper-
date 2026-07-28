#if os(macOS)
import Combine
import Foundation
import DoricoBridgeCore

@MainActor
final class NoteEntryState: ObservableObject {
    static let shared = NoteEntryState()

    @Published private(set) var degree = 0
    @Published private(set) var octave = 4

    private let noteNames = ["C", "D", "E", "F", "G", "A", "B"]
    private let semitones = [0, 2, 4, 5, 7, 9, 11]

    private init() {}

    var displayName: String { "\(noteNames[degree])\(octave)" }

    var midiAddress: MIDIAddress {
        let raw = 12 * (octave + 1) + semitones[degree]
        return MIDIAddress(channel: 1, note: UInt8(min(127, max(0, raw))))
    }

    func move(_ delta: Int) {
        guard delta != 0 else { return }
        let direction = delta > 0 ? 1 : -1
        for _ in 0..<abs(delta) {
            var nextDegree = degree + direction
            var nextOctave = octave
            if nextDegree > 6 {
                nextDegree = 0
                nextOctave += 1
            } else if nextDegree < 0 {
                nextDegree = 6
                nextOctave -= 1
            }

            let raw = 12 * (nextOctave + 1) + semitones[nextDegree]
            guard (0...127).contains(raw) else { break }
            degree = nextDegree
            octave = nextOctave
        }
    }

    func reset() {
        degree = 0
        octave = 4
    }
}
#endif
