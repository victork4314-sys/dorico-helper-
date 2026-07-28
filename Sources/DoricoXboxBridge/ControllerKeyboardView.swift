#if os(macOS)
import SwiftUI

struct ControllerKeyboardView: View {
    @ObservedObject var keyboard: ControllerKeyboardState

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 30, maximum: 64), spacing: 8), count: keyboard.columns)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.52)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(keyboard.purpose.title)
                            .font(.title2.weight(.semibold))
                        Text(keyboard.purpose.prompt)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(keyboard.pageName)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.16))
                        .clipShape(Capsule())
                }

                ScrollView(.horizontal) {
                    Text(keyboard.text.isEmpty ? "Your controller-entered text appears here" : keyboard.text)
                        .font(.system(.title3, design: .monospaced))
                        .foregroundStyle(keyboard.text.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                        .padding(.horizontal, 12)
                        .background(Color(nsColor: .textBackgroundColor))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(nsColor: .separatorColor))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                LazyVGrid(columns: gridColumns, spacing: 8) {
                    ForEach(Array(keyboard.keys.enumerated()), id: \.offset) { index, key in
                        Button {
                            keyboard.selectedIndex = index
                            keyboard.insertSelectedKey()
                        } label: {
                            Text(key)
                                .font(.system(.body, design: .rounded).weight(index == keyboard.selectedIndex ? .bold : .regular))
                                .frame(maxWidth: .infinity, minHeight: 36)
                                .background(index == keyboard.selectedIndex ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                                .foregroundStyle(index == keyboard.selectedIndex ? Color.white : Color.primary)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 7)
                                        .stroke(index == keyboard.selectedIndex ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: index == keyboard.selectedIndex ? 2 : 1)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(key)\(index == keyboard.selectedIndex ? ", selected" : "")")
                    }
                }

                HStack(spacing: 16) {
                    legend("D-pad / left stick", "Move")
                    legend("A", "Type")
                    legend("B", "Delete / back")
                    legend("X", "Space")
                    legend("Y / bumpers", "Next page")
                    legend("Menu / right-stick click", "Submit")
                    Spacer()
                }
                .font(.caption)
            }
            .padding(20)
            .frame(maxWidth: 820)
            .background(.regularMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.accentColor.opacity(0.75), lineWidth: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(24)
        }
    }

    private func legend(_ control: String, _ meaning: String) -> some View {
        HStack(spacing: 5) {
            Text(control)
                .fontWeight(.bold)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 5))
            Text(meaning)
                .foregroundStyle(.secondary)
        }
    }
}
#endif
