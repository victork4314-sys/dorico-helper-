import Foundation

public struct DoricoVoiceCommand: Hashable, Sendable {
    public var label: String
    public var canonicalPhrase: String
    public var action: CommandAction

    public init(label: String, canonicalPhrase: String, action: CommandAction) {
        self.label = label
        self.canonicalPhrase = canonicalPhrase
        self.action = action
    }
}

public struct DoricoVoiceBatch: Sendable {
    public var commands: [DoricoVoiceCommand]
    public var unrecognizedSegments: [String]
    public var label: String { commands.map(\.label).joined(separator: " → ") }

    public init(commands: [DoricoVoiceCommand], unrecognizedSegments: [String] = []) {
        self.commands = commands
        self.unrecognizedSegments = unrecognizedSegments
    }
}

public struct DoricoVoiceAliasBook: Codable, Hashable, Sendable {
    public var aliases: [String: String]

    public init(aliases: [String: String] = [:]) {
        self.aliases = Dictionary(uniqueKeysWithValues: aliases.map {
            (DoricoVoiceLanguage.normalize($0.key), DoricoVoiceLanguage.normalize($0.value))
        })
    }

    public mutating func teach(samples: [String], canonicalPhrase: String) {
        let target = DoricoVoiceLanguage.normalize(canonicalPhrase)
        guard !target.isEmpty else { return }
        for sample in samples {
            let key = DoricoVoiceLanguage.normalize(sample)
            if !key.isEmpty { aliases[key] = target }
        }
    }

    public mutating func removeAlias(_ sample: String) {
        aliases.removeValue(forKey: DoricoVoiceLanguage.normalize(sample))
    }

    public mutating func removeAll() { aliases.removeAll() }

    public func resolve(_ phrase: String) -> String? {
        let phrase = DoricoVoiceLanguage.normalize(phrase)
        if let exact = aliases[phrase] { return exact }
        return aliases
            .map { (DoricoVoiceLanguage.similarity(phrase, $0.key), $0.value) }
            .filter { $0.0 >= 0.72 }
            .max(by: { $0.0 < $1.0 })?.1
    }
}

/// A short, Siri-style setup profile. It does not train Apple's private acoustic model.
/// Instead it learns the reusable words and sound-groups that macOS Speech Recognition
/// consistently writes differently for this speaker and microphone.
public struct DoricoVoiceCalibrationProfile: Codable, Hashable, Sendable {
    public var replacements: [String: String]
    public var phraseSamples: [String: String]
    public var completedPromptCount: Int

    public init(
        replacements: [String: String] = [:],
        phraseSamples: [String: String] = [:],
        completedPromptCount: Int = 0
    ) {
        self.replacements = Dictionary(uniqueKeysWithValues: replacements.map {
            (DoricoVoiceLanguage.normalize($0.key), DoricoVoiceLanguage.normalize($0.value))
        })
        self.phraseSamples = Dictionary(uniqueKeysWithValues: phraseSamples.map {
            (DoricoVoiceLanguage.normalize($0.key), DoricoVoiceLanguage.normalize($0.value))
        })
        self.completedPromptCount = max(0, completedPromptCount)
    }

    public var isComplete: Bool {
        completedPromptCount >= DoricoVoiceLanguage.calibrationPrompts.count
    }

    public var learnedCorrectionCount: Int {
        replacements.count + phraseSamples.count
    }

    public mutating func learn(expected: String, heard: String) {
        let expected = DoricoVoiceLanguage.normalize(expected)
        let heard = DoricoVoiceLanguage.normalize(heard)
        guard !expected.isEmpty, !heard.isEmpty else { return }

        phraseSamples[heard] = expected
        for (source, target) in Self.correctionBlocks(expected: expected, heard: heard) {
            if let existing = replacements[source], existing != target {
                replacements.removeValue(forKey: source)
            } else {
                replacements[source] = target
            }
        }
        completedPromptCount += 1
    }

    public mutating func reset() {
        replacements.removeAll()
        phraseSamples.removeAll()
        completedPromptCount = 0
    }

    public func apply(to text: String) -> String {
        var value = DoricoVoiceLanguage.normalize(text)
        guard !value.isEmpty else { return value }
        if let exact = phraseSamples[value] { return exact }

        let ordered = replacements.sorted {
            let leftWords = $0.key.split(separator: " ").count
            let rightWords = $1.key.split(separator: " ").count
            return leftWords == rightWords ? $0.key.count > $1.key.count : leftWords > rightWords
        }
        for (source, target) in ordered {
            value = Self.replaceTokenPhrase(source, with: target, in: value)
        }
        return DoricoVoiceLanguage.normalize(value)
    }

