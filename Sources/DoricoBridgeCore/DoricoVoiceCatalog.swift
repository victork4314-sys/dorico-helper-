import Foundation

public extension DoricoVoiceLanguage {
    static var supportedCatalogActionCount: Int { DefaultCatalog.actions.count }

    static var catalogSpeechHints: [String] {
        Array(Set(DefaultCatalog.actions.flatMap { descriptor in
            [descriptor.title, spokenCatalogPhrase(from: normalize(descriptor.title))]
        })).filter { !$0.isEmpty }
    }

    static func catalogCommand(_ phrase: String, fuzzy: Bool) -> DoricoVoiceCommand? {
        let phrase = normalize(phrase)
        guard !phrase.isEmpty else { return nil }

        let exactMatches = catalogCandidates.filter { $0.phrase == phrase }
        if let exact = unambiguous(exactMatches) { return exact.command }
        guard fuzzy else { return nil }

        let inputNumbers = numericTokens(in: phrase)
        let inputIsMIDI = phrase.contains("midi")
        let scored = catalogCandidates.compactMap { candidate -> (Double, CatalogCandidate)? in
            if candidate.isMIDI, !inputIsMIDI { return nil }
            let candidateNumbers = numericTokens(in: candidate.phrase)
            if !inputNumbers.isEmpty, !candidateNumbers.isEmpty, inputNumbers != candidateNumbers { return nil }
            return (similarity(phrase, candidate.phrase), candidate)
        }
        .sorted { lhs, rhs in
            if lhs.0 == rhs.0 { return lhs.1.phrase.count < rhs.1.phrase.count }
            return lhs.0 > rhs.0
        }

        guard let best = scored.first else { return nil }
        let tokenCount = phrase.split(separator: " ").count
        let threshold: Double = tokenCount <= 1 ? 0.94 : tokenCount == 2 ? 0.87 : 0.81
        guard best.0 >= threshold else { return nil }

        if let runnerUp = scored.dropFirst().first,
           runnerUp.1.descriptorID != best.1.descriptorID,
           best.0 - runnerUp.0 < 0.035 {
            return nil
        }
        return best.1.command
    }

    static func jumpBarCommand(_ phrase: String) -> DoricoVoiceCommand? {
        let phrase = normalize(phrase)
        let prefixes = [
            "run dorico command ",
            "dorico command ",
            "run command ",
            "use command ",
            "open command ",
            "command "
        ]
        guard let prefix = prefixes.first(where: phrase.hasPrefix) else { return nil }
        let value = String(phrase.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return nil }
        return command(
            "Dorico command: \(value)",
            canonical: "dorico command \(value)",
            .sequence([
                CommandStep(.keyChord(KeyChord("j"))),
                CommandStep(.keyChord(KeyChord("1", modifiers: [.control])), delayMilliseconds: 90),
                CommandStep(.typeText(value), delayMilliseconds: 100),
                CommandStep(.keyChord(KeyChord("return")), delayMilliseconds: 45)
            ])
        )
    }

    private struct CatalogCandidate {
        var phrase: String
        var descriptorID: String
        var isMIDI: Bool
        var command: DoricoVoiceCommand
    }

    private static let catalogNoiseWords: Set<String> = [
        "active", "controller", "current", "dorico", "focused", "for", "keyboard",
        "mode", "selected", "the", "xbox"
    ]

    private static let catalogCandidates: [CatalogCandidate] = {
        var result: [CatalogCandidate] = []
        var seen = Set<String>()

        for descriptor in DefaultCatalog.actions {
            let command = DoricoVoiceCommand(
                label: descriptor.title,
                canonicalPhrase: normalize(descriptor.title),
                action: descriptor.action
            )
            let isMIDI = descriptor.category == "Dorico MIDI Learn" || descriptor.id.hasPrefix("midi.")
            var phrases = Set<String>()
            let normalizedTitle = normalize(descriptor.title)
            phrases.insert(normalizedTitle)
            phrases.insert(spokenCatalogPhrase(from: normalizedTitle))
            phrases.insert(normalize(descriptor.id.replacingOccurrences(of: ".", with: " ")))

            for part in descriptor.title.components(separatedBy: "/") {
                let normalized = normalize(part)
                if !normalized.isEmpty { phrases.insert(normalized) }
            }

            let naturalTitle = removeCatalogNoise(from: normalizedTitle)
            if naturalTitle.split(separator: " ").count >= 2 {
                phrases.insert(naturalTitle)
            }

            for alias in naturalAliases(for: descriptor) {
                let normalized = normalize(alias)
                if !normalized.isEmpty { phrases.insert(normalized) }
            }

            for phrase in phrases where !phrase.isEmpty {
                let key = "\(descriptor.id)|\(phrase)"
                guard seen.insert(key).inserted else { continue }
                result.append(CatalogCandidate(
                    phrase: phrase,
                    descriptorID: descriptor.id,
                    isMIDI: isMIDI,
                    command: command
                ))
            }
        }
        return result
    }()


