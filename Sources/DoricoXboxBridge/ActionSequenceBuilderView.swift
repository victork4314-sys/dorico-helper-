#if os(macOS)
import AppKit
import SwiftUI
import DoricoBridgeCore

struct ActionSequenceDraftStep: Identifiable, Equatable {
    let id = UUID()
    var descriptor: ActionDescriptor
    var delayMilliseconds: Int = 0

    var commandStep: CommandStep {
        CommandStep(descriptor.action, delayMilliseconds: UInt64(max(0, delayMilliseconds)))
    }
}

struct ActionSequenceBuilderView: View {
    @Binding var name: String
    @Binding var steps: [ActionSequenceDraftStep]
    let assignSequence: () -> Void

    var body: some View {
        GroupBox("Shortcuts-style action sequence") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Add any simple action, Dorico command, keyboard shortcut, text, Jump Bar action, MIDI pitch, or pointer action. Reorder them and set the wait before each step.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                TextField("Sequence name (optional)", text: $name)
                    .textFieldStyle(.roundedBorder)

                if steps.isEmpty {
                    ContentUnavailableView(
                        "No actions in this sequence",
                        systemImage: "square.stack.3d.up.slash",
                        description: Text("Use any Add to sequence button below.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } else {
                    VStack(spacing: 8) {
                        ForEach(Array(steps.indices), id: \.self) { index in
                            sequenceRow(index)
                        }
                    }
                }

                HStack {
                    Button("Clear sequence", role: .destructive) { steps.removeAll() }
                        .disabled(steps.isEmpty)
                    Spacer()
                    Button("Assign this sequence") { assignSequence() }
                        .buttonStyle(.borderedProminent)
                        .disabled(steps.isEmpty)
                }
            }
            .padding(8)
        }
    }

    private func sequenceRow(_ index: Int) -> some View {
        let step = steps[index]
        return HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.headline.monospacedDigit())
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.16))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(step.descriptor.title).fontWeight(.semibold)
                Text(step.descriptor.action.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Stepper(value: delayBinding(index), in: 0...5000, step: 25) {
                Text(step.delayMilliseconds == 0 ? "No wait" : "Wait \(step.delayMilliseconds) ms")
                    .font(.caption.monospacedDigit())
                    .frame(minWidth: 92, alignment: .trailing)
            }

            Button { move(index, by: -1) } label: { Image(systemName: "arrow.up") }
                .disabled(index == 0)
                .help("Move earlier")
            Button { move(index, by: 1) } label: { Image(systemName: "arrow.down") }
                .disabled(index == steps.count - 1)
                .help("Move later")
            Button(role: .destructive) { steps.remove(at: index) } label: { Image(systemName: "trash") }
                .help("Remove this action")
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay { RoundedRectangle(cornerRadius: 9).stroke(Color(nsColor: .separatorColor)) }
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private func delayBinding(_ index: Int) -> Binding<Int> {
        Binding(
            get: { steps.indices.contains(index) ? steps[index].delayMilliseconds : 0 },
            set: { value in
                guard steps.indices.contains(index) else { return }
                steps[index].delayMilliseconds = value
            }
        )
    }

    private func move(_ index: Int, by offset: Int) {
        let destination = index + offset
        guard steps.indices.contains(index), steps.indices.contains(destination) else { return }
        steps.swapAt(index, destination)
    }
}
#endif
