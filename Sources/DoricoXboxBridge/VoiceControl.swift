#if os(macOS)
import AppKit
import AVFoundation
import Combine
import Speech
import SwiftUI
import DoricoBridgeCore

struct VoiceParsedCommand: Identifiable {
    let id = UUID()
    let spokenText: String
    let displayName: String
    let action: CommandAction?
    let recognized: Bool
}

enum DoricoVoiceParser {
    static func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "#♯♭-/ ")).inverted)
            .joined(separator: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    static func parse(_ transcript: String, catalog: [ActionDescriptor]) -> [VoiceParsedCommand] {
        split(transcript).flatMap { chunk in
            if let command = resolve(chunk, catalog: catalog) { return [command] }
            let parts = normalize(chunk).components(separatedBy: " and ").filter { !$0.isEmpty }
            if parts.count > 1 {
                let commands = parts.compactMap { resolve($0, catalog: catalog) }
                if commands.count == parts.count { return commands }
            }
            return [VoiceParsedCommand(spokenText: chunk, displayName: chunk, action: nil, recognized: false)]
        }
    }

    private static func split(_ text: String) -> [String] {
        var value = text
        for separator in [" and then ", " then ", ";", ",", ".", "\n"] {
            value = value.replacingOccurrences(of: separator, with: "|", options: .caseInsensitive)
        }
        return value.split(separator: "|")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func resolve(_ original: String, catalog: [ActionDescriptor]) -> VoiceParsedCommand? {
        let phrase = removeFillers(normalize(original))
        guard !phrase.isEmpty else { return nil }

        if let item = catalog.first(where: {
            normalize($0.title) == phrase || normalize($0.id.replacingOccurrences(of: ".", with: " ")) == phrase
        }) {
            return VoiceParsedCommand(spokenText: original, displayName: item.title, action: item.action, recognized: true)
        }
        if let alias = aliases[phrase] {
            return VoiceParsedCommand(spokenText: original, displayName: alias.0, action: alias.1, recognized: true)
        }
        if let generated = generatedCommand(phrase) {
            return VoiceParsedCommand(spokenText: original, displayName: generated.0, action: generated.1, recognized: true)
        }
        return nil
    }

    private static func removeFillers(_ phrase: String) -> String {
        var words = phrase.split(separator: " ").map(String.init)
        let fillers = ["dorico", "please", "now", "add", "insert", "make", "set", "put", "choose", "select"]
        while let first = words.first, fillers.contains(first) { words.removeFirst() }
        return words.joined(separator: " ")
    }

    private static func popover(_ shortcut: String, _ text: String) -> CommandAction {
        .sequence([
            ActionStep(action: .keyChord(KeyChord(shortcut, modifiers: [.shift])), delayMilliseconds: 0),
            ActionStep(action: .typeText(text), delayMilliseconds: 90),
            ActionStep(action: .keyChord(KeyChord("return")), delayMilliseconds: 50)
        ])
    }

    private static func generatedCommand(_ phrase: String) -> (String, CommandAction)? {
        let notePattern = #"^(?:note )?([a-g])(?: (sharp|flat|natural))?$"#
        if let regex = try? NSRegularExpression(pattern: notePattern),
           let match = regex.firstMatch(in: phrase, range: NSRange(phrase.startIndex..., in: phrase)),
           let pitchRange = Range(match.range(at: 1), in: phrase) {
            let pitch = String(phrase[pitchRange])
            var steps: [ActionStep] = []
            if match.range(at: 2).location != NSNotFound,
               let range = Range(match.range(at: 2), in: phrase) {
                let accidental = String(phrase[range])
                let key = accidental == "sharp" ? "equals" : accidental == "flat" ? "minus" : "0"
                steps.append(ActionStep(action: .keyChord(KeyChord(key)), delayMilliseconds: 0))
            }
            steps.append(ActionStep(action: .keyChord(KeyChord(pitch)), delayMilliseconds: 35))
            return (phrase.uppercased(), .sequence(steps))
        }

        for prefix in ["tempo ", "metronome mark "] where phrase.hasPrefix(prefix) {
            let value = String(phrase.dropFirst(prefix.count))
            if !value.isEmpty { return ("Tempo \(value)", popover("t", value)) }
        }
        if phrase.hasPrefix("time signature ") {
            let value = String(phrase.dropFirst(15)).replacingOccurrences(of: " over ", with: "/")
            return ("Time signature \(value)", popover("m", value))
        }
        if phrase.hasPrefix("key signature ") {
            let value = String(phrase.dropFirst(14))
            return ("Key signature \(value)", popover("k", value))
        }
        if phrase.hasPrefix("clef ") {
            let value = String(phrase.dropFirst(5))
            return ("Clef \(value)", popover("c", value))
        }
        if phrase.hasPrefix("playing technique ") {
            let value = String(phrase.dropFirst(18))
            return ("Playing technique \(value)", popover("p", value))
        }
        if phrase.hasPrefix("ornament ") {
            let value = String(phrase.dropFirst(9))
            return ("Ornament \(value)", popover("o", value))
        }
        return nil
    }

    private static let aliases: [String: (String, CommandAction)] = {
        var result: [String: (String, CommandAction)] = [:]
        func add(_ phrases: [String], _ name: String, _ action: CommandAction) {
            for phrase in phrases { result[phrase] = (name, action) }
        }
        add(["sixteenth", "sixteenth note", "semiquaver"], "16th note", DefaultCatalog.action("duration.16"))
        add(["eighth", "eighth note", "quaver"], "Eighth note", DefaultCatalog.action("duration.8"))
        add(["quarter", "quarter note", "crotchet"], "Quarter note", DefaultCatalog.action("duration.4"))
        add(["half", "half note", "minim"], "Half note", DefaultCatalog.action("duration.2"))
        add(["whole", "whole note", "semibreve"], "Whole note", DefaultCatalog.action("duration.1"))
        add(["dot", "dotted", "rhythm dot", "augmentation dot"], "Rhythm dot", DefaultCatalog.action("duration.dot"))
        add(["tie", "tie notes"], "Tie", DefaultCatalog.action("tie"))
        add(["note input", "start note input"], "Start note input", DefaultCatalog.action("note.input"))
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

        for (spoken, dorico) in [("pianissimo", "pp"), ("piano", "p"), ("mezzo piano", "mp"), ("mezzo forte", "mf"), ("forte", "f"), ("fortissimo", "ff"), ("sforzando", "sfz"), ("crescendo", "<"), ("diminuendo", ">"), ("decrescendo", ">")] {
            add([spoken], spoken.capitalized, popover("d", dorico))
        }
        for clef in ["treble", "bass", "alto", "tenor"] {
            add(["\(clef) clef"], "\(clef.capitalized) clef", popover("c", clef))
        }
        add(["barline", "single barline"], "Barline", popover("b", "|"))
        add(["double barline"], "Double barline", popover("b", "||"))
        add(["final barline"], "Final barline", popover("b", "final"))
        return result
    }()
}

@MainActor
final class DoricoVoiceControl: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var transcript = ""
    @Published var status = "Voice control is off"
    @Published var parsedCommands: [VoiceParsedCommand] = []
    @Published var continuousListening = false
    @Published var executeAutomatically = true
    @Published var languageIdentifier = "en-US"

    private weak var appModel: AppModel?
    private let detector = DoricoDetector()
    private let accessibility = DoricoAccessibility()
    private let midi = VirtualMIDI()
    private lazy var router: ActionRouter? = appModel.map { ActionRouter(detector: detector, accessibility: accessibility, midi: midi, model: $0) }
    private let audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var lastExecuted = ""

    init(appModel: AppModel) {
        self.appModel = appModel
        super.init()
        midi.start()
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: languageIdentifier))
    }

    func toggle() { isListening ? stop() : start() }

    func start() {
        guard !isListening else { return }
        SFSpeechRecognizer.requestAuthorization { [weak self] auth in
            Task { @MainActor in
                guard let self else { return }
                guard auth == .authorized else { self.status = "Speech recognition permission was not granted"; return }
                AVAudioApplication.requestRecordPermission { granted in
                    Task { @MainActor in
                        guard granted else { self.status = "Microphone permission was not granted"; return }
                        self.beginSession()
                    }
                }
            }
        }
    }

    func stop() {
        task?.cancel(); task = nil
        request?.endAudio(); request = nil
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        isListening = false
        status = "Voice control is off"
    }

    func clear() { transcript = ""; parsedCommands = []; lastExecuted = "" }
    func executePreview() { execute(parsedCommands.filter(\.recognized)) }

    func setLanguage(_ id: String) {
        languageIdentifier = id
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: id))
        if isListening { stop(); start() }
    }

    private func beginSession() {
        guard let recognizer, recognizer.isAvailable else { status = "Speech recognition is unavailable"; return }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        self.request = request

        let node = audioEngine.inputNode
        node.removeTap(onBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: node.outputFormat(forBus: 0)) { buffer, _ in request.append(buffer) }
        audioEngine.prepare()
        do { try audioEngine.start() } catch { status = error.localizedDescription; return }
        isListening = true
        status = "Listening for Dorico commands"

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    self.transcript = text
                    self.parsedCommands = DoricoVoiceParser.parse(text, catalog: DefaultCatalog.actions + (self.appModel?.menuCommands ?? []))
                    if result.isFinal, self.executeAutomatically {
                        let normalized = DoricoVoiceParser.normalize(text)
                        if !normalized.isEmpty, normalized != self.lastExecuted {
                            self.lastExecuted = normalized
                            self.execute(self.parsedCommands.filter(\.recognized))
                        }
                    }
                }
                if error != nil || result?.isFinal == true { self.finishCycle() }
            }
        }
    }

    private func execute(_ commands: [VoiceParsedCommand]) {
        guard !commands.isEmpty else { status = "No recognized Dorico commands to run"; return }
        guard detector.runningApplication() != nil else { status = "Dorico Pro is not running"; return }
        guard let router else { status = "Voice action router is unavailable"; return }
        status = "Running \(commands.count) command\(commands.count == 1 ? "" : "s")"
        Task {
            for command in commands {
                if let action = command.action { await router.execute(action) }
                try? await Task.sleep(for: .milliseconds(90))
            }
            status = "Ran \(commands.count) command\(commands.count == 1 ? "" : "s")"
            appModel?.lastAction = "Voice: " + commands.map(\.displayName).joined(separator: " → ")
        }
    }

    private func finishCycle() {
        task = nil; request = nil
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        isListening = false
        if continuousListening {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in Task { @MainActor in self?.start() } }
        } else if status.hasPrefix("Listening") { status = "Voice control is off" }
    }
}

