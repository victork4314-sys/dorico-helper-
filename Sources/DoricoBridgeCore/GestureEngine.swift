import Foundation

public struct GestureEngine: Sendable {
    private struct State: Sendable {
        var isPressed = false
        var pressedAt: TimeInterval = 0
        var nextRepeatAt: TimeInterval = 0
        var holdEmitted = false
        var pendingSingleDeadline: TimeInterval?
        var pendingBumperDeadline: TimeInterval?
        var lastReleaseAt: TimeInterval?
    }

    private var states: [XboxInput: State] = [:]
    private let bumperComboWindow: TimeInterval = 0.120

    public init() {}

    public mutating func ingest(_ event: ControllerEvent, profile: ControllerProfile) -> [GestureEmission] {
        var state = states[event.input] ?? State()
        var output: [GestureEmission] = []
        let settings = profile.settings
        let supportsDouble = profile.hasBinding(input: event.input, gesture: .doublePress)
        let isBumper = event.input == .leftBumper || event.input == .rightBumper
        let supportsBumperCombo = profile.bindings.keys.contains { $0.layer == .bothBumpers && $0.gesture == .press }

        if event.isPressed && !state.isPressed {
            state.isPressed = true
            state.pressedAt = event.timestamp
            state.nextRepeatAt = event.timestamp + settings.repeatDelay
            state.holdEmitted = false

            if isBumper && supportsBumperCombo {
                let other: XboxInput = event.input == .leftBumper ? .rightBumper : .leftBumper
                if var otherState = states[other], otherState.isPressed, otherState.pendingBumperDeadline != nil {
                    otherState.pendingBumperDeadline = nil
                    states[other] = otherState
                    output.append(GestureEmission(input: event.input, gesture: .press, timestamp: event.timestamp))
                } else {
                    state.pendingBumperDeadline = event.timestamp + bumperComboWindow
                }
            } else if supportsDouble,
                      let lastRelease = state.lastReleaseAt,
                      event.timestamp - lastRelease <= settings.doublePressWindow {
                state.pendingSingleDeadline = nil
                output.append(GestureEmission(input: event.input, gesture: .doublePress, timestamp: event.timestamp))
            } else if supportsDouble {
                state.pendingSingleDeadline = event.timestamp + settings.doublePressWindow
            } else {
                output.append(GestureEmission(input: event.input, gesture: .press, timestamp: event.timestamp))
            }
        } else if !event.isPressed && state.isPressed {
            state.isPressed = false
            state.lastReleaseAt = event.timestamp
            if state.pendingBumperDeadline != nil {
                state.pendingBumperDeadline = nil
                output.append(GestureEmission(input: event.input, gesture: .press, timestamp: event.timestamp))
            }
            output.append(GestureEmission(input: event.input, gesture: .release, timestamp: event.timestamp))
        }

        states[event.input] = state
        return output
    }

    public mutating func tick(at timestamp: TimeInterval, profile: ControllerProfile) -> [GestureEmission] {
        var output: [GestureEmission] = []
        let settings = profile.settings

        for input in states.keys {
            guard var state = states[input] else { continue }

            if let deadline = state.pendingBumperDeadline, timestamp >= deadline {
                state.pendingBumperDeadline = nil
                output.append(GestureEmission(input: input, gesture: .press, timestamp: deadline))
            }
            if let deadline = state.pendingSingleDeadline, timestamp >= deadline {
                state.pendingSingleDeadline = nil
                output.append(GestureEmission(input: input, gesture: .press, timestamp: deadline))
            }
            if state.isPressed {
                if !state.holdEmitted, timestamp - state.pressedAt >= settings.holdDelay {
                    state.holdEmitted = true
                    output.append(GestureEmission(input: input, gesture: .hold, timestamp: timestamp))
                }
                if state.pendingBumperDeadline == nil, timestamp >= state.nextRepeatAt {
                    state.nextRepeatAt = timestamp + settings.repeatRate
                    output.append(GestureEmission(input: input, gesture: .repeatPress, timestamp: timestamp))
                }
            }
            states[input] = state
        }
        return output
    }

    public mutating func reset() { states.removeAll() }
}

public struct BindingResolver: Sendable {
    public init() {}

    public func activeLayer(heldInputs: Set<XboxInput>, pointerMode: Bool) -> MappingLayer {
        if pointerMode { return .pointer }
        let lt = heldInputs.contains(.leftTrigger)
        let rt = heldInputs.contains(.rightTrigger)
        let lb = heldInputs.contains(.leftBumper)
        let rb = heldInputs.contains(.rightBumper)
        if lt && rt { return .bothTriggers }
        if lb && rb { return .bothBumpers }
        if lt { return .leftTrigger }
        if rt { return .rightTrigger }
        if lb { return .leftBumper }
        if rb { return .rightBumper }
        return .base
    }

    public func resolve(
        emission: GestureEmission,
        heldInputs: Set<XboxInput>,
        pointerMode: Bool,
        helperUIActive: Bool,
        profile: ControllerProfile
    ) -> CommandAction? {
        if helperUIActive {
            switch emission.input {
            case .buttonB where emission.gesture == .press: return .internalCommand(.helperBack)
            case .buttonA where emission.gesture == .press: return .internalCommand(.helperActivate)
            case .view where emission.gesture == .press,
                 .guide where emission.gesture == .press: return .internalCommand(.toggleDashboard)
            case .dpadUp where emission.gesture == .press || emission.gesture == .repeatPress,
                 .leftStickUp where emission.gesture == .press || emission.gesture == .repeatPress: return .internalCommand(.helperUp)
            case .dpadDown where emission.gesture == .press || emission.gesture == .repeatPress,
                 .leftStickDown where emission.gesture == .press || emission.gesture == .repeatPress: return .internalCommand(.helperDown)
            case .dpadLeft where emission.gesture == .press || emission.gesture == .repeatPress,
                 .leftStickLeft where emission.gesture == .press || emission.gesture == .repeatPress: return .internalCommand(.helperLeft)
            case .dpadRight where emission.gesture == .press || emission.gesture == .repeatPress,
                 .leftStickRight where emission.gesture == .press || emission.gesture == .repeatPress: return .internalCommand(.helperRight)
            case .leftBumper where emission.gesture == .press || emission.gesture == .repeatPress: return .internalCommand(.helperDecrease)
            case .rightBumper where emission.gesture == .press || emission.gesture == .repeatPress: return .internalCommand(.helperIncrease)
            default: return nil
            }
        }

        let bothBumpers = heldInputs.contains(.leftBumper) && heldInputs.contains(.rightBumper)
        let layer: MappingLayer
        if bothBumpers && (emission.input == .leftBumper || emission.input == .rightBumper) {
            layer = .bothBumpers
        } else {
            // A modifier's own standalone press belongs to Base. Other inputs
            // pressed while that modifier is held belong to the modifier layer.
            layer = activeLayer(heldInputs: heldInputs.subtracting([emission.input]), pointerMode: pointerMode)
        }

        let exact = BindingKey(layer: layer, input: emission.input, gesture: emission.gesture)
        if let action = profile.action(for: exact) { return action }
        if emission.gesture == .repeatPress {
            let press = BindingKey(layer: layer, input: emission.input, gesture: .press)
            if let action = profile.action(for: press) { return action }
        }
        // No base fallback: an unmapped combination does nothing.
        return nil
    }
}