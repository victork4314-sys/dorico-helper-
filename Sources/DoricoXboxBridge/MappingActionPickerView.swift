#if os(macOS)
import AppKit
import SwiftUI
import DoricoBridgeCore

struct ControllerMappingTarget: Identifiable {
    let input: XboxInput
    var id: String { input.rawValue }
}

struct MappingActionPickerView: View {
    @ObservedObject var model: AppModel
    let input: XboxInput
    @Environment(\.dismiss) private var dismiss

    @State private var layer: MappingLayer
    @State private var gesture: BindingGesture
    @State private var search = ""
    @State private var customKey = ""
    @State private var commandModifier = false
    @State private var shiftModifier = false
    @State private var optionModifier = false
    @State private var controlModifier = false
    @State private var functionModifier = false
    @State private var customText = ""
    @State private var jumpBarCommand = ""
    @State private var midiChannel = 1
    @State private var midiNote = 60
    @State private var macroName = ""
    @State private var macroSteps = ""

    init(model: AppModel, input: XboxInput) {
        self.model = model
        self.input = input
        _layer = State(initialValue: model.selectedLayer)
        _gesture = State(initialValue: model.selectedGesture)
    }

    private let simpleActionIDs = [
        "place.note", "delete", "activate", "cancel", "note.input", "play",
        "undo", "redo", "copy", "cut", "paste", "select.all",
        "pitch.up", "pitch.down", "navigate.left", "navigate.right",
        "navigate.up", "navigate.down", "duration.16", "duration.8",
        "duration.4", "duration.2", "duration.1", "duration.dot", "tie",
        "xbox.popover.ornaments", "pointer.toggle", "pointer.click"
    ]

    private var simpleActions: [ActionDescriptor] {
        simpleActionIDs.compactMap { DefaultCatalog.actionByID[$0] }
    }

