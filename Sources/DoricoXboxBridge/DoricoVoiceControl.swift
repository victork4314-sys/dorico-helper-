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
    @Published var trainingTargetPhrase = ""
    @Published private(set) var trainingSamples: [String] = []
    @Published private(set) var isTraining = false
    @Published private(set) var aliasBook: DoricoVoiceAliasBook

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

    private let detector = DoricoDetector()
    private let accessibility = DoricoAccessibility()
    private let midi = VirtualMIDI()
    private let router: ActionRouter
    private weak var model: AppModel?

    private static let aliasesDefaultsKey = "DoricoVoiceAliases.v1"

    init(model: AppModel) {
        self.model = model
        self.aliasBook = Self.loadAliasBook()
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
        status = isTraining ? "Voice training paused" : "Voice control is off"
    }

    func beginTraining() {
        let target = DoricoVoiceLanguage.normalize(trainingTargetPhrase)
        guard !target.isEmpty else {
            status = "Enter the Dorico command you want to teach first"
            return
        }
        guard DoricoVoiceLanguage.canTeach(canonicalPhrase: target) else {
            status = "That target is not a recognized Dorico music command yet"
            return
        }

        trainingTargetPhrase = target
        trainingSamples.removeAll()
        isTraining = true
        status = "Training 1 of 3: say “\(target)” naturally"
        if !isListening { requestPermissionAndStart() }
    }

    func cancelTraining() {
        isTraining = false
        trainingSamples.removeAll()
        status = isListening ? "Ready for Dorico music commands" : "Voice control is off"
    }

    func removeLearnedPhrase(_ sample: String) {
        aliasBook.removeAlias(sample)
        saveAliasBook()
    }

    func clearLearnedPhrases() {
        aliasBook.removeAll()
        saveAliasBook()
        status = "All learned pronunciations were removed"
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
            aliasBook.aliases.values
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

        status = isTraining
            ? "Training \(trainingSamples.count + 1) of 3: say “\(trainingTargetPhrase)” naturally"
            : "Listening for Dorico music commands"

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

        if isTraining {
            captureTrainingSample(rawText)
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
        let now = Date()
        guard commandText != lastExecutedNormalizedText || now.timeIntervalSince(lastExecutionTime) > 1.4 else { return }

        let batch = DoricoVoiceLanguage.parseBatch(commandText, aliases: aliasBook)
        guard !batch.commands.isEmpty else {
            status = "No Dorico music command recognized"
            model?.log("Voice not recognized: \(commandText)")
            restartRecognitionSession()
            return
        }

        lastExecutedNormalizedText = commandText
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
                self.status = "Ready for the next Dorico music command"
            } else {
                self.status = "Ran \(batch.commands.count); could not understand: \(batch.unrecognizedSegments.joined(separator: ", "))"
            }
            self.restartRecognitionSession()
        }
    }

    private func captureTrainingSample(_ rawText: String) {
        let sample = DoricoVoiceLanguage.normalize(rawText)
        guard !sample.isEmpty else { return }
        trainingSamples.append(sample)

        if trainingSamples.count >= 3 {
            aliasBook.teach(samples: trainingSamples, canonicalPhrase: trainingTargetPhrase)
            saveAliasBook()
            isTraining = false
            let target = trainingTargetPhrase
            trainingSamples.removeAll()
            status = "Learned your pronunciation for “\(target)”"
            restartRecognitionSession()
            return
        }

        status = "Training \(trainingSamples.count + 1) of 3: say “\(trainingTargetPhrase)” again"
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
}
#endif
