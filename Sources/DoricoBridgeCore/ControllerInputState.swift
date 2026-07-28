import Foundation

/// One deduplicating gate shared by every physical-controller input path.
/// Callback delivery is the primary path and direct polling is the backup path;
/// both must pass through this state before the app receives a ControllerEvent.
public struct ControllerInputState: Sendable {
    private var states: [XboxInput: Bool] = [:]

    public init() {}

    public mutating func eventIfChanged(
        input: XboxInput,
        pressed: Bool,
        value: Float,
        timestamp: TimeInterval
    ) -> ControllerEvent? {
        if states[input] == nil {
            states[input] = pressed
            // Establishing an initial released state must not manufacture a
            // release event at startup. An initially held control is real input.
            guard pressed else { return nil }
            return ControllerEvent(input: input, isPressed: true, value: value, timestamp: timestamp)
        }
        guard states[input] != pressed else { return nil }
        states[input] = pressed
        return ControllerEvent(input: input, isPressed: pressed, value: value, timestamp: timestamp)
    }

    public mutating func reset() {
        states.removeAll()
    }

    public func isPressed(_ input: XboxInput) -> Bool {
        states[input] ?? false
    }

    public var pressedInputs: Set<XboxInput> {
        Set(states.compactMap { input, pressed in pressed ? input : nil })
    }
}