    private enum TokenEdit {
        case equal
        case substitute(expected: String, heard: String)
        case deleteExpected(String)
        case insertHeard(String)
    }

    private static let unsafeSingleTokenCorrections: Set<String> = [
        "a", "an", "and", "are", "at", "be", "by", "can", "do", "for", "from", "go",
        "i", "in", "is", "it", "left", "me", "my", "of", "on", "one", "or", "please",
        "right", "set", "the", "then", "this", "to", "two", "up", "use", "with", "you"
    ]

    private static func correctionBlocks(expected: String, heard: String) -> [(String, String)] {
        let expectedTokens = expected.split(separator: " ").map(String.init)
        let heardTokens = heard.split(separator: " ").map(String.init)
        guard !expectedTokens.isEmpty, !heardTokens.isEmpty else { return [] }

        var distance = Array(
            repeating: Array(repeating: 0, count: heardTokens.count + 1),
            count: expectedTokens.count + 1
        )
        for i in 0...expectedTokens.count { distance[i][0] = i }
        for j in 0...heardTokens.count { distance[0][j] = j }

        if !expectedTokens.isEmpty, !heardTokens.isEmpty {
            for i in 1...expectedTokens.count {
                for j in 1...heardTokens.count {
                    let substitution = distance[i - 1][j - 1] + (expectedTokens[i - 1] == heardTokens[j - 1] ? 0 : 1)
                    distance[i][j] = min(
                        substitution,
                        distance[i - 1][j] + 1,
                        distance[i][j - 1] + 1
                    )
                }
            }
        }

        var edits: [TokenEdit] = []
        var i = expectedTokens.count
        var j = heardTokens.count
        while i > 0 || j > 0 {
            if i > 0, j > 0, expectedTokens[i - 1] == heardTokens[j - 1],
               distance[i][j] == distance[i - 1][j - 1] {
                edits.append(.equal)
                i -= 1
                j -= 1
            } else if i > 0, j > 0, distance[i][j] == distance[i - 1][j - 1] + 1 {
                edits.append(.substitute(expected: expectedTokens[i - 1], heard: heardTokens[j - 1]))
                i -= 1
                j -= 1
            } else if i > 0, distance[i][j] == distance[i - 1][j] + 1 {
                edits.append(.deleteExpected(expectedTokens[i - 1]))
                i -= 1
            } else if j > 0 {
                edits.append(.insertHeard(heardTokens[j - 1]))
                j -= 1
            }
        }
        edits.reverse()

        var result: [(String, String)] = []
        var expectedBlock: [String] = []
        var heardBlock: [String] = []

        func flush() {
            guard !expectedBlock.isEmpty, !heardBlock.isEmpty else {
                expectedBlock.removeAll()
                heardBlock.removeAll()
                return
            }
            let source = heardBlock.joined(separator: " ")
            let target = expectedBlock.joined(separator: " ")
            defer {
                expectedBlock.removeAll()
                heardBlock.removeAll()
            }
            guard source != target else { return }
            if heardBlock.count == 1 {
                guard source.count >= 3, !unsafeSingleTokenCorrections.contains(source) else { return }
            }
            result.append((source, target))
        }

        for edit in edits {
            switch edit {
            case .equal:
                flush()
            case .substitute(let expected, let heard):
                expectedBlock.append(expected)
                heardBlock.append(heard)
            case .deleteExpected(let expected):
                expectedBlock.append(expected)
            case .insertHeard(let heard):
                heardBlock.append(heard)
            }
        }
        flush()
        return result
    }

    private static func replaceTokenPhrase(_ source: String, with target: String, in text: String) -> String {
        let sourceTokens = source.split(separator: " ").map(String.init)
        let targetTokens = target.split(separator: " ").map(String.init)
        let inputTokens = text.split(separator: " ").map(String.init)
        guard !sourceTokens.isEmpty, inputTokens.count >= sourceTokens.count else { return text }

        var output: [String] = []
        var index = 0
        while index < inputTokens.count {
            let end = index + sourceTokens.count
            if end <= inputTokens.count,
               Array(inputTokens[index..<end]) == sourceTokens {
                output.append(contentsOf: targetTokens)
                index = end
            } else {
                output.append(inputTokens[index])
                index += 1
            }
        }
        return output.joined(separator: " ")
    }
}

