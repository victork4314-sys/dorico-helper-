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

    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var transcriptCommitTask: Task<Void, Never>?
    private var sessionID = UUID()
    private var isRestartingSession = false
    private var isExecuting = false
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
        isListening = true
        beginRecognitionSession()
    }

    func stopListening() {
        guard isListening else { return }
        isListening = false
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
        if !isListening { requestPermissionAndStart() }
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

    private func beginRecognitionSession() {
        guard isListening else { return }
        guard recognizer?.isAvailable == true else {
            isListening = false
            status = "Speech recognition is unavailable"
            return
        }

        cleanRecognitionSession()
        sessionID = UUID()
        let activeSessionID = sessionID

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer?.supportsOnDeviceRecognition == true
        request.taskHint = .dictation
        request.contextualStrings = Array(Set(
            DoricoVoiceLanguage.speechHints +
            aliasBook.aliases.keys +
            aliasBook.aliases.values +
            calibrationProfile.replacements.keys +
            calibrationProfile.replacements.values +
            workingCalibration.replacements.keys +
            workingCalibration.replacements.values
        )).sorted()
        if #available(macOS 13.0, *) { request.addsPunctuation = true }
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            isListening = false
            status = "Microphone could not start: \(error.localizedDescription)"
            return
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
            self.beginRecognitionSession()
        }
    }

    private func cleanRecognitionSession() {
        transcriptCommitTask?.cancel()
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
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
        UserDefaults.standard.set(data, forKey: calibrationDefaultsKey)
    }
}
#endif
