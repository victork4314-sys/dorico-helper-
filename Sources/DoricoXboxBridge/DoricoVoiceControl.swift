#if os(macOS)
import AppKit
import AVFoundation
import Combine
import Speech
import DoricoBridgeCore

@MainActor
final class DoricoVoiceControl: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var transcript = ""
    @Published var lastRecognizedCommand = "None"
    @Published var status = "Voice control is off"
    @Published var requireDoricoPrefix = false
    @Published var showCommandReference = true
    @Published private(set) var aliasBook: DoricoVoiceAliasBook
    @Published private(set) var calibrationProfile: DoricoVoiceCalibrationProfile
    @Published private(set) var isCalibrating = false
    @Published private(set) var calibrationPromptIndex = 0
    @Published private(set) var calibrationSamples: [String] = []
    @Published private(set) var isRequestingPermissions = false
    @Published private(set) var speechPermissionStatus = "Not requested"
    @Published private(set) var microphonePermissionStatus = "Not requested"

    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var transcriptCommitTask: Task<Void, Never>?
    private var sessionID = UUID()
    private var isRestartingSession = false
    private var isExecuting = false
    private var inputTapInstalled = false
    private var lastExecutedNormalizedText = ""
    private var lastExecutionTime = Date.distantPast
    private var workingCalibration = DoricoVoiceCalibrationProfile()

    private let detector = DoricoDetector()
    private let accessibility = DoricoAccessibility()
    private let midi = VirtualMIDI()
    private let router: ActionRouter
    private weak var model: AppModel?

    private static let aliasesDefaultsKey = "DoricoVoiceAliases.v1"
    private static let calibrationDefaultsKey = "DoricoVoiceCalibration.v1"

    var calibrationPromptTotal: Int { DoricoVoiceLanguage.calibrationPrompts.count }
    var currentCalibrationPrompt: String {
        guard calibrationPromptIndex < calibrationPromptTotal else { return "" }
        return DoricoVoiceLanguage.calibrationPrompts[calibrationPromptIndex]
    }
    var voiceSetupComplete: Bool { calibrationProfile.isComplete }
    var learnedCorrectionCount: Int { calibrationProfile.learnedCorrectionCount }
    var supportedActionCount: Int { DoricoVoiceLanguage.supportedCatalogActionCount }

    init(model: AppModel) {
        self.model = model
        self.aliasBook = Self.loadAliasBook()
        self.calibrationProfile = Self.loadCalibrationProfile()
        self.router = ActionRouter(
            detector: detector,
            accessibility: accessibility,
            midi: midi,
            model: model
        )
        super.init()
        midi.start()
    }

    func toggleListening() {
        guard !isRequestingPermissions else { return }
        isListening ? stopListening() : requestPermissionAndStart()
    }

    func requestPermissionAndStart() {
        guard !isListening, !isRequestingPermissions else { return }
        isRequestingPermissions = true
        speechPermissionStatus = "Requesting"
        status = "Requesting Speech Recognition permission"

        SFSpeechRecognizer.requestAuthorization { [weak self] speechStatus in
            Task { @MainActor in
                guard let self else { return }
                guard speechStatus == .authorized else {
                    self.isRequestingPermissions = false
                    self.speechPermissionStatus = Self.speechPermissionLabel(speechStatus)
                    self.failVoiceStartup("Speech Recognition permission is required")
                    return
                }

                self.speechPermissionStatus = "Granted"
                self.microphonePermissionStatus = "Requesting"
                self.status = "Requesting Microphone permission"

                AVAudioApplication.requestRecordPermission { [weak self] microphoneGranted in
                    Task { @MainActor in
                        guard let self else { return }
                        self.isRequestingPermissions = false
                        self.microphonePermissionStatus = microphoneGranted ? "Granted" : "Denied"
                        guard microphoneGranted else {
                            self.failVoiceStartup("Microphone permission is required")
                            return
                        }
                        self.startListening()
                    }
                }
            }
        }
    }

    func startListening() {
        guard !isListening else { return }
        guard recognizer?.isAvailable == true else {
            failVoiceStartup("Speech recognition is unavailable")
            return
        }
        isListening = true
        if !beginRecognitionSession() {
            isListening = false
        }
    }

    func stopListening() {
        guard isListening || isRequestingPermissions else { return }
        isListening = false
        isRequestingPermissions = false
        isRestartingSession = false
        transcriptCommitTask?.cancel()
        cleanRecognitionSession()
        if isCalibrating {
            status = "Voice setup paused at phrase \(min(calibrationPromptIndex + 1, calibrationPromptTotal)) of \(calibrationPromptTotal)"
        } else {
            status = "Voice control is off"
        }
    }

    func beginVoiceSetup() {
        workingCalibration = DoricoVoiceCalibrationProfile()
        calibrationPromptIndex = 0
        calibrationSamples.removeAll()
        isCalibrating = true
        status = "Voice setup 1 of \(calibrationPromptTotal): say the displayed phrase once"
        if isListening {
            restartRecognitionSession()
        } else {
            requestPermissionAndStart()
        }
    }

    func cancelVoiceSetup() {
        isCalibrating = false
        calibrationPromptIndex = 0
        calibrationSamples.removeAll()
        workingCalibration = DoricoVoiceCalibrationProfile()
        status = isListening ? "Ready for Dorico music commands" : "Voice control is off"
    }

    func resetVoiceSetup() {
        calibrationProfile.reset()
        workingCalibration.reset()
        calibrationPromptIndex = 0
        calibrationSamples.removeAll()
        Self.saveCalibrationProfile(calibrationProfile)
        status = "Voice setup was removed"
        restartRecognitionSession()
    }

    func removeLearnedPhrase(_ sample: String) {
        aliasBook.removeAlias(sample)
        saveAliasBook()
    }

    func clearLearnedPhrases() {
        aliasBook.removeAll()
        saveAliasBook()
        status = "All legacy command-specific pronunciations were removed"
    }

    @discardableResult
    private func beginRecognitionSession() -> Bool {
        guard isListening else { return false }
        guard recognizer?.isAvailable == true else {
            failVoiceStartup("Speech recognition is unavailable")
            return false
        }

        cleanRecognitionSession()
        sessionID = UUID()
        let activeSessionID = sessionID

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer?.supportsOnDeviceRecognition == true
        request.taskHint = .dictation
        request.contextualStrings = DoricoVoiceRuntimePolicy.contextualStrings(
            priority: priorityContextualStrings,
            fallback: DoricoVoiceLanguage.speechHints
        )
        if #available(macOS 13.0, *) { request.addsPunctuation = true }
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard DoricoVoiceRuntimePolicy.isUsableAudioInput(
            sampleRate: format.sampleRate,
            channelCount: format.channelCount
        ) else {
            recognitionRequest = nil
            failVoiceStartup("No usable microphone input is available. Select a microphone in System Settings → Sound → Input, then try again.")
            return false
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        inputTapInstalled = true

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            failVoiceStartup("Microphone could not start: \(error.localizedDescription)")
            return false
        }

        if isCalibrating {
            status = "Voice setup \(calibrationPromptIndex + 1) of \(calibrationPromptTotal): say the displayed phrase once"
        } else {
            status = "Listening for every Dorico helper command"
        }

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self, self.sessionID == activeSessionID else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    self.transcript = text
                    self.scheduleUtterance(text, isFinal: result.isFinal)
                }
                if error != nil, self.isListening, !self.isRestartingSession {
                    self.restartRecognitionSession()
                }
            }
        }
        return true
    }

    private var priorityContextualStrings: [String] {
        var priority: [String] = [
            "Dorico", "quarter note", "eighth note", "sixteenth note", "quaver", "semiquaver",
            "C sharp", "E flat", "staccato", "tenuto", "fermata", "crescendo", "diminuendo",
            "fortissimo", "time signature", "key signature", "treble clef", "bass clef",
            "add bars", "delete bars", "start playback", "stop playback", "MIDI Learn"
        ]

        if isCalibrating, !currentCalibrationPrompt.isEmpty {
            priority.insert(currentCalibrationPrompt, at: 0)
            let words = DoricoVoiceLanguage.normalize(currentCalibrationPrompt)
                .split(separator: " ")
                .map(String.init)
            priority.append(contentsOf: words)
            if words.count > 1 {
                for index in 0..<(words.count - 1) {
                    priority.append(words[index] + " " + words[index + 1])
                }
            }
        }

        priority.append(contentsOf: calibrationProfile.replacements.keys)
        priority.append(contentsOf: calibrationProfile.replacements.values)
        priority.append(contentsOf: workingCalibration.replacements.keys)
        priority.append(contentsOf: workingCalibration.replacements.values)
        priority.append(contentsOf: aliasBook.aliases.keys)
        priority.append(contentsOf: aliasBook.aliases.values)
        return priority
    }

    private func scheduleUtterance(_ text: String, isFinal: Bool) {
        transcriptCommitTask?.cancel()
        if isFinal {
            consumeUtterance(text)
            return
        }

        transcriptCommitTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(720))
            guard !Task.isCancelled else { return }
            self?.consumeUtterance(text)
        }
    }

    private func consumeUtterance(_ rawText: String) {
        guard isListening, !isExecuting else { return }
        transcriptCommitTask?.cancel()

        let normalized = DoricoVoiceLanguage.normalize(rawText)
        guard !normalized.isEmpty else { return }

        if isCalibrating {
            captureCalibrationSample(rawText)
            return
        }

        guard !requireDoricoPrefix || normalized.hasPrefix("dorico ") else {
            status = "Waiting for a command beginning with “Dorico”"
            restartRecognitionSession()
            return
        }

        let commandText = normalized.hasPrefix("dorico ")
            ? String(normalized.dropFirst("dorico ".count))
            : normalized
        let calibratedText = calibrationProfile.apply(to: commandText)
        let now = Date()
        guard calibratedText != lastExecutedNormalizedText || now.timeIntervalSince(lastExecutionTime) > 1.4 else { return }

        let batch = DoricoVoiceLanguage.parseBatch(
            commandText,
            aliases: aliasBook,
            calibration: calibrationProfile
        )
        guard !batch.commands.isEmpty else {
            status = "No Dorico music or helper command recognized"
            model?.log("Voice not recognized: \(calibratedText)")
            restartRecognitionSession()
            return
        }

        lastExecutedNormalizedText = calibratedText
        lastExecutionTime = now
        lastRecognizedCommand = batch.label
        status = "Running \(batch.commands.count) \(batch.commands.count == 1 ? "command" : "commands"): \(batch.label)"
        model?.lastAction = "Voice: \(batch.label)"
        model?.log("Voice command batch: \(batch.label)")
        isExecuting = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            for (index, command) in batch.commands.enumerated() {
                await self.router.execute(command.action)
                if index < batch.commands.count - 1 {
                    try? await Task.sleep(for: .milliseconds(90))
                }
            }
            self.isExecuting = false
            if batch.unrecognizedSegments.isEmpty {
                self.status = "Ready for the next Dorico command"
            } else {
                self.status = "Ran \(batch.commands.count); could not understand: \(batch.unrecognizedSegments.joined(separator: ", "))"
            }
            self.restartRecognitionSession()
        }
    }

    private func captureCalibrationSample(_ rawText: String) {
        guard calibrationPromptIndex < calibrationPromptTotal else { return }
        let heard = DoricoVoiceLanguage.normalize(rawText)
        guard !heard.isEmpty else { return }

        let expected = DoricoVoiceLanguage.calibrationPrompts[calibrationPromptIndex]
        workingCalibration.learn(expected: expected, heard: heard)
        calibrationSamples.append(heard)
        calibrationPromptIndex += 1

        if calibrationPromptIndex >= calibrationPromptTotal {
            calibrationProfile = workingCalibration
            Self.saveCalibrationProfile(calibrationProfile)
            isCalibrating = false
            status = "Voice setup complete. \(learnedCorrectionCount) reusable pronunciation corrections learned."
            restartRecognitionSession()
            return
        }

        status = "Voice setup \(calibrationPromptIndex + 1) of \(calibrationPromptTotal): say the next phrase once"
        restartRecognitionSession()
    }

    private func restartRecognitionSession() {
        guard isListening else { return }
        isRestartingSession = true
        sessionID = UUID()
        cleanRecognitionSession()
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(160))
            guard let self, self.isListening else { return }
            self.isRestartingSession = false
            self.transcript = ""
            _ = self.beginRecognitionSession()
        }
    }

    private func cleanRecognitionSession() {
        transcriptCommitTask?.cancel()
        if audioEngine.isRunning { audioEngine.stop() }
        if inputTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            inputTapInstalled = false
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }

    private func failVoiceStartup(_ message: String) {
        isListening = false
        isRestartingSession = false
        cleanRecognitionSession()
        if isCalibrating {
            isCalibrating = false
            workingCalibration = DoricoVoiceCalibrationProfile()
            calibrationPromptIndex = 0
            calibrationSamples.removeAll()
            status = "Voice setup could not start: \(message)"
        } else {
            status = message
        }
        model?.log("Voice startup stopped safely: \(message)")
    }

    private static func speechPermissionLabel(_ authorization: SFSpeechRecognizerAuthorizationStatus) -> String {
        switch authorization {
        case .authorized: "Granted"
        case .denied: "Denied"
        case .restricted: "Restricted"
        case .notDetermined: "Not requested"
        @unknown default: "Unavailable"
        }
    }

    private static func loadAliasBook() -> DoricoVoiceAliasBook {
        guard let data = UserDefaults.standard.data(forKey: aliasesDefaultsKey),
              let book = try? JSONDecoder().decode(DoricoVoiceAliasBook.self, from: data) else {
            return DoricoVoiceAliasBook()
        }
        return book
    }

    private func saveAliasBook() {
        guard let data = try? JSONEncoder().encode(aliasBook) else { return }
        UserDefaults.standard.set(data, forKey: Self.aliasesDefaultsKey)
        objectWillChange.send()
    }

    private static func loadCalibrationProfile() -> DoricoVoiceCalibrationProfile {
        guard let data = UserDefaults.standard.data(forKey: calibrationDefaultsKey),
              let profile = try? JSONDecoder().decode(DoricoVoiceCalibrationProfile.self, from: data) else {
            return DoricoVoiceCalibrationProfile()
        }
        return profile
    }

    private static func saveCalibrationProfile(_ profile: DoricoVoiceCalibrationProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: Self.calibrationDefaultsKey)
    }
}
#endif
