#if os(macOS)
import AppKit
import AVFoundation
import Speech
import SwiftUI
import DoricoBridgeCore

@MainActor
final class DoricoVoiceControl: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var transcript = ""
    @Published var lastRecognizedCommand = "None"
    @Published var status = "Voice control is off"
    @Published var requireDoricoPrefix = false
    @Published var showCommandReference = true

    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var lastExecutedNormalizedText = ""
    private var lastExecutionTime = Date.distantPast

    private let detector = DoricoDetector()
    private let accessibility = DoricoAccessibility()
    private let midi = VirtualMIDI()
    private let router: ActionRouter
    private weak var model: AppModel?

    init(model: AppModel) {
        self.model = model
        self.router = ActionRouter(
            detector: detector,
            accessibility: accessibility,
            midi: midi,
            model: model
        )
        super.init()
        midi.start()
    }

    deinit {
        audioEngine.stop()
        recognitionTask?.cancel()
    }

    func toggleListening() {
        isListening ? stopListening() : requestPermissionAndStart()
    }

    func requestPermissionAndStart() {
        SFSpeechRecognizer.requestAuthorization { [weak self] speechStatus in
            AVAudioApplication.requestRecordPermission { microphoneGranted in
                Task { @MainActor in
                    guard let self else { return }
                    guard speechStatus == .authorized else {
                        self.status = "Speech Recognition permission is required"
                        return
                    }
                    guard microphoneGranted else {
                        self.status = "Microphone permission is required"
                        return
                    }
                    self.startListening()
                }
            }
        }
    }

    func startListening() {
        guard !isListening else { return }
        guard recognizer?.isAvailable == true else {
            status = "Speech recognition is unavailable"
            return
        }

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else {
            status = "Could not create a speech request"
            return
        }
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = recognizer?.supportsOnDeviceRecognition == true

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            status = "Microphone could not start: \(error.localizedDescription)"
            return
        }

        isListening = true
        status = "Listening for Dorico music commands"
        recognitionTask = recognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    self.transcript = text
                    self.consumeTranscript(text, isFinal: result.isFinal)
                }
                if error != nil {
                    self.restartAfterRecognitionEnded()
                }
            }
        }
    }

    func stopListening() {
        guard isListening else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
        status = "Voice control is off"
    }

    private func restartAfterRecognitionEnded() {
        guard isListening else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            startListening()
        }
    }

    private func consumeTranscript(_ rawText: String, isFinal: Bool) {
        let normalized = VoiceMusicCommandParser.normalize(rawText)
        guard !normalized.isEmpty else { return }
        guard !requireDoricoPrefix || normalized.hasPrefix("dorico ") else {
            status = "Waiting for a command beginning with “Dorico”"
            return
        }

        let commandText = normalized.hasPrefix("dorico ")
            ? String(normalized.dropFirst("dorico ".count))
            : normalized

        guard let parsed = VoiceMusicCommandParser.parse(commandText) else {
            if isFinal { status = "No Dorico command recognized" }
            return
        }

        let now = Date()
        guard commandText != lastExecutedNormalizedText || now.timeIntervalSince(lastExecutionTime) > 1.4 else { return }
        lastExecutedNormalizedText = commandText
        lastExecutionTime = now
        lastRecognizedCommand = parsed.label
        status = "Running: \(parsed.label)"
        model?.lastAction = "Voice: \(parsed.label)"
        model?.log("Voice command: \(parsed.label)")

        Task {
            await router.execute(parsed.action)
            status = "Ready for the next music command"
        }
    }
}

private struct ParsedVoiceMusicCommand {
    let label: String
    let action: CommandAction
}

