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
                        Text("Write and edit music by speaking normal Dorico and music terms")
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

                GroupBox("Teach your pronunciation") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Choose a Dorico command, then say it three times. The bridge remembers how your microphone and voice transcribe it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            TextField("Command, for example: eighth note", text: $voice.trainingTargetPhrase)
                                .textFieldStyle(.roundedBorder)
                            Button(voice.isTraining ? "Cancel" : "Train 3 Times") {
                                voice.isTraining ? voice.cancelTraining() : voice.beginTraining()
                            }
                        }

                        if voice.isTraining {
                            ProgressView(value: Double(voice.trainingSamples.count), total: 3)
                            Text("Captured \(voice.trainingSamples.count) of 3 samples")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if !voice.aliasBook.aliases.isEmpty {
                            DisclosureGroup("Learned pronunciations (\(voice.aliasBook.aliases.count))") {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(voice.aliasBook.aliases.keys.sorted(), id: \.self) { sample in
                                        HStack {
                                            Text("“\(sample)” → “\(voice.aliasBook.aliases[sample] ?? "")”")
                                                .font(.caption)
                                            Spacer()
                                            Button("Remove") { voice.removeLearnedPhrase(sample) }
                                                .buttonStyle(.borderless)
                                        }
                                    }
                                    Button("Remove all learned pronunciations", role: .destructive) {
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
                        commandGroup("Several commands at once", "quarter note, C sharp four, staccato · quaver then E flat three then tenuto")
                        commandGroup("Notes and rhythm", "eighth note or quaver · sixteenth note or semiquaver · dotted note · rest · chord mode · add tie")
                        commandGroup("Bars and movement", "add twenty-five bars · delete four bars · go left by a bar · move right three bars · go to bar thirty-two")
                        commandGroup("Dynamics and expression", "crescendo · diminuendo · dynamic fortissimo · staccato · tenuto · fermata · trill")
                        commandGroup("Score structure", "time signature three four · key signature E flat major · treble clef · tempo allegro")
                        commandGroup("Editing", "undo · redo · delete selection · next note · previous staff · extend selection right · play")
                    }
                }

                Text("The voice layer is Dorico-specific. It converts music language into Dorico’s own note-entry keys, popovers, navigation commands, and action sequences.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .frame(minWidth: 700, minHeight: 660)
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
        window.setContentSize(NSSize(width: 780, height: 760))
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
