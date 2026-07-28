#if os(macOS)
import AppKit
import SwiftUI
import DoricoBridgeCore

struct ControllerMappingTarget: Identifiable {
    let inputs: Set<XboxInput>
    var id: String { XboxInput.allCases.filter(inputs.contains).map(\.rawValue).joined(separator: "+") }
}

struct MappingActionPickerView: View {
    @ObservedObject var model: AppModel
    let inputs: Set<XboxInput>
    @Environment(\.dismiss) private var dismiss

    @State private var pointerContext: Bool
    @State private var gesture: BindingGesture
    @State private var search = ""
    @State private var capturedShortcut: KeyChord?
    @State private var customText = ""
    @State private var jumpBarCommand = ""
    @State private var midiChannel = 1
    @State private var midiNote = 60
    @State private var sequenceName = ""
    @State private var sequenceSteps: [ActionSequenceDraftStep] = []

    init(model: AppModel, inputs: Set<XboxInput>) {
        self.model = model
        self.inputs = inputs
        _pointerContext = State(initialValue: model.selectedLayer == .pointer)
        _gesture = State(initialValue: model.selectedGesture)
    }

    private let simpleActionIDs = [
        "place.note", "delete", "activate", "cancel", "note.input", "play",
        "undo", "redo", "copy", "cut", "paste", "select.all",
        "pitch.up", "pitch.down", "navigate.left", "navigate.right",
        "navigate.up", "navigate.down", "duration.16", "duration.8",
        "duration.4", "duration.2", "duration.1", "duration.dot", "tie",
        "xbox.popover.ornaments", "pointer.toggle", "pointer.click",
        "pointer.double", "pointer.right"
    ]

    private var simpleActions: [ActionDescriptor] {
        simpleActionIDs.compactMap { DefaultCatalog.actionByID[$0] }
    }

