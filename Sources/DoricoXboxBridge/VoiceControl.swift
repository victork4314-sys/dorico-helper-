#if os(macOS)
import AppKit
import AVFoundation
import Combine
import Speech
import SwiftUI
import DoricoBridgeCore

@MainActor
final class DoricoVoiceControl: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var transcript = ""
    @Published var status = "Voice control is off"
    @Published var parsedCommands: [VoiceParsedCommand] = []
    @Published var continuousListening = false
    @Published var executeAutomatically = true
    @Published var languageIdentifier = Locale.current.identifier

    private weak var appModel: AppModel?
    private let detector = DoricoDetector()
    private let accessibility = DoricoAccessibility()
    private let midi = VirtualMIDI()
    private lazy var router: ActionRouter? = {
        guard let appModel else { return nil }
        return ActionRouter(detector: detector, accessibility: accessibility, midi: midi, model: appModel)
    }()

    private let audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var lastExecutedTranscript = ""
    private var restartWorkItem: DispatchWorkItem?

    init(appModel: AppModel) {
        self.appModel = appModel
        super.init()
        midi.start()
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: languageIdentifier))
    }

    func toggleListening() {
        isListening ? stopListening(userInitiated: true) : startListening()
    }

    func startListening() {
        guard !isListening else { return }
        restartWorkItem?.cancel()

        SFSpeechRecognizer.requestAuthorization { [weak self] authorization in
            Task { @MainActor in
                guard let self else { return }
                guard authorization == .authorized else {
                    self.status = "Speech recognition permission was not granted"
                    return
                }
                AVAudioApplication.requestRecordPermission { granted in
                    Task { @MainActor in
                        guard granted else {
                            self.status = "Microphone permission was not granted"
                            return
                        }
                        self.beginRecognitionSession()
                    }
                }
            }
        }
    }

    func stopListening(userInitiated: Bool = true) {
        restartWorkItem?.cancel()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        isListening = false
        if userInitiated { status = "Voice control is off" }
    }

    func executePreview() {
        let executable = parsedCommands.filter { $0.action != nil }
        guard !executable.isEmpty else {
            status = "No recognized Dorico commands to run"
            return
        }
        execute(executable)
    }

    func clear() {
        transcript = ""
        parsedCommands = []
        lastExecutedTranscript = ""
        status = isListening ? "Listening for Dorico commands" : "Voice control is off"
    }

    func setLanguage(_ identifier: String) {
        languageIdentifier = identifier
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: identifier))
        if isListening {
            stopListening(userInitiated: false)
            startListening()
        }
    }

    private func beginRecognitionSession() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            status = "Speech recognition is currently unavailable"
            return
        }

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
            status = "Listening for Dorico commands"
        } catch {
            status = "Could not start the microphone: \(error.localizedDescription)"
            return
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.handleRecognition(result.bestTranscription.formattedString, isFinal: result.isFinal)
                }
                if error != nil || result?.isFinal == true {
                    self.finishRecognitionCycle()
                }
            }
        }
    }

    private func handleRecognition(_ text: String, isFinal: Bool) {
        transcript = text
        parsedCommands = DoricoVoiceParser.parse(text, catalog: DefaultCatalog.actions + (appModel?.menuCommands ?? []))

        guard executeAutomatically, isFinal else { return }
        let normalized = DoricoVoiceParser.normalize(text)
        guard !normalized.isEmpty, normalized != lastExecutedTranscript else { return }
        lastExecutedTranscript = normalized
        execute(parsedCommands.filter { $0.action != nil })
    }

    private func execute(_ commands: [VoiceParsedCommand]) {
        guard detector.runningApplication() != nil else {
            status = "Dorico Pro is not running"
            return
        }
        guard let router else {
            status = "Voice action router is unavailable"
            return
        }

        status = "Running \(commands.count) Dorico command\(commands.count == 1 ? "" : "s")"
        Task {
            for command in commands {
                guard let action = command.action else { continue }
                await router.execute(action)
                try? await Task.sleep(for: .milliseconds(90))
            }
            status = "Ran \(commands.count) command\(commands.count == 1 ? "" : "s")"
            appModel?.lastAction = "Voice: " + commands.map(\.displayName).joined(separator: " → ")
        }
    }

    private func finishRecognitionCycle() {
        recognitionTask = nil
        recognitionRequest = nil
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        isListening = false

        guard continuousListening else {
            if status.hasPrefix("Listening") { status = "Voice control is off" }
            return
        }

        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.startListening() }
        }
        restartWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }
}

