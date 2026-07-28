#if os(macOS)
import SwiftUI
import DoricoBridgeCore

struct MappingAddView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var selectedLayer: MappingLayer

    init(model: AppModel) {
        self.model = model
        _selectedLayer = State(initialValue: model.selectedLayer)
    }

    private var commands: [ActionDescriptor] {
        let all = model.displayedCommands
        guard !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return all }
        return all.filter {
            $0.title.localizedCaseInsensitiveContains(search) ||
            $0.category.localizedCaseInsensitiveContains(search) ||
            $0.detail.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Add Mapping")
                        .font(.title2.weight(.semibold))
                    Text("Choose what the controller should do, then press the controller input that should do it.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding(18)

            Divider()

            HStack(spacing: 14) {
                Picker("Context", selection: $selectedLayer) {
                    ForEach(MappingLayer.allCases, id: \.self) { layer in
                        Text(layer.displayName).tag(layer)
                    }
                }
                .frame(width: 220)

                TextField("Search commands", text: $search)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(18)

            Divider()

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(commands) { command in
                        Button {
                            model.selectedLayer = selectedLayer
                            model.selectedGesture = .press
                            model.beginCapture(command)
                            model.captureMessage = "Press the controller button, stick direction, trigger, bumper, or combination for \(command.title). B cancels."
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(command.title)
                                        .fontWeight(.semibold)
                                    Text("\(command.category) — \(command.detail)")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                Text(selectedLayer.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .overlay {
                                RoundedRectangle(cornerRadius: 9)
                                    .stroke(Color(nsColor: .separatorColor))
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(18)
            }
        }
        .frame(minWidth: 720, minHeight: 560)
    }
}
#endif