    private var searchableActions: [ActionDescriptor] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return Array((DefaultCatalog.actions + model.menuCommands).filter { action in
            action.title.localizedCaseInsensitiveContains(query) ||
            action.category.localizedCaseInsensitiveContains(query) ||
            action.detail.localizedCaseInsensitiveContains(query)
        }.prefix(160))
    }

    private var combinationName: String {
        XboxInput.allCases.filter(inputs.contains).map(\.displayName).joined(separator: " + ")
    }

    private var currentAction: CommandAction? {
        model.mappedAction(for: inputs, pointerMode: pointerContext, gesture: gesture)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    targetSettings
                    ActionSequenceBuilderView(
                        name: $sequenceName,
                        steps: $sequenceSteps,
                        assignSequence: assignBuiltSequence
                    )
                    simpleSection
                    searchSection
                    customKeyboardSection
                    customTextAndCommandSection
                    customMIDISection
                    deleteSection
                }
                .padding(20)
            }
        }
        .frame(minWidth: 880, minHeight: 760)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Map \(combinationName)").font(.title2.weight(.semibold))
                Text("Every selected control must be held. Changes apply only to “\(model.activeProfileName)”.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Done") { dismiss() }
        }
        .padding(20)
    }

    private var targetSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Exact combination and context", icon: "gamecontroller")
            Text(combinationName).font(.headline).textSelection(.enabled)
            HStack(spacing: 18) {
                Toggle("Only in pointer mode", isOn: $pointerContext)
                Picker("Gesture", selection: $gesture) {
                    ForEach(BindingGesture.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .frame(maxWidth: 260)
            }
            Text("Extra held controls create a different combination. No smaller mapping fires underneath this exact set.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(currentAction.map { "Current action: \($0.summary)" } ?? "This exact combination is currently unmapped.")
                .font(.callout)
                .foregroundStyle(currentAction == nil ? Color.secondary : Color.accentColor)
        }
    }

    private var simpleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Simple actions", icon: "sparkles")
            Text("Place Note, Delete, movement, playback, durations, editing, pointer actions, and other common controls are ready without command hunting.")
                .font(.callout).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 8)], spacing: 8) {
                ForEach(simpleActions) { action in choiceRow(action) }
            }
        }
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("Find any Dorico command or action", icon: "magnifyingglass")
                Spacer()
                Button("Scan Dorico menus") { model.scanDoricoMenus() }
            }
            TextField("Search commands, popovers, pointer actions, named MIDI pitches…", text: $search)
                .textFieldStyle(.roundedBorder)
            if search.isEmpty {
                Text("Type a name, or scan the running Dorico menu bar to include its live commands.")
                    .font(.callout).foregroundStyle(.secondary)
            } else if searchableActions.isEmpty {
                ContentUnavailableView("No matching action", systemImage: "magnifyingglass", description: Text("Try another search or scan Dorico menus."))
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            } else {
                LazyVStack(spacing: 7) {
                    ForEach(searchableActions) { action in choiceRow(action) }
                }
            }
        }
    }

    private var customKeyboardSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Exact keyboard shortcut", icon: "keyboard")
            GroupBox("Capture every symbol and modifier") {
                VStack(alignment: .leading, spacing: 10) {
                    KeyboardShortcutRecorder(shortcut: $capturedShortcut)
                    HStack {
                        Button("Assign shortcut") {
                            guard let capturedShortcut else { return }
                            assign(model.customCapturedKeyDescriptor(capturedShortcut))
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(capturedShortcut == nil)

                        Button("Add shortcut to sequence") {
                            guard let capturedShortcut else { return }
                            addToSequence(model.customCapturedKeyDescriptor(capturedShortcut))
                        }
                        .disabled(capturedShortcut == nil)
                    }
                }
                .padding(8)
            }
        }
    }

    private var customTextAndCommandSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Custom text and Jump Bar", icon: "text.cursor")

            GroupBox("Type your own text") {
                VStack(alignment: .leading, spacing: 9) {
                    TextField("Text to type into Dorico", text: $customText).textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Assign typed text") {
                            if let descriptor = model.customTextDescriptor(customText) { assign(descriptor) }
                        }
                        .disabled(customText.isEmpty)
                        Button("Add text to sequence") {
                            if let descriptor = model.customTextDescriptor(customText) { addToSequence(descriptor) }
                        }
                        .disabled(customText.isEmpty)
                    }
                }.padding(8)
            }

            GroupBox("Run a Dorico Jump Bar command") {
                VStack(alignment: .leading, spacing: 9) {
                    TextField("Jump Bar command", text: $jumpBarCommand).textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Assign Jump Bar command") {
                            if let descriptor = model.customJumpBarDescriptor(jumpBarCommand) { assign(descriptor) }
                        }
                        .disabled(jumpBarCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("Add Jump Bar command to sequence") {
                            if let descriptor = model.customJumpBarDescriptor(jumpBarCommand) { addToSequence(descriptor) }
                        }
                        .disabled(jumpBarCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }.padding(8)
            }
        }
    }

    private var customMIDISection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Custom MIDI pitch", icon: "pianokeys")
            GroupBox("Named musical pitch") {
                HStack(spacing: 18) {
                    Picker("Pitch", selection: $midiNote) {
                        ForEach(0...127, id: \.self) { value in
                            Text(MIDIAddress.noteName(for: UInt8(value))).tag(value)
                        }
                    }
                    .frame(width: 180)
                    Stepper("Channel \(midiChannel)", value: $midiChannel, in: 1...16)
                    Text("Selected: \(MIDIAddress.noteName(for: UInt8(midiNote)))")
                        .font(.callout.monospaced()).foregroundStyle(.secondary)
                    Spacer()
                    Button("Assign MIDI pitch") { assign(midiDescriptor) }
                    Button("Add MIDI pitch to sequence") { addToSequence(midiDescriptor) }
                }
                .padding(8)
            }
        }
    }

    private var deleteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Remove mapping", icon: "trash")
            Button("Remove only this exact combination", role: .destructive) {
                model.removeDirectMapping(for: inputs, pointerMode: pointerContext, gesture: gesture)
                dismiss()
            }
            .disabled(currentAction == nil)
        }
    }

    private var midiDescriptor: ActionDescriptor {
        model.customMIDIDescriptor(channel: midiChannel, note: midiNote)
    }

    private func choiceRow(_ action: ActionDescriptor) -> some View {
        ActionChoiceRow(
            action: action,
            assign: { assign(action) },
            addToSequence: { addToSequence(action) }
        )
    }

    private func sectionTitle(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon).font(.headline)
    }

    private func addToSequence(_ descriptor: ActionDescriptor) {
        sequenceSteps.append(ActionSequenceDraftStep(descriptor: descriptor))
    }

    private func assignBuiltSequence() {
        let commandSteps = sequenceSteps.map(\.commandStep)
        guard let descriptor = model.customSequenceDescriptor(name: sequenceName, steps: commandSteps) else { return }
        assign(descriptor)
    }

    private func assign(_ descriptor: ActionDescriptor) {
        model.assignAction(descriptor, to: inputs, pointerMode: pointerContext, gesture: gesture)
        dismiss()
    }
}

private struct ActionChoiceRow: View {
    let action: ActionDescriptor
    let assign: () -> Void
    let addToSequence: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(action.title).fontWeight(.semibold)
                Text("\(action.category) — \(action.detail)")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            Button("Assign", action: assign).buttonStyle(.borderedProminent)
            Button("Add to sequence", action: addToSequence)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay { RoundedRectangle(cornerRadius: 9).stroke(Color(nsColor: .separatorColor)) }
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}
#endif