struct VoiceParsedCommand: Identifiable {
    let id = UUID()
    var spokenText: String
    var displayName: String
    var action: CommandAction?
    var confidence: VoiceCommandConfidence
}

enum VoiceCommandConfidence: String {
    case exact = "Exact"
    case alias = "Music term"
    case unresolved = "Not recognized"
}

enum DoricoVoiceParser {
    static func parse(_ transcript: String, catalog: [ActionDescriptor]) -> [VoiceParsedCommand] {
        let chunks = splitCommands(transcript)
        return chunks.flatMap { resolveChunk($0, catalog: catalog) }
    }

    static func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "#♯♭- ")).inverted)
            .joined(separator: " ")
            .split(whereSeparator: \ .isWhitespace)
            .joined(separator: " ")
    }

    private static func splitCommands(_ transcript: String) -> [String] {
        var text = transcript
        let strongSeparators = [" and then ", " then ", ";", ",", ".", "\n"]
        for separator in strongSeparators {
            text = text.replacingOccurrences(of: separator, with: "|", options: [.caseInsensitive])
        }
        return text.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private static func resolveChunk(_ chunk: String, catalog: [ActionDescriptor]) -> [VoiceParsedCommand] {
        let normalized = normalize(chunk)
        guard !normalized.isEmpty else { return [] }

        if let resolved = resolveSingle(normalized, original: chunk, catalog: catalog) {
            return [resolved]
        }

        // Plain “and” is only treated as a separator when every resulting part
        // is independently understood. This preserves names such as “bars and barlines”.
        let parts = normalized.components(separatedBy: " and ").filter { !$0.isEmpty }
        if parts.count > 1 {
            let resolved = parts.compactMap { resolveSingle($0, original: $0, catalog: catalog) }
            if resolved.count == parts.count { return resolved }
        }

        return [VoiceParsedCommand(spokenText: chunk, displayName: chunk, action: nil, confidence: .unresolved)]
    }

    private static func resolveSingle(_ phrase: String, original: String, catalog: [ActionDescriptor]) -> VoiceParsedCommand? {
        let fillerRemoved = removeFillers(phrase)
        let candidates = [phrase, fillerRemoved]

        for candidate in candidates {
            if let descriptor = catalog.first(where: {
                normalize($0.title) == candidate || normalize($0.id.replacingOccurrences(of: ".", with: " ")) == candidate
            }) {
                return VoiceParsedCommand(spokenText: original, displayName: descriptor.title, action: descriptor.action, confidence: .exact)
            }
        }

        if let alias = aliases[fillerRemoved] ?? aliases[phrase] {
            return VoiceParsedCommand(spokenText: original, displayName: alias.name, action: alias.action, confidence: .alias)
        }

        if let dynamic = dynamicMusicCommand(fillerRemoved) {
            return VoiceParsedCommand(spokenText: original, displayName: dynamic.name, action: dynamic.action, confidence: .alias)
        }

        let fuzzy = catalog
            .map { ($0, tokenScore(fillerRemoved, normalize($0.title))) }
            .filter { $0.1 >= 0.88 }
            .sorted { $0.1 > $1.1 }
            .first
        if let fuzzy {
            return VoiceParsedCommand(spokenText: original, displayName: fuzzy.0.title, action: fuzzy.0.action, confidence: .exact)
        }
        return nil
    }

    private static func removeFillers(_ phrase: String) -> String {
        var words = phrase.split(separator: " ").map(String.init)
        let leading = ["dorico", "please", "now", "add", "insert", "make", "set", "put", "choose", "select"]
        while let first = words.first, leading.contains(first) { words.removeFirst() }
        return words.joined(separator: " ")
    }

    private static func tokenScore(_ lhs: String, _ rhs: String) -> Double {
        let left = Set(lhs.split(separator: " "))
        let right = Set(rhs.split(separator: " "))
        guard !left.isEmpty, !right.isEmpty else { return 0 }
        return Double(left.intersection(right).count) / Double(left.union(right).count)
    }

    private static func popover(shortcut: String, text: String) -> CommandAction {
        .sequence([
            ActionStep(action: .keyChord(KeyChord(shortcut, modifiers: [.shift])), delayMilliseconds: 0),
            ActionStep(action: .typeText(text), delayMilliseconds: 80),
            ActionStep(action: .keyChord(KeyChord("return")), delayMilliseconds: 50)
        ])
    }

    private static func dynamicMusicCommand(_ phrase: String) -> (name: String, action: CommandAction)? {
        let notePattern = #"^(?:note )?([a-g])(?: (sharp|flat|natural))?$"#
        if let regex = try? NSRegularExpression(pattern: notePattern),
           let match = regex.firstMatch(in: phrase, range: NSRange(phrase.startIndex..., in: phrase)),
           let pitchRange = Range(match.range(at: 1), in: phrase) {
            let pitch = String(phrase[pitchRange])
            var steps: [ActionStep] = []
            if match.range(at: 2).location != NSNotFound,
               let accidentalRange = Range(match.range(at: 2), in: phrase) {
                let accidental = String(phrase[accidentalRange])
                let key = accidental == "sharp" ? "equals" : accidental == "flat" ? "minus" : "0"
                steps.append(ActionStep(action: .keyChord(KeyChord(key)), delayMilliseconds: 0))
            }
            steps.append(ActionStep(action: .keyChord(KeyChord(pitch)), delayMilliseconds: 35))
            return (phrase.uppercased(), .sequence(steps))
        }

        let tempoPrefixes = ["tempo ", "metronome mark "]
        for prefix in tempoPrefixes where phrase.hasPrefix(prefix) {
            let value = String(phrase.dropFirst(prefix.count))
            guard !value.isEmpty else { continue }
            return ("Tempo \(value)", popover(shortcut: "t", text: value))
        }
        if phrase.hasPrefix("time signature ") {
            let value = String(phrase.dropFirst("time signature ".count)).replacingOccurrences(of: " over ", with: "/")
            return ("Time signature \(value)", popover(shortcut: "m", text: value))
        }
        if phrase.hasPrefix("key signature ") {
            let value = String(phrase.dropFirst("key signature ".count))
            return ("Key signature \(value)", popover(shortcut: "k", text: value))
        }
        if phrase.hasPrefix("clef ") {
            let value = String(phrase.dropFirst("clef ".count))
            return ("Clef \(value)", popover(shortcut: "c", text: value))
        }
        if phrase.hasPrefix("playing technique ") {
            let value = String(phrase.dropFirst("playing technique ".count))
            return ("Playing technique \(value)", popover(shortcut: "p", text: value))
        }
        if phrase.hasPrefix("ornament ") {
            let value = String(phrase.dropFirst("ornament ".count))
            return ("Ornament \(value)", popover(shortcut: "o", text: value))
        }
        return nil
    }

    private static let aliases: [String: (name: String, action: CommandAction)] = {
        var map: [String: (String, CommandAction)] = [:]
        func add(_ phrases: [String], _ name: String, _ action: CommandAction) {
            for phrase in phrases { map[phrase] = (name, action) }
        }

        add(["sixteenth", "sixteenth note", "semiquaver"], "16th note", DefaultCatalog.action("duration.16"))
        add(["eighth", "eighth note", "quaver"], "Eighth note", DefaultCatalog.action("duration.8"))
        add(["quarter", "quarter note", "crotchet"], "Quarter note", DefaultCatalog.action("duration.4"))
        add(["half", "half note", "minim"], "Half note", DefaultCatalog.action("duration.2"))
        add(["whole", "whole note", "semibreve"], "Whole note", DefaultCatalog.action("duration.1"))
        add(["dot", "dotted", "rhythm dot", "augmentation dot"], "Rhythm dot", DefaultCatalog.action("duration.dot"))
        add(["tie", "tie notes"], "Tie", DefaultCatalog.action("tie"))
        add(["start note input", "note input"], "Start note input", DefaultCatalog.action("note.input"))
        add(["delete", "delete selection", "remove selection"], "Delete selection", DefaultCatalog.action("delete"))
        add(["undo"], "Undo", DefaultCatalog.action("undo"))
        add(["redo"], "Redo", DefaultCatalog.action("redo"))
        add(["play", "stop", "playback", "play stop"], "Play / Stop", DefaultCatalog.action("play"))
        add(["left", "move left", "previous note"], "Move selection left", DefaultCatalog.action("navigate.left"))
        add(["right", "move right", "next note"], "Move selection right", DefaultCatalog.action("navigate.right"))
        add(["up", "move up"], "Move selection up", DefaultCatalog.action("navigate.up"))
        add(["down", "move down"], "Move selection down", DefaultCatalog.action("navigate.down"))
        add(["confirm", "enter", "return", "okay"], "Confirm", DefaultCatalog.action("activate"))
        add(["cancel", "escape", "close"], "Cancel", DefaultCatalog.action("cancel"))

        let dynamics: [(String, String)] = [
            ("pianissimo", "pp"), ("piano", "p"), ("mezzo piano", "mp"),
            ("mezzo forte", "mf"), ("forte", "f"), ("fortissimo", "ff"),
            ("sforzando", "sfz"), ("crescendo", "<"), ("diminuendo", ">"), ("decrescendo", ">")
        ]
        for (spoken, dorico) in dynamics {
            add([spoken], spoken.capitalized, popover(shortcut: "d", text: dorico))
        }
        add(["treble clef"], "Treble clef", popover(shortcut: "c", text: "treble"))
        add(["bass clef"], "Bass clef", popover(shortcut: "c", text: "bass"))
        add(["alto clef"], "Alto clef", popover(shortcut: "c", text: "alto"))
        add(["tenor clef"], "Tenor clef", popover(shortcut: "c", text: "tenor"))
        add(["barline", "single barline"], "Barline", popover(shortcut: "b", text: "|"))
        add(["double barline"], "Double barline", popover(shortcut: "b", text: "||"))
        add(["final barline"], "Final barline", popover(shortcut: "b", text: "final"))
        return map
    }()
}

