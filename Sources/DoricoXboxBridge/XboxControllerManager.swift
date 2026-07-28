#if os(macOS)
import CoreHaptics
import Foundation
import GameController
import DoricoBridgeCore

@MainActor
final class XboxControllerManager {
    enum HapticKind { case tick, soft, success, cancel }

    private weak var model: AppModel?
    private var controller: GCController?
    private var observers: [NSObjectProtocol] = []
    private var digitalStates: [XboxInput: Bool] = [:]
    private var hapticEngine: CHHapticEngine?

    init(model: AppModel) {
        self.model = model
    }

    var statusText: String {
        guard let controller else { return "No Xbox controller connected" }
        let battery = controller.battery.map { " · \(Int($0.batteryLevel * 100))% battery" } ?? ""
        return "\(controller.vendorName ?? "Xbox controller") connected\(battery)"
    }

    func start() {
        observers.append(NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let connected = notification.object as? GCController else { return }
            Task { @MainActor in self?.consider(connected) }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let disconnected = notification.object as? GCController else { return }
            Task { @MainActor in self?.disconnected(disconnected) }
        })

        for candidate in GCController.controllers() { consider(candidate) }
        GCController.startWirelessControllerDiscovery(completionHandler: nil)
    }

    func updateThresholds() {
        digitalStates.removeAll()
    }

    private func consider(_ candidate: GCController) {
        guard isXbox(candidate), candidate.extendedGamepad != nil else {
            model?.log("Ignored non-Xbox controller: \(candidate.vendorName ?? candidate.productCategory)")
            return
        }
        controller = candidate
        attach(candidate)
        prepareHaptics(candidate)
        model?.controllerStatus = statusText
        model?.log("Xbox controller connected: \(candidate.vendorName ?? candidate.productCategory)")
        haptic(.success)
    }

    private func disconnected(_ candidate: GCController) {
        guard candidate === controller else { return }
        controller = nil
        hapticEngine = nil
        digitalStates.removeAll()
        model?.controllerStatus = "No Xbox controller connected"
        model?.log("Xbox controller disconnected")
    }

    private func isXbox(_ candidate: GCController) -> Bool {
        let identity = "\(candidate.vendorName ?? "") \(candidate.productCategory)".lowercased()
        return identity.contains("xbox") || identity.contains("microsoft")
    }

    private func attach(_ controller: GCController) {
        guard let pad = controller.extendedGamepad else { return }

        bind(pad.buttonA, .buttonA)
        bind(pad.buttonB, .buttonB)
        bind(pad.buttonX, .buttonX)
        bind(pad.buttonY, .buttonY)
        bind(pad.leftShoulder, .leftBumper)
        bind(pad.rightShoulder, .rightBumper)
        bind(pad.leftTrigger, .leftTrigger, threshold: { [weak self] in self?.model?.activeProfile.settings.triggerThreshold ?? 0.55 })
        bind(pad.rightTrigger, .rightTrigger, threshold: { [weak self] in self?.model?.activeProfile.settings.triggerThreshold ?? 0.55 })
        if let button = pad.leftThumbstickButton { bind(button, .leftThumbstickButton) }
        if let button = pad.rightThumbstickButton { bind(button, .rightThumbstickButton) }
        bind(pad.buttonMenu, .menu)
        if let button = pad.buttonOptions { bind(button, .view) }
        if let button = pad.buttonHome { bind(button, .guide) }
        bind(pad.dpad.up, .dpadUp)
        bind(pad.dpad.down, .dpadDown)
        bind(pad.dpad.left, .dpadLeft)
        bind(pad.dpad.right, .dpadRight)

        pad.leftThumbstick.valueChangedHandler = { [weak self] _, x, y in
            Task { @MainActor in self?.handleStick(x: x, y: y, left: true) }
        }
        pad.rightThumbstick.valueChangedHandler = { [weak self] _, x, y in
            Task { @MainActor in self?.handleStick(x: x, y: y, left: false) }
        }
    }

    private func bind(
        _ button: GCControllerButtonInput,
        _ input: XboxInput,
        threshold: @escaping () -> Float = { 0.5 }
    ) {
        button.valueChangedHandler = { [weak self] _, value, _ in
            Task { @MainActor in
                guard let self else { return }
                self.emitDigital(input, pressed: value >= threshold(), value: value)
            }
        }
    }

    private func handleStick(x: Float, y: Float, left: Bool) {
        let deadzone = model?.activeProfile.settings.stickDeadzone ?? 0.34
        let releaseZone = max(0.02, deadzone * 0.72)
        let up: XboxInput = left ? .leftStickUp : .rightStickUp
        let down: XboxInput = left ? .leftStickDown : .rightStickDown
        let leftInput: XboxInput = left ? .leftStickLeft : .rightStickLeft
        let rightInput: XboxInput = left ? .leftStickRight : .rightStickRight

        updateAxis(positive: up, negative: down, value: y, engage: deadzone, release: releaseZone)
        updateAxis(positive: rightInput, negative: leftInput, value: x, engage: deadzone, release: releaseZone)
    }

    private func updateAxis(positive: XboxInput, negative: XboxInput, value: Float, engage: Float, release: Float) {
        if value >= engage {
            emitDigital(positive, pressed: true, value: value)
            emitDigital(negative, pressed: false, value: 0)
        } else if value <= -engage {
            emitDigital(negative, pressed: true, value: -value)
            emitDigital(positive, pressed: false, value: 0)
        } else if abs(value) <= release {
            emitDigital(positive, pressed: false, value: 0)
            emitDigital(negative, pressed: false, value: 0)
        }
    }

    private func emitDigital(_ input: XboxInput, pressed: Bool, value: Float) {
        guard digitalStates[input] != pressed else { return }
        digitalStates[input] = pressed
        let event = ControllerEvent(
            input: input,
            isPressed: pressed,
            value: value,
            timestamp: ProcessInfo.processInfo.systemUptime
        )
        model?.receiveControllerEvent(event)
    }

    private func prepareHaptics(_ controller: GCController) {
        guard let haptics = controller.haptics,
              haptics.supportedLocalities.contains(.default) else { return }
        hapticEngine = haptics.createEngine(withLocality: .default)
        try? hapticEngine?.start()
    }

    func haptic(_ kind: HapticKind) {
        guard model?.activeProfile.settings.hapticsEnabled == true,
              let hapticEngine else { return }
        let values: (Float, Float) = switch kind {
        case .tick: (0.18, 0.35)
        case .soft: (0.30, 0.48)
        case .success: (0.55, 0.65)
        case .cancel: (0.42, 0.30)
        }
        do {
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: values.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: values.1)
                ],
                relativeTime: 0
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try hapticEngine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            model?.log("Haptic failed: \(error.localizedDescription)")
        }
    }
}
#endif
