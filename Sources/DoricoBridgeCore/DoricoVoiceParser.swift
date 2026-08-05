import Foundation

public extension DoricoVoiceLanguage {
    static func parseBatch(
        _ rawText: String,
        aliases: DoricoVoiceAliasBook = .init(),
        calibration: DoricoVoiceCalibrationProfile = .init()
    ) -> DoricoVoiceBatch {
        let calibrated = calibration.apply(to: rawText)
        let prepared = prepareSeparators(calibrated)
        var commands: [DoricoVoiceCommand] = [], unknown: [String] = []
        for raw in prepared.split(separator: "|").map(String.init) {
            let segment = normalize(raw)
            guard !segment.isEmpty else { continue }
            let resolved = aliases.resolve(segment) ?? segment
            if let parsed = parseDense(resolved, aliases) { commands += parsed } else { unknown.append(segment) }
        }
        return DoricoVoiceBatch(commands: commands, unrecognizedSegments: unknown)
    }

    static func canTeach(canonicalPhrase: String) -> Bool {
        let batch = parseBatch(canonicalPhrase)
        return !batch.commands.isEmpty && batch.unrecognizedSegments.isEmpty
    }

    static func prepareSeparators(_ raw: String) -> String {
        var text = raw.lowercased()
        for mark in [",", ";", ":", ".", "!", "?"] { text = text.replacingOccurrences(of: mark, with: " | ") }
        for pattern in [#"\band then\b"#, #"\bthen\b"#, #"\bafter that\b"#, #"\bfollowed by\b"#] {
            text = text.replacingOccurrences(of: pattern, with: " | ", options: .regularExpression)
        }
        return text.replacingOccurrences(of: "\\s*\\|\\s*", with: "|", options: .regularExpression)
    }

    static func parseDense(_ phrase: String, _ aliases: DoricoVoiceAliasBook) -> [DoricoVoiceCommand]? {
        let phrase = stripFiller(normalize(phrase))
        guard !phrase.isEmpty else { return [] }
        if let alias = aliases.resolve(phrase), alias != phrase { return parseDense(alias, .init()) }
        let words = phrase.split(separator: " ").map(String.init)
        if words.count > 1 {
            for split in stride(from: words.count - 1, through: 1, by: -1) {
                let left = words[..<split].joined(separator: " "), right = words[split...].joined(separator: " ")
                if let first = parseSingle(left, fuzzy: false), let rest = parseDense(right, aliases) { return [first] + rest }
            }
        }
        if let command = parseSingle(phrase, fuzzy: true) { return [command] }
        if let range = phrase.range(of: " and "),
           let left = parseDense(String(phrase[..<range.lowerBound]), aliases),
           let right = parseDense(String(phrase[range.upperBound...]), aliases) { return left + right }
        return nil
    }

    static func parseSingle(_ phrase: String, fuzzy: Bool) -> DoricoVoiceCommand? {
        let phrase = stripFiller(normalize(phrase))
        if let direct = directCommands[phrase] { return direct }
        if let duration = duration(phrase, fuzzy: false) { return duration }
        if let parameter = parameterCommand(phrase) { return parameter }
        if let catalog = catalogCommand(phrase, fuzzy: false) { return catalog }
        if let jumpBar = jumpBarCommand(phrase) { return jumpBar }
        guard fuzzy else { return nil }
        if let duration = duration(phrase, fuzzy: true) { return duration }

        let direct = directCommands.map { (similarity(phrase, $0.key), $0.value) }
            .filter { $0.0 >= ($0.1.canonicalPhrase.split(separator: " ").count <= 2 ? 0.76 : 0.80) }
            .max(by: { $0.0 < $1.0 })?.1
        if let direct { return direct }
        return catalogCommand(phrase, fuzzy: true)
    }

    static func stripFiller(_ phrase: String) -> String {
        var value = " \(phrase) "
        for filler in [" please "," could you "," can you "," would you "," i want you to "," i need you to "," for me "," now "," just "," um "," uh "," dorico "," make it "," set it to "," put in "] {
            value = value.replacingOccurrences(of: filler, with: " ")
        }
        return normalize(value)
    }