@MainActor
final class VoiceControlWindowController: NSWindowController {
    private static var retained: VoiceControlWindowController?

    static func show(for model: AppModel) {
        if let existing = retained {
            existing.showWindow(nil)
            existing.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let control = DoricoVoiceControl(appModel: model)
        let root = VoiceControlView(control: control)
        let window = NSWindow(contentViewController: NSHostingController(rootView: root))
        window.title = "Dorico Voice Control"
        window.setContentSize(NSSize(width: 720, height: 620))
        window.minSize = NSSize(width: 620, height: 500)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        let controller = VoiceControlWindowController(window: window)
        retained = controller
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct VoiceControlView: View {
    @ObservedObject var control: DoricoVoiceControl

    private let languages = [
        ("en-US", "English (US)"), ("en-GB", "English (UK)"),
        ("nb-NO", "Norwegian Bokmål"), ("pl-PL", "Polish")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dorico Voice Control").font(.title2.bold())
                    Text("Speak one command or a whole ordered chain of music instructions.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Circle()
                    .fill(control.isListening ? Color.red : Color.secondary.opacity(0.35))
                    .frame(width: 12, height: 12)
            }

            HStack(spacing: 12) {
                Button(control.isListening ? "Stop listening" : "Start listening") { control.toggleListening() }
                    .keyboardShortcut(.space, modifiers: [.command])
                Button("Run preview") { control.executePreview() }
                    .disabled(control.parsedCommands.allSatisfy { $0.action == nil })
                Button("Clear") { control.clear() }
                Spacer()
                Picker("Language", selection: Binding(
                    get: { control.languageIdentifier },
                    set: { control.setLanguage($0) }
                )) {
                    ForEach(languages, id: \.0) { Text($0.1).tag($0.0) }
                }
                .frame(width: 205)
            }

            HStack(spacing: 24) {
                Toggle("Run final speech automatically", isOn: $control.executeAutomatically)
                Toggle("Keep listening", isOn: $control.continuousListening)
            }

            GroupBox("Heard") {
                Text(control.transcript.isEmpty ? "Say: “eighth note, dotted, C sharp, tie, move right.”" : control.transcript)
                    .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
                    .textSelection(.enabled)
                    .padding(6)
            }

            GroupBox("Split command preview") {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if control.parsedCommands.isEmpty {
                            Text("Commands appear here before they run.")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        ForEach(Array(control.parsedCommands.enumerated()), id: \.element.id) { index, command in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(command.displayName).fontWeight(.medium)
                                    Text("Heard: \(command.spokenText)").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(command.confidence.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(command.action == nil ? .red : .secondary)
                            }
                            .padding(8)
                            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(6)
                }
                .frame(minHeight: 210)
            }

            HStack {
                Image(systemName: "waveform")
                Text(control.status)
                Spacer()
                Text("Separators: comma, “then”, “and then”, or a pause")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
    }
}

extension AppModel {
    func showVoiceControl() {
        VoiceControlWindowController.show(for: self)
    }
}
#endif