public enum DoricoVoiceLanguage {
    public static let calibrationPrompts = [
        "Dorico, write a quarter note, then an eighth note, then a sixteenth note.",
        "Dorico, enter C sharp four and E flat three, then add staccato and a tie.",
        "Dorico, add twenty five bars, move left one bar, and extend the selection right.",
        "Dorico, use a treble clef, time signature three four, and key signature E flat major.",
        "Dorico, add crescendo, fortissimo, fermata, trill, tenuto, and start playback."
    ]

    private static let coreSpeechHints = [
        "Dorico", "eighth note", "quaver", "sixteenth note", "semiquaver", "quarter note", "crotchet",
        "half note", "minim", "whole note", "semibreve", "C sharp four", "E flat three",
        "add twenty five bars", "delete four bars", "go left one bar", "go right two bars", "go to bar thirty two",
        "time signature three four", "key signature E flat major", "treble clef", "bass clef",
        "dynamic fortissimo", "tempo allegro", "crescendo", "diminuendo", "staccato", "tenuto", "fermata", "trill"
    ]

    public static var speechHints: [String] {
        Array(Set(coreSpeechHints + calibrationPrompts + catalogSpeechHints)).sorted()
    }

    public static func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "♯", with: " sharp ")
            .replacingOccurrences(of: "♭", with: " flat ")
            .replacingOccurrences(of: "-(?=[0-9])", with: " minus ", options: .regularExpression)
            .replacingOccurrences(of: "–|—|-", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "[^a-z0-9+/. ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func similarity(_ lhs: String, _ rhs: String) -> Double {
        let a = Array(normalize(lhs)), b = Array(normalize(rhs))
        guard !a.isEmpty || !b.isEmpty else { return 1 }
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        var previous = Array(0...b.count)
        for (i, left) in a.enumerated() {
            var current = [i + 1]
            for (j, right) in b.enumerated() {
                current.append(min(current[j] + 1, previous[j + 1] + 1, previous[j] + (left == right ? 0 : 1)))
            }
            previous = current
        }
        let characterScore = 1 - Double(previous[b.count]) / Double(max(a.count, b.count))
        let leftTokens = Set(String(a).split(separator: " "))
        let rightTokens = Set(String(b).split(separator: " "))
        let union = leftTokens.union(rightTokens)
        let tokenScore = union.isEmpty ? 1 : Double(leftTokens.intersection(rightTokens).count) / Double(union.count)
        return max(characterScore * 0.94, characterScore * 0.72 + tokenScore * 0.28)
    }

    static func command(_ label: String, canonical: String, _ action: CommandAction) -> DoricoVoiceCommand {
        DoricoVoiceCommand(label: label, canonicalPhrase: canonical, action: action)
    }

    static func popover(_ shortcut: KeyChord, _ value: String) -> CommandAction {
        .sequence([
            CommandStep(.keyChord(shortcut)),
            CommandStep(.typeText(value), delayMilliseconds: 80),
            CommandStep(.keyChord(KeyChord("return")), delayMilliseconds: 40)
        ])
    }

    static func extractNumber(_ phrase: String) -> Int? {
        if let range = phrase.range(of: #"\b[0-9]+\b"#, options: .regularExpression) { return Int(phrase[range]) }
        let small = ["zero":0,"one":1,"a":1,"an":1,"two":2,"three":3,"four":4,"five":5,"six":6,"seven":7,"eight":8,"nine":9,"ten":10,"eleven":11,"twelve":12,"thirteen":13,"fourteen":14,"fifteen":15,"sixteen":16,"seventeen":17,"eighteen":18,"nineteen":19]
        let tens = ["twenty":20,"thirty":30,"forty":40,"fifty":50,"sixty":60,"seventy":70,"eighty":80,"ninety":90]
        var total = 0, current = 0, found = false
        for token in phrase.split(separator: " ").map(String.init) {
            if let n = small[token] { current += n; found = true }
            else if let n = tens[token] { current += n; found = true }
            else if token == "hundred", found { current = max(current, 1) * 100 }
            else if token == "thousand", found { total += max(current, 1) * 1000; current = 0 }
            else if found { break }
        }
        return found ? total + current : nil
    }

    static func contains(_ phrase: String, any terms: [String]) -> Bool { terms.contains(where: phrase.contains) }

    static func stripLeading(_ phrase: String, _ words: Set<String>) -> String {
        var tokens = phrase.split(separator: " ").map(String.init)
        while let first = tokens.first, words.contains(first) { tokens.removeFirst() }
        return tokens.joined(separator: " ")
    }
}