@MainActor
final class VoiceControlWindowController: NSWindowController {
    private static var retained: VoiceControlWindowController?
    static func show(for model: AppModel) {
        if let existing = retained { existing.showWindow(nil); existing.window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let control = DoricoVoiceControl(appModel: model)
        let window = NSWindow(contentViewController: NSHostingController(rootView: VoiceControlView(control: control)))
        window.title = "Dorico Voice Control"
        window.setContentSize(NSSize(width: 720, height: 620))
        window.minSize = NSSize(width: 620, height: 500)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        retained = VoiceControlWindowController(window: window)
        retained?.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct VoiceControlView: View {
    @ObservedObject var control: DoricoVoiceControl
    let languages = [("en-US", "English (US)"), ("en-GB", "English (UK)"), ("nb-NO", "Norwegian Bokmål"), ("pl-PL", "Polish")]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Dorico Voice Control").font(.title2.bold())
                    Text("Speak one command or a whole ordered chain of music instructions.").foregroundStyle(.secondary)
                }
                Spacer()
                Circle().fill(control.isListening ? Color.red : Color.secondary.opacity(0.35)).frame(width: 12, height: 12)
            }
            HStack {
                Button(control.isListening ? "Stop listening" : "Start listening") { control.toggle() }
                Button("Run preview") { control.executePreview() }.disabled(!control.parsedCommands.contains(where: \.recognized))
                Button("Clear") { control.clear() }
                Spacer()
                Picker("Language", selection: Binding(get: { control.languageIdentifier }, set: { control.setLanguage($0) })) {
                    ForEach(languages, id: \.0) { Text($0.1).tag($0.0) }
                }.frame(width: 205)
            }
            HStack(spacing: 24) {
                Toggle("Run final speech automatically", isOn: $control.executeAutomatically)
                Toggle("Keep listening", isOn: $control.continuousListening)
            }
            GroupBox("Heard") {
                Text(control.transcript.isEmpty ? "Say: “eighth note, dotted, C sharp, tie, move right.”" : control.transcript)
                    .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading).textSelection(.enabled).padding(6)
            }
            GroupBox("Split command preview") {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if control.parsedCommands.isEmpty { Text("Commands appear here before they run.").foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading) }
                        ForEach(Array(control.parsedCommands.enumerated()), id: \.element.id) { index, command in
                            HStack(alignment: .top) {
                                Text("\(index + 1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                VStack(alignment: .leading) { Text(command.displayName).fontWeight(.medium); Text("Heard: \(command.spokenText)").font(.caption).foregroundStyle(.secondary) }
                                Spacer()
                                Text(command.recognized ? "Ready" : "Not recognized").font(.caption).foregroundStyle(command.recognized ? .secondary : .red)
                            }.padding(8).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }.padding(6)
                }.frame(minHeight: 210)
            }
            HStack { Image(systemName: "waveform"); Text(control.status); Spacer(); Text("Separate commands with a comma, “then”, or “and then”.").font(.caption).foregroundStyle(.secondary) }
        }.padding(20)
    }
}

extension AppModel { func showVoiceControl() { VoiceControlWindowController.show(for: self) } }
#endif
