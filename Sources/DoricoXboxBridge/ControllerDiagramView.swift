#if os(macOS)
import AppKit
import SwiftUI
import DoricoBridgeCore

struct ControllerDiagramView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var noteEntry = NoteEntryState.shared
    var selectInput: (XboxInput) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Controller mapping")
                        .font(.headline)
                    Text("Click any control, then choose its action. Editing only “\(model.activeProfileName)”.")
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
                Label("A places \(noteEntry.displayName)", systemImage: "music.note")
                Label("Up/Down changes pitch", systemImage: "arrow.up.arrow.down")
                Label("Only the active layout runs", systemImage: "checkmark.shield")
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
        let action = model.mappedAction(for: input, layer: model.selectedLayer, gesture: model.selectedGesture)
        return Button {
            selectInput(input)
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .frame(width: width, height: height)
                .background(action == nil ? Color.secondary.opacity(0.16) : Color.accentColor.opacity(0.24))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(action == nil ? Color.secondary.opacity(0.45) : Color.accentColor, lineWidth: action == nil ? 1 : 2)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .buttonStyle(.plain)
        .help("\(input.displayName): \(action?.summary ?? "Unmapped")")
        .accessibilityLabel("\(input.displayName). \(action?.summary ?? "Unmapped"). Press to choose an action.")
    }
}
#endif
