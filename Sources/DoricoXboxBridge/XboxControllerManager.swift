#if os(macOS)
import AppKit
import CoreHaptics
import Foundation
import GameController
import DoricoBridgeCore

@MainActor
final class XboxControllerManager {
    enum HapticKind { case tick, soft, success, cancel }

    private enum InputPath: String {
        case callback = "callback"
        case polling = "60 Hz polling backup"
    }

    private weak var model: AppModel?
    private var controller: GCController?
    private var observers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var inputState = ControllerInputState()
    private var pollingTimer: Timer?
    private var watchdogTimer: Timer?
    private var hapticEngine: CHHapticEngine?
    private var callbackEventCount = 0
    private var pollingEventCount = 0
    private var lastInputPath: InputPath?

    init(model: AppModel) {
        self.model = model
    }

    var statusText: String {
        guard let controller else { return "No Xbox controller connected · background monitoring on · polling backup armed" }
        let battery = controller.battery.map { " · \(Int($0.batteryLevel * 100))% battery" } ?? ""
        let path = lastInputPath.map { " · last input: \($0.rawValue)" } ?? ""
        return "\(controller.vendorName ?? "Xbox controller") connected\(battery) · background on · callback + polling\(path)"
    }

    func start() {
        hardenBackgroundMonitoring(reason: "startup", alwaysLog: true)
        registerControllerObservers()
        registerLifecycleRecovery()
        startPollingBackup()
        startTransportWatchdog()
        reconcileControllers(forceReattach: true)
        GCController.startWirelessControllerDiscovery(completionHandler: nil)
    }

    func updateThresholds() {
        inputState.reset()
        model?.resetControllerState()
    }

