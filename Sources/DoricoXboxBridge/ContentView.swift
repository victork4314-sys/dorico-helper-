#if os(macOS)
import SwiftUI
import DoricoBridgeCore

struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            mainContent
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) {
            if let message = model.captureMessage {
                statusBanner(message)
                    .padding()
            }
        }
        .overlay {
            if model.controllerKeyboard.isVisible {
                ControllerKeyboardView(keyboard: model.controllerKeyboard)
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Dorico Xbox Bridge")
                    .font(.title2.weight(.semibold))
                Text("Dorico Pro 6.1 · Xbox controller")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)

            ForEach(AppModel.Section.allCases) { section in
                Button {
                    model.selectSection(section)
                } label: {
                    HStack {
                        Image(systemName: section.symbol)
                            .frame(width: 22)
                        Text(section.rawValue)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(model.selectedSection == section ? Color.accentColor.opacity(0.18) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 6) {
                Label(model.controllerStatus, systemImage: "gamecontroller")
                Label(model.doricoStatus, systemImage: "music.note.list")
                Label(model.bridgeEnabled ? "Bridge enabled" : "Bridge disabled", systemImage: model.bridgeEnabled ? "checkmark.circle" : "pause.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .padding(12)
        }
        .padding(.vertical, 14)
        .frame(width: 235)
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            header
            Divider()
            itemList
            Divider()
            controllerLegend
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(model.selectedSection.rawValue)
                    .font(.title2.weight(.semibold))
                Text(sectionSubtitle)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if model.selectedSection == .commands, !model.commandFilter.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    Text(model.commandFilter)
                        .lineLimit(1)
                    Text("Xbox filter")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.14))
                .clipShape(Capsule())
            }
            if model.selectedSection == .settings || model.selectedSection == .commands {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(model.selectedLayer.displayName)
                    Text(model.selectedGesture.displayName)
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
        }
        .padding(18)
    }

    private var itemList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if model.uiItems.isEmpty {
                        ContentUnavailableView(
                            "Nothing here yet",
                            systemImage: "rectangle.dashed",
                            description: Text(emptyStateText)
                        )
                        .padding(.top, 70)
                    }
                    ForEach(Array(model.uiItems.enumerated()), id: \.element.id) { index, item in
                        itemRow(item, index: index)
                            .id(item.id)
                    }
                    if model.selectedSection == .diagnostics, !model.diagnosticsLog.isEmpty {
                        diagnosticsLog
                    }
                }
                .padding(18)
            }
            .onChange(of: model.selectedRow) { _, newValue in
                let items = model.uiItems
                if items.indices.contains(newValue) {
                    withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(items[newValue].id, anchor: .center) }
                }
            }
        }
    }

    private func itemRow(_ item: AppModel.UIItem, index: Int) -> some View {
        Button {
            model.selectedRow = index
            item.activate()
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(index == model.selectedRow ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: 5)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .fontWeight(index == model.selectedRow ? .semibold : .regular)
                    Text(item.detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                Spacer()
                if item.kind == .adjustable {
                    Image(systemName: "chevron.left.chevron.right")
                        .foregroundStyle(.secondary)
                } else if item.kind == .action {
                    Image(systemName: "button.programmable")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(index == model.selectedRow ? Color.accentColor.opacity(0.11) : Color(nsColor: .controlBackgroundColor))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(index == model.selectedRow ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: index == model.selectedRow ? 2 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var diagnosticsLog: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent events")
                .font(.headline)
            ForEach(Array(model.diagnosticsLog.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, 10)
    }

    private var controllerLegend: some View {
        HStack(spacing: 18) {
            legend("A", "Activate")
            legend("B", "Back / cancel")
            legend("D-pad / left stick", "Move")
            legend("Left / right", "Adjust or change section")
            legend("View", "Show bridge")
            Spacer()
            if let capture = model.captureAction {
                Text("Assigning: \(capture.title)")
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .font(.caption)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private func legend(_ control: String, _ meaning: String) -> some View {
        HStack(spacing: 5) {
            Text(control)
                .fontWeight(.bold)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 5))
            Text(meaning).foregroundStyle(.secondary)
        }
    }

    private func statusBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: model.captureAction == nil ? "info.circle.fill" : "gamecontroller.fill")
            Text(message)
            Spacer()
            Button("Dismiss") { model.captureMessage = nil }
        }
        .padding(12)
        .background(.regularMaterial)
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor.opacity(0.7)) }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var sectionSubtitle: String {
        switch model.selectedSection {
        case .status: "Connection, permissions, Dorico detection, controller text, and universal fallbacks"
        case .mappings: "Every active Xbox binding. Activate a row to remove it."
        case .commands: "Search, create Jump Bar actions, or map any built-in, MIDI Learn, or live Dorico menu command."
        case .profiles: "Switch, duplicate, reset, import, and export complete controller layouts."
        case .settings: "Use left/right to adjust the selected value."
        case .diagnostics: "Real controller, Dorico, Accessibility, MIDI, routing, and stuck-input state."
        }
    }

    private var emptyStateText: String {
        switch model.selectedSection {
        case .mappings: "Choose a command and capture an Xbox input to create a mapping."
        case .commands: "Clear the controller-entered search or scan Dorico menus."
        default: "No items are available."
        }
    }
}
#endif