    private var searchableActions: [ActionDescriptor] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let all = DefaultCatalog.actions + model.menuCommands
        return Array(all.filter { action in
            action.title.localizedCaseInsensitiveContains(query) ||
            action.category.localizedCaseInsensitiveContains(query) ||
            action.detail.localizedCaseInsensitiveContains(query)
        }.prefix(120))
    }

    private var currentAction: CommandAction? {
        model.mappedAction(for: input, layer: layer, gesture: gesture)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    targetSettings
                    simpleSection
                    searchSection
                    customSection
                    deleteSection
                }
                .padding(20)
            }
        }
        .frame(minWidth: 780, minHeight: 680)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Map \(input.displayName)")
                    .font(.title2.weight(.semibold))
                Text("Changes apply only to “\(model.activeProfileName)”.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Done") { dismiss() }
        }
        .padding(20)
    }

    private var targetSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Button and context", icon: "gamecontroller")
            HStack(spacing: 14) {
                Picker("Context", selection: $layer) {
                    ForEach(MappingLayer.allCases, id: \.self) { value in
                        Text(value.displayName).tag(value)
                    }
                }
                Picker("Gesture", selection: $gesture) {
                    ForEach(BindingGesture.allCases, id: \.self) { value in
                        Text(value.displayName).tag(value)
                    }
                }
            }
            Text(currentAction.map { "Current action: \($0.summary)" } ?? "This slot is currently unmapped.")
                .font(.callout)
                .foregroundStyle(currentAction == nil ? Color.secondary : Color.accentColor)
        }
    }

    private var simpleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Simple actions", icon: "sparkles")
            Text("Common actions are ready to pick—no command hunting required.")
                .font(.callout)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8)], spacing: 8) {
                ForEach(simpleActions) { action in
                    actionButton(action)
                }
            }
        }
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("Find any Dorico command", icon: "magnifyingglass")
                Spacer()
                Button("Scan Dorico menus") { model.scanDoricoMenus() }
            }
            TextField("Search actions, Dorico menu commands, popovers, MIDI slots…", text: $search)
                .textFieldStyle(.roundedBorder)
            if search.isEmpty {
                Text("Type a name, or scan the running Dorico menu bar to include its live commands.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if searchableActions.isEmpty {
                ContentUnavailableView("No matching command", systemImage: "magnifyingglass", description: Text("Try another search or scan Dorico menus."))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                LazyVStack(spacing: 7) {
                    ForEach(searchableActions) { action in actionButton(action) }
                }
            }
        }
    }

    private var customSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Completely custom action", icon: "slider.horizontal.3")

            GroupBox("Custom keyboard shortcut") {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Key, such as n, return, delete, left…", text: $customKey)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Toggle("Cmd", isOn: $commandModifier)
                        Toggle("Shift", isOn: $shiftModifier)
                        Toggle("Option", isOn: $optionModifier)
                        Toggle("Control", isOn: $controlModifier)
                        Toggle("Fn", isOn: $functionModifier)
                    }
                    Button("Assign custom shortcut") {
                        if let descriptor = model.customKeyDescriptor(key: customKey, modifiers: selectedModifiers) {
                            assign(descriptor)
                        }
                    }
                    .disabled(customKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(8)
            }

            GroupBox("Type your own text or command") {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Text to type into Dorico", text: $customText)
                        .textFieldStyle(.roundedBorder)
                    Button("Assign typed text") {
                        if let descriptor = model.customTextDescriptor(customText) { assign(descriptor) }
                    }
                    .disabled(customText.isEmpty)

                    Divider()

                    TextField("Dorico Jump Bar command", text: $jumpBarCommand)
                        .textFieldStyle(.roundedBorder)
                    Button("Assign Jump Bar command") {
                        if let descriptor = model.customJumpBarDescriptor(jumpBarCommand) { assign(descriptor) }
                    }
                    .disabled(jumpBarCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(8)
            }

            GroupBox("Custom macro") {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Macro name (optional)", text: $macroName)
                        .textFieldStyle(.roundedBorder)
                    TextField("Shortcut steps separated by commas, e.g. shift+n, 6, c", text: $macroSteps)
                        .textFieldStyle(.roundedBorder)
                    Text("Use + inside a step for modifiers: cmd+shift+s, ctrl+1, return.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Assign custom macro") {
                        if let descriptor = model.customMacroDescriptor(name: macroName, chords: parsedMacroSteps) {
                            assign(descriptor)
                        }
                    }
                    .disabled(parsedMacroSteps.isEmpty)
                }
                .padding(8)
            }

            GroupBox("Custom MIDI action") {
                HStack(spacing: 18) {
                    Stepper("Channel \(midiChannel)", value: $midiChannel, in: 1...16)
                    Stepper("Note \(midiNote)", value: $midiNote, in: 0...127)
                    Spacer()
                    Button("Assign MIDI pulse") {
                        assign(model.customMIDIDescriptor(channel: midiChannel, note: midiNote))
                    }
                }
                .padding(8)
            }
        }
    }

    private var deleteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Remove mapping", icon: "trash")
            Button("Remove only this slot", role: .destructive) {
                model.removeDirectMapping(for: input, layer: layer, gesture: gesture)
                dismiss()
            }
            .disabled(currentAction == nil)
        }
    }

    private var selectedModifiers: Set<KeyModifier> {
        var output = Set<KeyModifier>()
        if commandModifier { output.insert(.command) }
        if shiftModifier { output.insert(.shift) }
        if optionModifier { output.insert(.option) }
        if controlModifier { output.insert(.control) }
        if functionModifier { output.insert(.function) }
        return output
    }

    private var parsedMacroSteps: [KeyChord] {
        macroSteps
            .split(separator: ",")
            .compactMap { parseChord(String($0)) }
    }

    private func parseChord(_ source: String) -> KeyChord? {
        let parts = source
            .split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        guard let key = parts.last else { return nil }
        var modifiers = Set<KeyModifier>()
        for token in parts.dropLast() {
            switch token {
            case "cmd", "command": modifiers.insert(.command)
            case "shift": modifiers.insert(.shift)
            case "opt", "option", "alt": modifiers.insert(.option)
            case "ctrl", "control": modifiers.insert(.control)
            case "fn", "function": modifiers.insert(.function)
            default: return nil
            }
        }
        return KeyChord(key, modifiers: modifiers)
    }

    private func actionButton(_ action: ActionDescriptor) -> some View {
        Button {
            assign(action)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(action.title)
                        .fontWeight(.semibold)
                    Text("\(action.category) — \(action.detail)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Color(nsColor: .separatorColor))
            }
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }

    private func sectionTitle(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.headline)
    }

    private func assign(_ descriptor: ActionDescriptor) {
        model.assignAction(descriptor, to: input, layer: layer, gesture: gesture)
        dismiss()
    }
}
#endif
