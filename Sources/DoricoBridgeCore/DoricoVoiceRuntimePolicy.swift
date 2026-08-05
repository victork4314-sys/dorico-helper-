import Foundation

/// Runtime safety rules shared by the native voice controller and tests.
public enum DoricoVoiceRuntimePolicy {
    /// Apple documents a maximum of 100 contextual strings per speech request.
    public static let maximumContextualStrings = 100

    /// Builds a deterministic, deduplicated list while preserving priority order.
    public static func contextualStrings(
        priority: [String],
        fallback: [String],
        limit: Int = maximumContextualStrings
    ) -> [String] {
        guard limit > 0 else { return [] }

        var seen = Set<String>()
        var result: [String] = []

        func append(_ candidate: String) {
            guard result.count < limit else { return }
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            let identity = trimmed.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            guard seen.insert(identity).inserted else { return }
            result.append(trimmed)
        }

        for candidate in priority {
            append(candidate)
            if result.count == limit { return result }
        }
        for candidate in fallback {
            append(candidate)
            if result.count == limit { return result }
        }
        return result
    }

    /// AVAudioEngine can report a zero-channel or zero-rate input while no usable
    /// microphone route is available. Installing a tap with that format triggers
    /// a fatal AVFoundation assertion, so reject it before touching the audio graph.
    public static func isUsableAudioInput(sampleRate: Double, channelCount: UInt32) -> Bool {
        sampleRate.isFinite && sampleRate > 0 && channelCount > 0
    }
}
