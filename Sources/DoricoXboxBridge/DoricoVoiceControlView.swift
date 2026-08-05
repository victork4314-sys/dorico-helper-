#if os(macOS)
import AppKit
import SwiftUI

struct DoricoVoiceControlView: View {
    @StateObject private var voice: DoricoVoiceControl

    init(model: AppModel) {
        _voice = StateObject(wrappedValue: DoricoVoiceControl(model: model))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dorico Voice Control").font(.title2.weight(.semibold))
                        Text("Speak normal music language or the name of any Dorico Helper action")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(voice.isListening ? "Stop Listening" : "Start Listening") {
                        voice.toggleListening()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.space, modifiers: [.command, .shift])
                    .disabled(voice.isRequestingPermissions)
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

                GroupBox("Permissions") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Speech Recognition: \(voice.speechPermissionStatus)", systemImage: "captions.bubble")
                            Spacer()
                            Label("Microphone: \(voice.microphonePermissionStatus)", systemImage: "mic")
                        }
                        .font(.callout)

                        Text("macOS adds Dorico Xbox Bridge to Privacy & Security only after the permission request reaches the system. Press Set Up My Voice or Start Listening to request both permissions.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            Button("Open Microphone Settings") {
                                openPrivacyPane("Privacy_Microphone")
                            }
                            Button("Open Speech Recognition Settings") {
                                openPrivacyPane("Privacy_SpeechRecognition")
                            }
                        }
                    }
                    .padding(4)
                }

                GroupBox("Live transcript") {
                    Text(voice.transcript.isEmpty ? "Your speech will appear here." : voice.transcript)
                        .frame(maxWidth: .infinity, minHeight: 66, alignment: .topLeading)
                        .textSelection(.enabled)
                        .padding(8)
                }

                Toggle("Require commands to begin with “Dorico”", isOn: $voice.requireDoricoPrefix)
                Toggle("Show command examples", isOn: $voice.showCommandReference)

                GroupBox("Set up your voice once") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Say five different phrases once each. The helper compares what macOS heard with the displayed music language, learns reusable pronunciation corrections, and applies them across every command. This is not command-by-command training.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if voice.isCalibrating {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Phrase \(voice.calibrationPromptIndex + 1) of \(voice.calibrationPromptTotal)")
                                    .font(.headline)
                                Text("“\(voice.currentCalibrationPrompt)”")
                                    .font(.title3)
                                    .textSelection(.enabled)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(nsColor: .controlBackgroundColor))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                Text(voice.isRequestingPermissions
                                     ? "Waiting for macOS permission prompts."
                                     : "Say the whole phrase naturally once. A short pause submits it.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                ProgressView(
                                    value: Double(voice.calibrationPromptIndex),
                                    total: Double(voice.calibrationPromptTotal)
                                )
                                Button("Cancel Voice Setup") { voice.cancelVoiceSetup() }
                            }
                        } else {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(voice.voiceSetupComplete ? "Voice setup complete" : "Voice setup has not been completed")
                                        .fontWeight(.semibold)
                                    if voice.voiceSetupComplete {
                                        Text("\(voice.learnedCorrectionCount) reusable corrections learned")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Button(voice.voiceSetupComplete ? "Run Setup Again" : "Set Up My Voice") {
                                    voice.beginVoiceSetup()
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(voice.isRequestingPermissions)
                                if voice.voiceSetupComplete {
                                    Button("Reset", role: .destructive) { voice.resetVoiceSetup() }
                                }
                            }
                        }

                        Text("The current helper catalog contains \(voice.supportedActionCount) voice-addressable actions. New named catalog actions automatically join voice control without a separate parser edit.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if !voice.aliasBook.aliases.isEmpty {
                            DisclosureGroup("Legacy command-specific overrides (\(voice.aliasBook.aliases.count))") {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("These older phrase overrides still work, but the five-phrase voice setup replaces the need to train commands individually.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    ForEach(voice.aliasBook.aliases.keys.sorted(), id: \.self) { sample in
                                        HStack {
                                            Text("“\(sample)” → “\(voice.aliasBook.aliases[sample] ?? "")”")
                                                .font(.caption)
                                            Spacer()
                                            Button("Remove") { voice.removeLearnedPhrase(sample) }
                                                .buttonStyle(.borderless)
                                        }
                                    }
                                    Button("Remove all legacy overrides", role: .destructive) {
                                        voice.clearLearnedPhrases()
                                    }
                                }
                                .padding(.top, 6)
                            }
                        }
                    }
                    .padding(4)
                }

                if voice.showCommandReference {
                    VStack(alignment: .leading, spacing: 10) {
                        commandGroup("Everything in the helper", "Say any action name shown in Mappings, such as pointer double-click, next accessible zone, increase accessible value, open command area, or MIDI Learn C sharp four channel one.")
                        commandGroup("Several commands at once", "quarter note, C sharp four, staccato · quaver then E flat three then tenuto")
                        commandGroup("Notes and rhythm", "eighth note or quaver · sixteenth note or semiquaver · dotted note · rest · chord mode · add tie")
                        commandGroup("Bars and movement", "add twenty-five bars · delete four bars · go left by a bar · move right three bars · go to bar thirty-two")
                        commandGroup("Dynamics and expression", "crescendo · diminuendo · dynamic fortissimo · staccato · tenuto · fermata · trill")
                        commandGroup("Score structure", "time signature three four · key signature E flat major · treble clef · tempo allegro")
                        commandGroup("Any remaining Dorico command", "Say “Dorico command” followed by the command name to run it through Dorico’s Jump Bar command search.")
                    }
                }

                Text("Voice first tries musician language, then every named Dorico Helper action, then the explicit Dorico Jump Bar fallback. All execution still uses the same checked ActionRouter as controller and keyboard mappings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .frame(minWidth: 720, minHeight: 700)
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

    private func openPrivacyPane(_ pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else { return }
        NSWorkspace.shared.open(url)
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
        window.setContentSize(NSSize(width: 820, height: 800))
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