    private func registerControllerObservers() {
        observers.append(NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.recoverTransport(reason: "controller connected") }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.recoverTransport(reason: "controller disconnected") }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.recoverTransport(reason: "bridge moved to background") }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.recoverTransport(reason: "bridge became active") }
        })
    }

    private func registerLifecycleRecovery() {
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.recoverTransport(reason: "Mac woke from sleep") }
        })
        workspaceObservers.append(center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.recoverTransport(reason: "frontmost app changed") }
        })
    }

    private func startPollingBackup() {
        guard pollingTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.pollControllerState() }
        }
        timer.tolerance = 0.003
        RunLoop.main.add(timer, forMode: .common)
        pollingTimer = timer
        model?.log("60 Hz direct controller polling backup armed")
    }

    private func startTransportWatchdog() {
        guard watchdogTimer == nil else { return }
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.watchdogTick() }
        }
        timer.tolerance = 0.15
        RunLoop.main.add(timer, forMode: .common)
        watchdogTimer = timer
        model?.log("Controller transport watchdog armed")
    }

    private func watchdogTick() {
        hardenBackgroundMonitoring(reason: "watchdog")
        let connected = GCController.controllers()
        if let active = controller {
            if !connected.contains(where: { $0 === active }) {
                reconcileControllers(forceReattach: true)
            }
        } else {
            reconcileControllers(forceReattach: true)
        }
        model?.controllerStatus = statusText
    }

    private func recoverTransport(reason: String) {
        hardenBackgroundMonitoring(reason: reason)
        reconcileControllers(forceReattach: true)
        if controller == nil {
            GCController.startWirelessControllerDiscovery(completionHandler: nil)
        }
        model?.controllerStatus = statusText
    }

    private func hardenBackgroundMonitoring(reason: String, alwaysLog: Bool = false) {
        let wasEnabled = GCController.shouldMonitorBackgroundEvents
        if !wasEnabled {
            GCController.shouldMonitorBackgroundEvents = true
        }
        if alwaysLog || !wasEnabled {
            model?.log("Background Xbox monitoring enabled/reasserted: \(reason)")
        }
    }

    private func reconcileControllers(forceReattach: Bool = false) {
        let candidates = GCController.controllers().filter { isXbox($0) && $0.extendedGamepad != nil }
        if let active = controller, candidates.contains(where: { $0 === active }) {
            if forceReattach { attach(active) }
            model?.controllerStatus = statusText
            return
        }
        if let candidate = candidates.first {
            consider(candidate)
        } else if controller != nil {
            disconnected()
        }
    }

    private func consider(_ candidate: GCController) {
        guard isXbox(candidate), candidate.extendedGamepad != nil else {
            model?.log("Ignored non-Xbox controller: \(candidate.vendorName ?? candidate.productCategory)")
            return
        }
        if controller !== candidate {
            inputState.reset()
            model?.resetControllerState()
        }
        controller = candidate
        attach(candidate)
        prepareHaptics(candidate)
        model?.controllerStatus = statusText
        model?.log("Xbox controller connected with callback and polling paths: \(candidate.vendorName ?? candidate.productCategory)")
        haptic(.success)
    }

    private func disconnected() {
        controller = nil
        hapticEngine = nil
        inputState.reset()
        lastInputPath = nil
        model?.resetControllerState()
        model?.controllerStatus = statusText
        model?.log("Xbox controller disconnected; discovery and polling remain armed")
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
            Task { @MainActor in self?.handleStick(x: x, y: y, left: true, source: .callback) }
        }
        pad.rightThumbstick.valueChangedHandler = { [weak self] _, x, y in
            Task { @MainActor in self?.handleStick(x: x, y: y, left: false, source: .callback) }
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
                self.emitDigital(input, pressed: value >= threshold(), value: value, source: .callback)
            }
        }
    }

    private func pollControllerState() {
        guard let pad = controller?.extendedGamepad else { return }
        let triggerThreshold = model?.activeProfile.settings.triggerThreshold ?? 0.55

        sample(pad.buttonA, .buttonA)
        sample(pad.buttonB, .buttonB)
        sample(pad.buttonX, .buttonX)
        sample(pad.buttonY, .buttonY)
        sample(pad.leftShoulder, .leftBumper)
        sample(pad.rightShoulder, .rightBumper)
        sample(pad.leftTrigger, .leftTrigger, threshold: triggerThreshold)
        sample(pad.rightTrigger, .rightTrigger, threshold: triggerThreshold)
        if let button = pad.leftThumbstickButton { sample(button, .leftThumbstickButton) }
        if let button = pad.rightThumbstickButton { sample(button, .rightThumbstickButton) }
        sample(pad.buttonMenu, .menu)
        if let button = pad.buttonOptions { sample(button, .view) }
        if let button = pad.buttonHome { sample(button, .guide) }
        sample(pad.dpad.up, .dpadUp)
        sample(pad.dpad.down, .dpadDown)
        sample(pad.dpad.left, .dpadLeft)
        sample(pad.dpad.right, .dpadRight)
        handleStick(x: pad.leftThumbstick.xAxis.value, y: pad.leftThumbstick.yAxis.value, left: true, source: .polling)
        handleStick(x: pad.rightThumbstick.xAxis.value, y: pad.rightThumbstick.yAxis.value, left: false, source: .polling)
    }

    private func sample(_ button: GCControllerButtonInput, _ input: XboxInput, threshold: Float = 0.5) {
        emitDigital(input, pressed: button.value >= threshold, value: button.value, source: .polling)
    }

    private func handleStick(x: Float, y: Float, left: Bool, source: InputPath) {
        let deadzone = model?.activeProfile.settings.stickDeadzone ?? 0.34
        let releaseZone = max(0.02, deadzone * 0.72)
        let up: XboxInput = left ? .leftStickUp : .rightStickUp
        let down: XboxInput = left ? .leftStickDown : .rightStickDown
        let leftInput: XboxInput = left ? .leftStickLeft : .rightStickLeft
        let rightInput: XboxInput = left ? .leftStickRight : .rightStickRight

        updateAxis(positive: up, negative: down, value: y, engage: deadzone, release: releaseZone, source: source)
        updateAxis(positive: rightInput, negative: leftInput, value: x, engage: deadzone, release: releaseZone, source: source)
    }

    private func updateAxis(
        positive: XboxInput,
        negative: XboxInput,
        value: Float,
        engage: Float,
        release: Float,
        source: InputPath
    ) {
        if value >= engage {
            emitDigital(positive, pressed: true, value: value, source: source)
            emitDigital(negative, pressed: false, value: 0, source: source)
        } else if value <= -engage {
            emitDigital(negative, pressed: true, value: -value, source: source)
            emitDigital(positive, pressed: false, value: 0, source: source)
        } else if abs(value) <= release {
            emitDigital(positive, pressed: false, value: 0, source: source)
            emitDigital(negative, pressed: false, value: 0, source: source)
        }
    }

    private func emitDigital(_ input: XboxInput, pressed: Bool, value: Float, source: InputPath) {
        guard let event = inputState.eventIfChanged(
            input: input,
            pressed: pressed,
            value: value,
            timestamp: ProcessInfo.processInfo.systemUptime
        ) else { return }

        switch source {
        case .callback: callbackEventCount += 1
        case .polling: pollingEventCount += 1
        }
        lastInputPath = source
        model?.controllerStatus = statusText
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