    static let directCommands: [String: DoricoVoiceCommand] = {
        var map: [String: DoricoVoiceCommand] = [:]
        func add(_ phrases: [String], _ label: String, _ canonical: String, _ action: CommandAction) {
            let command = DoricoVoiceCommand(label: label, canonicalPhrase: canonical, action: action)
            phrases.forEach { map[normalize($0)] = command }
        }
        add(["undo","undo that","take that back"], "Undo", "undo", .keyChord(KeyChord("z", modifiers: [.command])))
        add(["redo","do that again"], "Redo", "redo", .keyChord(KeyChord("z", modifiers: [.command,.shift])))
        add(["copy","copy selection"], "Copy", "copy", .keyChord(KeyChord("c", modifiers: [.command])))
        add(["paste","paste here"], "Paste", "paste", .keyChord(KeyChord("v", modifiers: [.command])))
        add(["cut","cut selection"], "Cut", "cut", .keyChord(KeyChord("x", modifiers: [.command])))
        add(["delete","delete selection","remove selection"], "Delete selection", "delete selection", .keyChord(KeyChord("delete")))
        add(["select all","select everything"], "Select all", "select all", .keyChord(KeyChord("a", modifiers: [.command])))
        add(["start note input","begin note input","start writing notes"], "Start note input", "start note input", .keyChord(KeyChord("n", modifiers: [.shift])))
        add(["stop note input","end note input","exit note input"], "Stop note input", "stop note input", .keyChord(KeyChord("escape")))
        add(["play","start playback"], "Play", "play", .keyChord(KeyChord("space")))
        add(["stop","stop playback","pause playback"], "Stop", "stop", .keyChord(KeyChord("space")))
        add(["play from selection","play from here"], "Play from selection", "play from selection", .keyChord(KeyChord("p")))
        add(["next note","go to next note"], "Next note", "next note", .keyChord(KeyChord("right")))
        add(["previous note","go to previous note"], "Previous note", "previous note", .keyChord(KeyChord("left")))
        add(["next staff","staff down"], "Next staff", "next staff", .keyChord(KeyChord("down")))
        add(["previous staff","staff up"], "Previous staff", "previous staff", .keyChord(KeyChord("up")))
        add(["extend selection right","select right"], "Extend selection right", "extend selection right", .keyChord(KeyChord("right", modifiers: [.shift])))
        add(["extend selection left","select left"], "Extend selection left", "extend selection left", .keyChord(KeyChord("left", modifiers: [.shift])))
        add(["extend selection up","select up"], "Extend selection up", "extend selection up", .keyChord(KeyChord("up", modifiers: [.shift])))
        add(["extend selection down","select down"], "Extend selection down", "extend selection down", .keyChord(KeyChord("down", modifiers: [.shift])))
        add(["tie","add tie"], "Tie", "add tie", .keyChord(KeyChord("t")))
        add(["dot","dotted note","add dot"], "Toggle rhythm dot", "dotted note", .keyChord(KeyChord(".")))
        add(["rest","toggle rest","rest input"], "Toggle rest input", "rest", .keyChord(KeyChord(",")))
        add(["chord mode","toggle chord mode"], "Toggle chord mode", "chord mode", .keyChord(KeyChord("q")))
        add(["grace note","add grace note"], "Toggle grace note", "grace note", .keyChord(KeyChord("/")))
        add(["natural","natural accidental"], "Natural accidental", "natural", .keyChord(KeyChord("0")))
        add(["sharp","sharp accidental"], "Sharp accidental", "sharp", .keyChord(KeyChord("=")))
        add(["flat","flat accidental"], "Flat accidental", "flat", .keyChord(KeyChord("-")))
        add(["crescendo","add crescendo","get louder"], "Crescendo", "crescendo", popover(KeyChord("d", modifiers:[.shift]), "<"))
        add(["diminuendo","decrescendo","get quieter"], "Diminuendo", "diminuendo", popover(KeyChord("d", modifiers:[.shift]), ">"))
        add(["fermata","add fermata"], "Fermata", "fermata", popover(KeyChord("o", modifiers:[.shift]), "fermata"))
        add(["trill","add trill"], "Trill", "trill", popover(KeyChord("o", modifiers:[.shift]), "tr"))
        for value in ["staccato","tenuto","accent","marcato"] { add([value,"add \(value)","make \(value)"], value.capitalized, value, popover(KeyChord("p", modifiers:[.shift]), value)) }
        return map
    }()

    static func duration(_ phrase: String, fuzzy: Bool) -> DoricoVoiceCommand? {
        let phrase = stripLeading(phrase, ["choose","select","set","use","make","add","enter","input","a","an"])
        let variants: [([String],String,String,String)] = [
            (["128th note","one hundred twenty eighth note"],"1","128th note","128th note"),
            (["64th note","sixty fourth note"],"2","64th note","64th note"),
            (["32nd note","thirty second note","demisemiquaver"],"3","32nd note","32nd note"),
            (["16th note","sixteenth note","semiquaver"],"4","16th note","sixteenth note"),
            (["8th note","eighth note","quaver"],"5","Eighth note","eighth note"),
            (["quarter note","crotchet"],"6","Quarter note","quarter note"),
            (["half note","minim"],"7","Half note","half note"),
            (["whole note","semibreve"],"8","Whole note","whole note"),
            (["double whole note","breve"],"9","Double whole note","double whole note")
        ]
        var best: (Double,DoricoVoiceCommand)?
        for (phrases,key,label,canonical) in variants {
            for candidate in phrases {
                if phrase == candidate { return command(label, canonical: canonical, .keyChord(KeyChord(key))) }
                let score = similarity(phrase, candidate)
                if fuzzy, score >= 0.80, score > (best?.0 ?? 0) { best = (score, command(label, canonical: canonical, .keyChord(KeyChord(key)))) }
            }
        }
        return best?.1
    }
}
