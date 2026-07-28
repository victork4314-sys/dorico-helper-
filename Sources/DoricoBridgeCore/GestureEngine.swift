import Foundation

public struct GestureEngine: Sendable {
    private struct RawState: Sendable {
        var isPressed = false
        var pressedAt: TimeInterval = 0
        var nextRepeatAt: TimeInterval = 0
        var holdEmitted = false
        var pendingSingleDeadline: TimeInterval?
        var lastReleaseAt: TimeInterval?
    }

    private struct PendingPress: Sendable {
        var inputs: Set<XboxInput>
        var primaryInput: XboxInput
        var pointerMode: Bool
        var deadline: TimeInterval?
        var waitsForDouble: Bool
    }

    private var rawStates: [XboxInput: RawState] = [:]
    private var pressedAt: [XboxInput: TimeInterval] = [:]
    private var pendingPress: PendingPress?
    private var activeChord: Set<XboxInput> = []
    private var activePrimary: XboxInput?
    private var activeChordStartedAt: TimeInterval = 0
    private var activeNextRepeatAt: TimeInterval = 0
    private var activeHoldEmitted = false
    private var activePressEmittedChord: Set<XboxInput>?
    private var lastReleasedChord: Set<XboxInput>?
    private var lastReleaseAt: TimeInterval?

    public init() {}

    public mutating func ingest(
        _ event: ControllerEvent,
        profile: ControllerProfile,
        pointerMode: Bool = false,
        rawMode: Bool = false
    ) -> [GestureEmission] {
        if rawMode {
            return ingestRaw(event, profile: profile)
        }

        var output: [GestureEmission] = []
        let settings = profile.settings
        let wasPressed = pressedAt[event.input] != nil

        if event.isPressed && !wasPressed {
            // A released single waiting for a possible double-press must be
            // completed before an unrelated chord begins.
            if let pending = pendingPress,
               pending.waitsForDouble,
               pressedAt.isEmpty,
               pending.inputs != [event.input] {
                output.append(emission(for: pending, gesture: .press, timestamp: event.timestamp))
                pendingPress = nil
            }

            pressedAt[event.input] = event.timestamp
            let chord = Set(pressedAt.keys)

            // Expanding a chord cancels the smaller pending action. This is the
            // core no-leak rule: A never fires underneath A+LT, and A+LT never
            // fires underneath A+LT+RB, regardless of how many controls exist.
            if let pending = pendingPress, pending.inputs != chord {
                pendingPress = nil
            }

            beginActiveChord(chord, primaryInput: event.input, timestamp: event.timestamp, settings: settings)

            let supportsDouble = profile.hasBinding(
                inputs: chord,
                gesture: .doublePress,
                pointerMode: pointerMode
            )
            let isDouble = supportsDouble &&
                lastReleasedChord == chord &&
                event.timestamp - (lastReleaseAt ?? -.infinity) <= settings.doublePressWindow

            if isDouble {
                pendingPress = nil
                activePressEmittedChord = chord
                output.append(GestureEmission(
                    inputs: chord,
                    primaryInput: event.input,
                    gesture: .doublePress,
                    timestamp: event.timestamp
                ))
                return output
            }

            let hasPress = profile.hasBinding(inputs: chord, gesture: .press, pointerMode: pointerMode)
            let hasLargerChord = profile.hasStrictSuperset(of: chord, pointerMode: pointerMode)

            guard hasPress else {
                // The chord may still be a prefix of a larger mapping. Nothing
                // fires until an exact configured set is reached.
                return output
            }

            if supportsDouble {
                pendingPress = PendingPress(
                    inputs: chord,
                    primaryInput: event.input,
                    pointerMode: pointerMode,
                    deadline: event.timestamp + settings.doublePressWindow,
                    waitsForDouble: true
                )
            } else if hasLargerChord {
                // Wait until release or expansion. There is deliberately no
                // timeout: a slow deliberate larger combination must not leak
                // the smaller action first.
                pendingPress = PendingPress(
                    inputs: chord,
                    primaryInput: event.input,
                    pointerMode: pointerMode,
                    deadline: nil,
                    waitsForDouble: false
                )
            } else {
                activePressEmittedChord = chord
                output.append(GestureEmission(
                    inputs: chord,
                    primaryInput: event.input,
                    gesture: .press,
                    timestamp: event.timestamp
                ))
            }
        } else if !event.isPressed && wasPressed {
            let chordBeforeRelease = Set(pressedAt.keys)

            if let pending = pendingPress, pending.inputs == chordBeforeRelease {
                if !pending.waitsForDouble {
                    output.append(emission(for: pending, gesture: .press, timestamp: event.timestamp))
                    activePressEmittedChord = chordBeforeRelease
                    pendingPress = nil
                }
                // Double-press singles remain pending until their deadline so
                // the second press can replace them with one double action.
            }

            output.append(GestureEmission(
                inputs: chordBeforeRelease,
                primaryInput: event.input,
                gesture: .release,
                timestamp: event.timestamp
            ))

            pressedAt.removeValue(forKey: event.input)
            lastReleasedChord = chordBeforeRelease
            lastReleaseAt = event.timestamp

            let remaining = Set(pressedAt.keys)
            if remaining.isEmpty {
                clearActiveChord()
            } else {
                // Releasing part of a combination does not synthesize a press
                // for the smaller remaining set.
                beginActiveChord(
                    remaining,
                    primaryInput: activePrimary ?? remaining.first ?? event.input,
                    timestamp: event.timestamp,
                    settings: settings
                )
                activePressEmittedChord = nil
            }
        }

        return output
    }