private enum VoiceMusicCommandParser {
    static func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "♯", with: " sharp ")
            .replacingOccurrences(of: "♭", with: " flat ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "[^a-z0-9/ ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parse(_ phrase: String) -> ParsedVoiceMusicCommand? {
        let p = normalize(phrase)

        if let simple = simpleCommands[p] { return simple }
        if let duration = durationCommand(in: p) { return duration }
        if let pitch = pitchCommand(in: p) { return pitch }
        if let dynamic = popoverValue(in: p, introductions: ["add dynamic", "dynamic", "mark"], shortcut: KeyChord("d", modifiers: [.shift]), label: "Dynamic") { return dynamic }
        if let technique = popoverValue(in: p, introductions: ["add playing technique", "playing technique", "add technique", "technique"], shortcut: KeyChord("p", modifiers: [.shift]), label: "Playing technique") { return technique }
        if let ornament = popoverValue(in: p, introductions: ["add ornament", "ornament"], shortcut: KeyChord("o", modifiers: [.shift]), label: "Ornament") { return ornament }
        if let tempo = popoverValue(in: p, introductions: ["add tempo", "tempo"], shortcut: KeyChord("t", modifiers: [.shift]), label: "Tempo") { return tempo }
        if let meter = popoverValue(in: p, introductions: ["add time signature", "time signature", "meter"], shortcut: KeyChord("m", modifiers: [.shift]), label: "Time signature") { return meter }
        if let key = popoverValue(in: p, introductions: ["add key signature", "key signature", "key"], shortcut: KeyChord("k", modifiers: [.shift]), label: "Key signature") { return key }
        if let clef = popoverValue(in: p, introductions: ["add clef", "clef"], shortcut: KeyChord("c", modifiers: [.shift]), label: "Clef") { return clef }
        if let bar = popoverValue(in: p, introductions: ["add bars", "add bar", "bars", "bar"], shortcut: KeyChord("b", modifiers: [.shift]), label: "Bars") { return bar }
        if let rehearsal = popoverValue(in: p, introductions: ["add rehearsal mark", "rehearsal mark"], shortcut: KeyChord("a", modifiers: [.shift, .command]), label: "Rehearsal mark") { return rehearsal }

        return nil
    }

    private static let simpleCommands: [String: ParsedVoiceMusicCommand] = [
        "undo": command("Undo", .keyChord(KeyChord("z", modifiers: [.command]))),
        "redo": command("Redo", .keyChord(KeyChord("z", modifiers: [.command, .shift]))),
        "copy": command("Copy", .keyChord(KeyChord("c", modifiers: [.command]))),
        "paste": command("Paste", .keyChord(KeyChord("v", modifiers: [.command]))),
        "cut": command("Cut", .keyChord(KeyChord("x", modifiers: [.command]))),
        "delete": command("Delete selection", .keyChord(KeyChord("delete"))),
        "delete selection": command("Delete selection", .keyChord(KeyChord("delete"))),
        "select all": command("Select all", .keyChord(KeyChord("a", modifiers: [.command]))),
        "start note input": command("Start note input", .keyChord(KeyChord("return"))),
        "stop note input": command("Stop note input", .keyChord(KeyChord("escape"))),
        "play": command("Play", .keyChord(KeyChord("space"))),
        "stop": command("Stop", .keyChord(KeyChord("space"))),
        "play from selection": command("Play from selection", .keyChord(KeyChord("p"))),
        "next note": command("Next note", .keyChord(KeyChord("right"))),
        "previous note": command("Previous note", .keyChord(KeyChord("left"))),
        "next staff": command("Next staff", .keyChord(KeyChord("down"))),
        "previous staff": command("Previous staff", .keyChord(KeyChord("up"))),
        "extend selection right": command("Extend selection right", .keyChord(KeyChord("right", modifiers: [.shift]))),
        "extend selection left": command("Extend selection left", .keyChord(KeyChord("left", modifiers: [.shift]))),
        "extend selection up": command("Extend selection up", .keyChord(KeyChord("up", modifiers: [.shift]))),
        "extend selection down": command("Extend selection down", .keyChord(KeyChord("down", modifiers: [.shift]))),
        "tie": command("Tie", .keyChord(KeyChord("t"))),
        "add tie": command("Tie", .keyChord(KeyChord("t"))),
        "dot": command("Toggle rhythm dot", .keyChord(KeyChord("."))),
        "dotted note": command("Toggle rhythm dot", .keyChord(KeyChord("."))),
        "rest": command("Toggle rest input", .keyChord(KeyChord(","))),
        "toggle rest": command("Toggle rest input", .keyChord(KeyChord(","))),
        "chord mode": command("Toggle chord mode", .keyChord(KeyChord("q"))),
        "grace note": command("Toggle grace note", .keyChord(KeyChord("/"))),
        "natural": command("Natural accidental", .keyChord(KeyChord("0"))),
        "sharp": command("Sharp accidental", .keyChord(KeyChord("="))),
        "flat": command("Flat accidental", .keyChord(KeyChord("-"))),
        "crescendo": popover("Crescendo", shortcut: KeyChord("d", modifiers: [.shift]), value: "<"),
        "diminuendo": popover("Diminuendo", shortcut: KeyChord("d", modifiers: [.shift]), value: ">"),
        "decrescendo": popover("Decrescendo", shortcut: KeyChord("d", modifiers: [.shift]), value: ">"),
        "fermata": popover("Fermata", shortcut: KeyChord("o", modifiers: [.shift]), value: "fermata"),
        "trill": popover("Trill", shortcut: KeyChord("o", modifiers: [.shift]), value: "tr"),
        "staccato": popover("Staccato", shortcut: KeyChord("p", modifiers: [.shift]), value: "staccato"),
        "tenuto": popover("Tenuto", shortcut: KeyChord("p", modifiers: [.shift]), value: "tenuto"),
        "accent": popover("Accent", shortcut: KeyChord("p", modifiers: [.shift]), value: "accent"),
        "marcato": popover("Marcato", shortcut: KeyChord("p", modifiers: [.shift]), value: "marcato")
    ]

    private static func durationCommand(in phrase: String) -> ParsedVoiceMusicCommand? {
        let variants: [(terms: [String], key: String, label: String)] = [
            (["one hundred twenty eighth note", "128th note"], "1", "128th note"),
            (["sixty fourth note", "64th note"], "2", "64th note"),
            (["thirty second note", "32nd note"], "3", "32nd note"),
            (["sixteenth note", "16th note", "semiquaver"], "4", "16th note"),
            (["eighth note", "8th note", "quaver"], "5", "Eighth note"),
            (["quarter note", "crotchet"], "6", "Quarter note"),
            (["half note", "minim"], "7", "Half note"),
            (["whole note", "semibreve"], "8", "Whole note"),
            (["double whole note", "breve"], "9", "Double whole note")
        ]
        for variant in variants where variant.terms.contains(where: phrase.contains) {
            return command(variant.label, .keyChord(KeyChord(variant.key)))
        }
        return nil
    }

    private static func pitchCommand(in phrase: String) -> ParsedVoiceMusicCommand? {
        let pattern = #"(?:add|enter|play|note)?\s*([a-g])(?:\s*(sharp|flat|natural))?(?:\s*(minus\s*1|[0-9]))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: phrase, range: NSRange(phrase.startIndex..., in: phrase)),
              match.range.location == 0,
              let letterRange = Range(match.range(at: 1), in: phrase) else { return nil }

        let letter = String(phrase[letterRange]).uppercased()
        var accidental = ""
        if let range = Range(match.range(at: 2), in: phrase) {
            switch String(phrase[range]) {
            case "sharp": accidental = "#"
            case "flat": accidental = "b"
            default: break
            }
        }
        var octave = ""
        if let range = Range(match.range(at: 3), in: phrase) {
            octave = String(phrase[range]).replacingOccurrences(of: "minus ", with: "-")
        }
        let value = letter + accidental + octave
        guard value.count >= 1 else { return nil }
        return command("Enter \(value)", .typeText(value))
    }

    private static func popoverValue(
        in phrase: String,
        introductions: [String],
        shortcut: KeyChord,
        label: String
    ) -> ParsedVoiceMusicCommand? {
        for introduction in introductions where phrase.hasPrefix(introduction + " ") {
            let value = String(phrase.dropFirst(introduction.count + 1)).trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty else { continue }
            return popover("\(label): \(value)", shortcut: shortcut, value: value)
        }
        return nil
    }

    private static func popover(_ label: String, shortcut: KeyChord, value: String) -> ParsedVoiceMusicCommand {
        command(label, .sequence([
            CommandStep(action: .keyChord(shortcut), delayMilliseconds: 0),
            CommandStep(action: .typeText(value), delayMilliseconds: 80),
            CommandStep(action: .keyChord(KeyChord("return")), delayMilliseconds: 40)
        ]))
    }

    private static func command(_ label: String, _ action: CommandAction) -> ParsedVoiceMusicCommand {
        ParsedVoiceMusicCommand(label: label, action: action)
    }
}

struct DoricoVoiceControlView: View {
    @StateObject private var voice: DoricoVoiceControl

    init(model: AppModel) {
        _voice = StateObject(wrappedValue: DoricoVoiceControl(model: model))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dorico Voice Control").font(.title2.weight(.semibold))
                    Text("Speak notation and music terms directly to Dorico Pro 6.1")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(voice.isListening ? "Stop Listening" : "Start Listening") {
                    voice.toggleListening()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.space, modifiers: [.command, .shift])
            }

            HStack(spacing: 10) {
                Image(systemName: voice.isListening ? "waveform.circle.fill" : "waveform.circle")
                    .font(.title2)
                    .foregroundStyle(voice.isListening ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(voice.status).fontWeight(.medium)
                    Text("Last command: \(voice.lastRecognizedCommand)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            GroupBox("Live transcript") {
                Text(voice.transcript.isEmpty ? "Your speech will appear here." : voice.transcript)
                    .frame(maxWidth: .infinity, minHeight: 66, alignment: .topLeading)
                    .textSelection(.enabled)
                    .padding(8)
            }

            Toggle("Require commands to begin with “Dorico”", isOn: $voice.requireDoricoPrefix)
            Toggle("Show command examples", isOn: $voice.showCommandReference)

            if voice.showCommandReference {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        commandGroup("Notes and rhythm", "C sharp four · quarter note · dotted note · rest · chord mode · add tie")
                        commandGroup("Dynamics and expression", "crescendo · diminuendo · dynamic fortissimo · staccato · tenuto · fermata · trill")
                        commandGroup("Score structure", "time signature three four · key signature E flat major · treble clef · add four bars · tempo allegro")
                        commandGroup("Editing and navigation", "undo · redo · delete selection · next note · previous staff · extend selection right · play")
                    }
                }
            }

            Text("Voice commands execute only through the Dorico bridge. The router still checks that Dorico is running and applies the same targeting rules as controller actions.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(minWidth: 620, minHeight: 520)
        .onDisappear { voice.stopListening() }
    }

    private func commandGroup(_ title: String, _ examples: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).fontWeight(.semibold)
            Text(examples).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

@MainActor
final class DoricoVoiceControlWindowController: NSObject, NSWindowDelegate {
    static let shared = DoricoVoiceControlWindowController()
    private weak var window: NSWindow?

    func show(model: AppModel) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(rootView: DoricoVoiceControlView(model: model))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Dorico Voice Control"
        window.setContentSize(NSSize(width: 700, height: 620))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.center()
        window.delegate = self
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
#endif
