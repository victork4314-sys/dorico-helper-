#if os(macOS)
import AppKit
import SwiftUI
import DoricoBridgeCore

struct ControllerDiagramView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var noteEntry = NoteEntryState.shared
    @Binding var selectedInputs: Set<XboxInput>
    var mapSelection: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Controller combination mapping")
                        .font(.headline)
                    Text("Select any number of controls, then map that exact combination. Editing only “\(model.activeProfileName)”.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("Selected pitch")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(noteEntry.displayName)
                        .font(.title3.monospacedDigit().weight(.semibold))
                }
            }

            HStack(spacing: 10) {
                Button("Map selected combination") { mapSelection() }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedInputs.isEmpty)
                Button("Clear selection") { selectedInputs.removeAll() }
                    .disabled(selectedInputs.isEmpty)
                Button("Select every control") { selectedInputs = Set(XboxInput.allCases) }
                Spacer()
                Text(selectionDescription)
                    .font(.caption.monospaced())
                    .foregroundStyle(selectedInputs.isEmpty ? Color.secondary : Color.accentColor)
                    .lineLimit(2)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                ZStack {
                    RoundedRectangle(cornerRadius: 118, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .overlay {
                            RoundedRectangle(cornerRadius: 118, style: .continuous)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 2)
                        }
                        .frame(width: 700, height: 286)
                        .position(x: 380, y: 190)

                    shoulder(.leftTrigger, "LT", x: 150, y: 28)
                    shoulder(.leftBumper, "LB", x: 230, y: 54)
                    shoulder(.rightBumper, "RB", x: 530, y: 54)
                    shoulder(.rightTrigger, "RT", x: 610, y: 28)

                    face(.buttonY, "Y", x: 590, y: 128)
                    face(.buttonX, "X", x: 548, y: 170)
                    face(.buttonB, "B", x: 632, y: 170)
                    face(.buttonA, "A", x: 590, y: 212)

                    small(.view, "View", x: 328, y: 146)
                    small(.guide, "Xbox", x: 380, y: 122, width: 58)
                    small(.menu, "Menu", x: 432, y: 146)

                    stick(centerX: 245, centerY: 155, click: .leftThumbstickButton,
                          up: .leftStickUp, down: .leftStickDown,
                          left: .leftStickLeft, right: .leftStickRight,
                          title: "LS")
                    stick(centerX: 475, centerY: 245, click: .rightThumbstickButton,
                          up: .rightStickUp, down: .rightStickDown,
                          left: .rightStickLeft, right: .rightStickRight,
                          title: "RS")

                    dpad(centerX: 305, centerY: 250)
                }
                .frame(width: 760, height: 350)
            }

            HStack(spacing: 16) {
                Label("One control or every control", systemImage: "square.stack.3d.up")
                Label("Order does not matter", systemImage: "arrow.triangle.swap")
                Label("Exact match—no smaller action leakage", systemImage: "checkmark.shield")
                Label("Only the active layout runs", systemImage: "rectangle.stack.fill")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.55))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var selectionDescription: String {
        guard !selectedInputs.isEmpty else { return "No controls selected" }
        return XboxInput.allCases
            .filter(selectedInputs.contains)
            .map(\.displayName)
            .joined(separator: " + ")
    }

    private func toggle(_ input: XboxInput) {
        if selectedInputs.contains(input) {
            selectedInputs.remove(input)
        } else {
            selectedInputs.insert(input)
        }
    }

    private func shoulder(_ input: XboxInput, _ label: String, x: CGFloat, y: CGFloat) -> some View {
        mappingButton(input, label: label, width: 72, height: 34, cornerRadius: 10)
            .position(x: x, y: y)
    }

    private func face(_ input: XboxInput, _ label: String, x: CGFloat, y: CGFloat) -> some View {
        mappingButton(input, label: label, width: 42, height: 42, cornerRadius: 21)
            .position(x: x, y: y)
    }

    private func small(_ input: XboxInput, _ label: String, x: CGFloat, y: CGFloat, width: CGFloat = 46) -> some View {
        mappingButton(input, label: label, width: width, height: 28, cornerRadius: 14)
            .position(x: x, y: y)
    }

    private func stick(
        centerX: CGFloat,
        centerY: CGFloat,
        click: XboxInput,
        up: XboxInput,
        down: XboxInput,
        left: XboxInput,
        right: XboxInput,
        title: String
    ) -> some View {
        ZStack {
            Circle()
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 102, height: 102)
            mappingButton(click, label: title, width: 58, height: 58, cornerRadius: 29)
            mappingButton(up, label: "↑", width: 28, height: 24, cornerRadius: 8)
                .offset(y: -62)
            mappingButton(down, label: "↓", width: 28, height: 24, cornerRadius: 8)
                .offset(y: 62)
            mappingButton(left, label: "←", width: 28, height: 24, cornerRadius: 8)
                .offset(x: -62)
            mappingButton(right, label: "→", width: 28, height: 24, cornerRadius: 8)
                .offset(x: 62)
        }
        .frame(width: 160, height: 160)
        .position(x: centerX, y: centerY)
    }

    private func dpad(centerX: CGFloat, centerY: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 104, height: 104)
            mappingButton(.dpadUp, label: "↑", width: 34, height: 34, cornerRadius: 8)
                .offset(y: -37)
            mappingButton(.dpadDown, label: "↓", width: 34, height: 34, cornerRadius: 8)
                .offset(y: 37)
            mappingButton(.dpadLeft, label: "←", width: 34, height: 34, cornerRadius: 8)
                .offset(x: -37)
            mappingButton(.dpadRight, label: "→", width: 34, height: 34, cornerRadius: 8)
                .offset(x: 37)
        }
        .frame(width: 130, height: 130)
        .position(x: centerX, y: centerY)
    }

    private func mappingButton(
        _ input: XboxInput,
        label: String,
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat
    ) -> some View {
        let selected = selectedInputs.contains(input)
        let singleAction = model.mappedAction(
            for: [input],
            pointerMode: model.selectedLayer == .pointer,
            gesture: model.selectedGesture
        )
        return Button {
            toggle(input)
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .frame(width: width, height: height)
                .background(
                    selected
                        ? Color.accentColor.opacity(0.42)
                        : (singleAction == nil ? Color.secondary.opacity(0.16) : Color.accentColor.opacity(0.16))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            selected ? Color.accentColor : (singleAction == nil ? Color.secondary.opacity(0.45) : Color.accentColor),
                            lineWidth: selected ? 3 : (singleAction == nil ? 1 : 2)
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .buttonStyle(.plain)
        .help("\(input.displayName): \(selected ? "selected for combination" : (singleAction?.summary ?? "not selected"))")
        .accessibilityLabel("\(input.displayName). \(selected ? "Selected for the combination" : "Not selected"). Press to toggle.")
    }
}
#endif
