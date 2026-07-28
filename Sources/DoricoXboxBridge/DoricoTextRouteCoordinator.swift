#if os(macOS)
import Combine
import Foundation
import DoricoBridgeCore

@MainActor
final class DoricoTextRouteCoordinator {
    static let shared = DoricoTextRouteCoordinator()

    private var pendingRoute: DoricoTextRoute?
    private var openingRoutedKeyboard = false
    private var keyboardObservation: AnyCancellable?

    private init() {}

    func begin(_ route: DoricoTextRoute, model: AppModel) {
        pendingRoute = route
        observeKeyboardIfNeeded(model: model)
        openingRoutedKeyboard = true
        model.showDashboard()
        model.openControllerKeyboard(.typeIntoDorico)
        openingRoutedKeyboard = false
    }

    func keyboardWillOpen(_ purpose: ControllerKeyboardState.Purpose) {
        if purpose != .typeIntoDorico || !openingRoutedKeyboard {
            pendingRoute = nil
        }
    }

    func cancel() {
        pendingRoute = nil
    }

    func consumeAction(for text: String) -> CommandAction? {
        guard let route = pendingRoute else { return nil }
        pendingRoute = nil
        return action(for: route, text: text)
    }

    private func observeKeyboardIfNeeded(model: AppModel) {
        guard keyboardObservation == nil else { return }
        keyboardObservation = model.controllerKeyboard.$isVisible
            .dropFirst()
            .sink { [weak self, weak model] visible in
                guard !visible else { return }
                DispatchQueue.main.async {
                    guard let self, let model else { return }
                    // Submission sets dashboardVisible to false before hiding the
                    // app. Cancel/back leaves the dashboard visible. This keeps a
                    // submitted route alive exactly long enough to be consumed,
                    // while clearing every cancellation path, including View and
                    // controller disconnect/reset.
                    if model.dashboardVisible && !model.controllerKeyboard.isVisible {
                        self.cancel()
                    }
                }
            }
    }

    private func action(for route: DoricoTextRoute, text: String) -> CommandAction {
        switch route {
        case .focusedField:
            return .typeText(text)
        case .jumpBarCommands:
            return .sequence([
                CommandStep(.keyChord(KeyChord("j"))),
                CommandStep(.keyChord(KeyChord("1", modifiers: [.control])), delayMilliseconds: 90),
                CommandStep(.typeText(text), delayMilliseconds: 100),
                CommandStep(.keyChord(KeyChord("return")), delayMilliseconds: 45)
            ])
        case .jumpBarGoTo:
            return .sequence([
                CommandStep(.keyChord(KeyChord("j"))),
                CommandStep(.keyChord(KeyChord("2", modifiers: [.control])), delayMilliseconds: 90),
                CommandStep(.typeText(text), delayMilliseconds: 100),
                CommandStep(.keyChord(KeyChord("return")), delayMilliseconds: 45)
            ])
        case .dynamicsPopover:
            return popover(key: "d", text: text)
        case .ornamentsPopover:
            return popover(key: "o", text: text)
        case .meterPopover:
            return popover(key: "m", text: text)
        case .keySignaturePopover:
            return popover(key: "k", text: text)
        case .tempoPopover:
            return popover(key: "t", text: text)
        case .clefPopover:
            return popover(key: "c", text: text)
        case .playingTechniquesPopover:
            return popover(key: "p", text: text)
        case .barsAndBarlinesPopover:
            return popover(key: "b", text: text)
        }
    }

    private func popover(key: String, text: String) -> CommandAction {
        .sequence([
            CommandStep(.keyChord(KeyChord(key, modifiers: [.shift]))),
            CommandStep(.typeText(text), delayMilliseconds: 110),
            CommandStep(.keyChord(KeyChord("return")), delayMilliseconds: 45)
        ])
    }
}
#endif
