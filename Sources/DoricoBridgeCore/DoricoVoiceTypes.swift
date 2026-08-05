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

public enum DoricoVoiceLanguage {
    public static let speechHints = [
        "Dorico", "eighth note", "quaver", "sixteenth note", "semiquaver", "quarter note", "crotchet",
        "half note", "minim", "whole note", "semibreve", "C sharp four", "E flat three",
        "add twenty five bars", "delete four bars", "go left one bar", "go right two bars", "go to bar thirty two",
        "time signature three four", "key signature E flat major", "treble clef", "bass clef",
        "dynamic fortissimo", "tempo allegro", "crescendo", "diminuendo", "staccato", "tenuto", "fermata", "trill"
    ]

    public static func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "♯", with: " sharp ")
            .replacingOccurrences(of: "♭", with: " flat ")
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