    private static func spokenCatalogPhrase(from phrase: String) -> String {
        var output: [String] = []
        let pitchPattern = try? NSRegularExpression(pattern: #"^([a-g])([0-9])$"#)
        for token in phrase.split(separator: " ").map(String.init) {
            if let value = Int(token), let words = spokenNumber(value) {
                output.append(words)
                continue
            }
            if let pitchPattern,
               let match = pitchPattern.firstMatch(in: token, range: NSRange(token.startIndex..., in: token)),
               let letterRange = Range(match.range(at: 1), in: token),
               let octaveRange = Range(match.range(at: 2), in: token),
               let octave = Int(token[octaveRange]),
               let words = spokenNumber(octave) {
                output.append(String(token[letterRange]))
                output.append(words)
                continue
            }
            output.append(token)
        }
        return output.joined(separator: " ")
    }

    private static func spokenNumber(_ value: Int) -> String? {
        guard (0...9999).contains(value) else { return nil }
        let small = [
            "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
            "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen",
            "seventeen", "eighteen", "nineteen"
        ]
        let tens = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]
        if value < 20 { return small[value] }
        if value < 100 {
            let remainder = value % 10
            return remainder == 0 ? tens[value / 10] : "\(tens[value / 10]) \(small[remainder])"
        }
        if value < 1000 {
            let remainder = value % 100
            let prefix = "\(small[value / 100]) hundred"
            return remainder == 0 ? prefix : "\(prefix) \(spokenNumber(remainder) ?? "")"
        }
        let remainder = value % 1000
        let prefix = "\(small[value / 1000]) thousand"
        return remainder == 0 ? prefix : "\(prefix) \(spokenNumber(remainder) ?? "")"
    }

    private static func removeCatalogNoise(from phrase: String) -> String {
        phrase.split(separator: " ")
            .map(String.init)
            .filter { !catalogNoiseWords.contains($0) }
            .joined(separator: " ")
    }

    private static func naturalAliases(for descriptor: ActionDescriptor) -> [String] {
        switch descriptor.id {
        case "place.note":
            return ["place note", "write note", "enter selected note"]
        case "pitch.up":
            return ["pitch up", "move pitch up", "raise note"]
        case "pitch.down":
            return ["pitch down", "move pitch down", "lower note"]
        case "activate":
            return ["confirm", "press return", "activate control"]
        case "cancel":
            return ["cancel", "close", "escape"]
        case "navigate.left":
            return ["navigate left", "selection left"]
        case "navigate.right":
            return ["navigate right", "selection right"]
        case "navigate.up":
            return ["navigate up", "selection up"]
        case "navigate.down":
            return ["navigate down", "selection down"]
        case "access.scan.next":
            return ["next zone", "next accessible zone"]
        case "access.scan.previous":
            return ["previous zone", "previous accessible zone"]
        case "access.press":
            return ["press focused control", "activate focused control"]
        case "access.increment":
            return ["increase focused value", "increment value"]
        case "access.decrement":
            return ["decrease focused value", "decrement value"]
        case "access.menu":
            return ["focused control menu", "show control menu"]
        case "pointer.toggle":
            return ["pointer mode", "toggle pointer"]
        case "pointer.click":
            return ["left click", "click pointer"]
        case "pointer.double":
            return ["double click", "double click pointer"]
        case "pointer.right":
            return ["right click", "right click pointer"]
        case "bridge.dashboard":
            return ["open command area", "show command area", "open dashboard"]
        case "bridge.toggle":
            return ["toggle command area", "toggle dashboard"]
        case "xbox.jump.commands":
            return ["jump bar commands", "open jump bar commands"]
        case "xbox.jump.goto":
            return ["jump bar go to", "open jump bar go to"]
        default:
            return []
        }
    }

    private static func unambiguous(_ candidates: [CatalogCandidate]) -> CatalogCandidate? {
        guard let first = candidates.first else { return nil }
        return candidates.allSatisfy { $0.descriptorID == first.descriptorID } ? first : nil
    }

    private static func numericTokens(in phrase: String) -> Set<String> {
        Set(phrase.split(separator: " ").map(String.init).filter { Int($0) != nil })
    }
}