    public mutating func tick(
        at timestamp: TimeInterval,
        profile: ControllerProfile,
        pointerMode: Bool = false,
        rawMode: Bool = false
    ) -> [GestureEmission] {
        if rawMode {
            return tickRaw(at: timestamp, profile: profile)
        }

        var output: [GestureEmission] = []
        let settings = profile.settings

        if let pending = pendingPress,
           let deadline = pending.deadline,
           timestamp >= deadline {
            output.append(emission(for: pending, gesture: .press, timestamp: deadline))
            if activeChord == pending.inputs {
                activePressEmittedChord = pending.inputs
            }
            pendingPress = nil
        }

        guard !activeChord.isEmpty, let primary = activePrimary else { return output }

        if !activeHoldEmitted,
           timestamp - activeChordStartedAt >= settings.holdDelay,
           profile.hasBinding(inputs: activeChord, gesture: .hold, pointerMode: pointerMode) {
            activeHoldEmitted = true
            output.append(GestureEmission(
                inputs: activeChord,
                primaryInput: primary,
                gesture: .hold,
                timestamp: timestamp
            ))
        }

        if timestamp >= activeNextRepeatAt {
            activeNextRepeatAt = timestamp + settings.repeatRate
            let hasExplicitRepeat = profile.hasBinding(
                inputs: activeChord,
                gesture: .repeatPress,
                pointerMode: pointerMode
            )
            let mayRepeatPress = activePressEmittedChord == activeChord && profile.hasBinding(
                inputs: activeChord,
                gesture: .press,
                pointerMode: pointerMode
            )
            if hasExplicitRepeat || mayRepeatPress {
                output.append(GestureEmission(
                    inputs: activeChord,
                    primaryInput: primary,
                    gesture: .repeatPress,
                    timestamp: timestamp
                ))
            }
        }

        return output
    }

    public mutating func reset() {
        rawStates.removeAll()
        pressedAt.removeAll()
        pendingPress = nil
        lastReleasedChord = nil
        lastReleaseAt = nil
        clearActiveChord()
    }

    private mutating func beginActiveChord(
        _ chord: Set<XboxInput>,
        primaryInput: XboxInput,
        timestamp: TimeInterval,
        settings: ControllerSettings
    ) {
        activeChord = chord
        activePrimary = primaryInput
        activeChordStartedAt = timestamp
        activeNextRepeatAt = timestamp + settings.repeatDelay
        activeHoldEmitted = false
        activePressEmittedChord = nil
    }

    private mutating func clearActiveChord() {
        activeChord.removeAll()
        activePrimary = nil
        activeChordStartedAt = 0
        activeNextRepeatAt = 0
        activeHoldEmitted = false
        activePressEmittedChord = nil
    }

    private func emission(
        for pending: PendingPress,
        gesture: BindingGesture,
        timestamp: TimeInterval
    ) -> GestureEmission {
        GestureEmission(
            inputs: pending.inputs,
            primaryInput: pending.primaryInput,
            gesture: gesture,
            timestamp: timestamp
        )
    }

    // Helper UI and the on-screen controller keyboard need immediate raw
    // per-control events rather than user profile chord disambiguation.
    private mutating func ingestRaw(
        _ event: ControllerEvent,
        profile: ControllerProfile
    ) -> [GestureEmission] {
        var state = rawStates[event.input] ?? RawState()
        var output: [GestureEmission] = []
        let settings = profile.settings
        let supportsDouble = profile.hasBinding(input: event.input, gesture: .doublePress)

        if event.isPressed && !state.isPressed {
            state.isPressed = true
            state.pressedAt = event.timestamp
            state.nextRepeatAt = event.timestamp + settings.repeatDelay
            state.holdEmitted = false

            if supportsDouble,
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
            output.append(GestureEmission(input: event.input, gesture: .release, timestamp: event.timestamp))
        }

        rawStates[event.input] = state
        return output
    }

    private mutating func tickRaw(
        at timestamp: TimeInterval,
        profile: ControllerProfile
    ) -> [GestureEmission] {
        var output: [GestureEmission] = []
        let settings = profile.settings

        for input in rawStates.keys {
            guard var state = rawStates[input] else { continue }
            if let deadline = state.pendingSingleDeadline, timestamp >= deadline {
                state.pendingSingleDeadline = nil
                output.append(GestureEmission(input: input, gesture: .press, timestamp: deadline))
            }
            if state.isPressed {
                if !state.holdEmitted, timestamp - state.pressedAt >= settings.holdDelay {
                    state.holdEmitted = true
                    output.append(GestureEmission(input: input, gesture: .hold, timestamp: timestamp))
                }
                if timestamp >= state.nextRepeatAt {
                    state.nextRepeatAt = timestamp + settings.repeatRate
                    output.append(GestureEmission(input: input, gesture: .repeatPress, timestamp: timestamp))
                }
            }
            rawStates[input] = state
        }
        return output
    }
}

public struct BindingResolver: Sendable {
    public init() {}

    /// Legacy helper used only by old UI code. Runtime routing uses exact input sets.
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

        let exact = BindingKey(
            inputs: emission.inputs,
            pointerMode: pointerMode,
            gesture: emission.gesture
        )
        if let action = profile.action(for: exact) { return action }

        if emission.gesture == .repeatPress {
            let press = BindingKey(
                inputs: emission.inputs,
                pointerMode: pointerMode,
                gesture: .press
            )
            if let action = profile.action(for: press) { return action }
        }

        // Exact set matching only. No layer or subset fallback is permitted.
        return nil
    }
}
