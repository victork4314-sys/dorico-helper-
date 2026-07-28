import Foundation

public enum XboxInput: String, Codable, CaseIterable, Sendable {
    case buttonA, buttonB, buttonX, buttonY
    case dpadUp, dpadDown, dpadLeft, dpadRight
    case leftBumper, rightBumper, leftTrigger, rightTrigger
    case leftThumbstickButton, rightThumbstickButton
    case menu, view, guide
    case leftStickUp, leftStickDown, leftStickLeft, leftStickRight
    case rightStickUp, rightStickDown, rightStickLeft, rightStickRight

    public var displayName: String {
        switch self {
        case .buttonA: "A"
        case .buttonB: "B"
        case .buttonX: "X"
        case .buttonY: "Y"
        case .dpadUp: "D-pad Up"
        case .dpadDown: "D-pad Down"
        case .dpadLeft: "D-pad Left"
        case .dpadRight: "D-pad Right"
        case .leftBumper: "LB"
        case .rightBumper: "RB"
        case .leftTrigger: "LT"
        case .rightTrigger: "RT"
        case .leftThumbstickButton: "Left Stick Click"
        case .rightThumbstickButton: "Right Stick Click"
        case .menu: "Menu"
        case .view: "View"
        case .guide: "Xbox / Guide"
        case .leftStickUp: "Left Stick Up"
        case .leftStickDown: "Left Stick Down"
        case .leftStickLeft: "Left Stick Left"
        case .leftStickRight: "Left Stick Right"
        case .rightStickUp: "Right Stick Up"
        case .rightStickDown: "Right Stick Down"
        case .rightStickLeft: "Right Stick Left"
        case .rightStickRight: "Right Stick Right"
        }
    }
}

public enum BindingGesture: String, Codable, CaseIterable, Sendable {
    case press
    case release
    case hold
    case doublePress
    case repeatPress

    public var displayName: String {
        switch self {
        case .press: "Press"
        case .release: "Release"
        case .hold: "Hold"
        case .doublePress: "Double-press"
        case .repeatPress: "Repeat while held"
        }
    }
}

public enum MappingLayer: String, Codable, CaseIterable, Sendable {
    case base
    case leftTrigger
    case rightTrigger
    case bothTriggers
    case leftBumper
    case rightBumper
    case bothBumpers
    case pointer

    public var displayName: String {
        switch self {
        case .base: "Base"
        case .leftTrigger: "Hold LT"
        case .rightTrigger: "Hold RT"
        case .bothTriggers: "Hold LT + RT"
        case .leftBumper: "Hold LB"
        case .rightBumper: "Hold RB"
        case .bothBumpers: "Hold LB + RB"
        case .pointer: "Pointer mode"
        }
    }
}

public struct BindingKey: Hashable, Codable, Sendable {
    public var layer: MappingLayer
    public var input: XboxInput
    public var gesture: BindingGesture

    public init(layer: MappingLayer, input: XboxInput, gesture: BindingGesture = .press) {
        self.layer = layer
        self.input = input
        self.gesture = gesture
    }
}

public enum KeyModifier: String, Codable, CaseIterable, Hashable, Sendable {
    case command
    case shift
    case option
    case control
    case function
}

public struct KeyChord: Codable, Hashable, Sendable {
    public var key: String
    public var modifiers: Set<KeyModifier>

    public init(_ key: String, modifiers: Set<KeyModifier> = []) {
        self.key = key.lowercased()
        self.modifiers = modifiers
    }

    public var displayName: String {
        let order: [KeyModifier] = [.control, .option, .shift, .command, .function]
        let prefix = order.filter(modifiers.contains).map { modifier in
            switch modifier {
            case .command: "Cmd"
            case .shift: "Shift"
            case .option: "Opt"
            case .control: "Ctrl"
            case .function: "Fn"
            }
        }
        return (prefix + [key.capitalized]).joined(separator: "-")
    }
}

public struct MIDIAddress: Codable, Hashable, Sendable {
    public var channel: UInt8
    public var note: UInt8

    public init(channel: UInt8, note: UInt8) {
        self.channel = min(16, max(1, channel))
        self.note = min(127, note)
    }

    public static func address(for index: Int) -> MIDIAddress {
        let safe = max(0, index)
        return MIDIAddress(channel: UInt8((safe / 128) % 16 + 1), note: UInt8(safe % 128))
    }
}

public enum FocusDirection: String, Codable, Sendable {
    case up, down, left, right
}

public enum AccessibilityOperation: Codable, Hashable, Sendable {
    case move(FocusDirection)
    case pressFocused
    case incrementFocused
    case decrementFocused
    case showFocusedMenu
    case scanNext
    case scanPrevious
}

public enum PointerOperation: Codable, Hashable, Sendable {
    case move(dx: Double, dy: Double)
    case scroll(dx: Double, dy: Double)
    case leftClick
    case rightClick
    case doubleClick
    case toggle
}

public enum DoricoTextRoute: String, Codable, CaseIterable, Hashable, Sendable {
    case focusedField
    case jumpBarCommands
    case jumpBarGoTo
    case dynamicsPopover
    case ornamentsPopover
    case meterPopover
    case keySignaturePopover
    case tempoPopover
    case clefPopover
    case playingTechniquesPopover
    case barsAndBarlinesPopover

    public var displayName: String {
        switch self {
        case .focusedField: "Focused Dorico field or open popover"
        case .jumpBarCommands: "Jump Bar Commands"
        case .jumpBarGoTo: "Jump Bar Go To"
        case .dynamicsPopover: "Dynamics popover"
        case .ornamentsPopover: "Ornaments popover"
        case .meterPopover: "Time signature popover"
        case .keySignaturePopover: "Key signature popover"
        case .tempoPopover: "Tempo popover"
        case .clefPopover: "Clef popover"
        case .playingTechniquesPopover: "Playing techniques popover"
        case .barsAndBarlinesPopover: "Bars and barlines popover"
        }
    }
}

public enum BridgeInternalCommand: String, Codable, Hashable, Sendable {
    case showDashboard
    case hideDashboard
    case toggleDashboard
    case helperUp
    case helperDown
    case helperLeft
    case helperRight
    case helperDecrease
    case helperIncrease
    case helperActivate
    case helperBack
    case toggleBridge
    case nextProfile
    case previousProfile
    case speakContext
}

public struct CommandStep: Codable, Hashable, Sendable {
    public var action: CommandAction
    public var delayMilliseconds: UInt64

    public init(_ action: CommandAction, delayMilliseconds: UInt64 = 0) {
        self.action = action
        self.delayMilliseconds = delayMilliseconds
    }
}

public indirect enum CommandAction: Codable, Hashable, Sendable {
    case keyChord(KeyChord)
    case typeText(String)
    case controllerText(DoricoTextRoute)
    case midiPulse(MIDIAddress)
    case menuPath([String])
    case accessibility(AccessibilityOperation)
    case pointer(PointerOperation)
    case sequence([CommandStep])
    case internalCommand(BridgeInternalCommand)
    case none

    public var summary: String {
        switch self {
        case .keyChord(let chord): chord.displayName
        case .typeText(let text): "Type “\(text)”"
        case .controllerText(let route): "Xbox keyboard: \(route.displayName)"
        case .midiPulse(let address): "MIDI ch \(address.channel), note \(address.note)"
        case .menuPath(let path): path.joined(separator: " › ")
        case .accessibility(let operation): "Accessibility: \(String(describing: operation))"
        case .pointer(let operation): "Pointer: \(String(describing: operation))"
        case .sequence(let steps): "Macro (\(steps.count) steps)"
        case .internalCommand(let command): "Bridge: \(command.rawValue)"
        case .none: "None"
        }
    }
}

public struct ActionDescriptor: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var category: String
    public var detail: String
    public var action: CommandAction
    public var repeatable: Bool

    public init(
        id: String,
        title: String,
        category: String,
        detail: String,
        action: CommandAction,
        repeatable: Bool = false
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.detail = detail
        self.action = action
        self.repeatable = repeatable
    }
}

public struct ControllerSettings: Codable, Hashable, Sendable {
    public var stickDeadzone: Float
    public var triggerThreshold: Float
    public var repeatDelay: TimeInterval
    public var repeatRate: TimeInterval
    public var holdDelay: TimeInterval
    public var doublePressWindow: TimeInterval
    public var pointerSpeed: Double
    public var hapticsEnabled: Bool
    public var onlyWhenDoricoFrontmost: Bool

    public init(
        stickDeadzone: Float = 0.34,
        triggerThreshold: Float = 0.55,
        repeatDelay: TimeInterval = 0.38,
        repeatRate: TimeInterval = 0.085,
        holdDelay: TimeInterval = 0.48,
        doublePressWindow: TimeInterval = 0.25,
        pointerSpeed: Double = 18,
        hapticsEnabled: Bool = true,
        onlyWhenDoricoFrontmost: Bool = true
    ) {
        self.stickDeadzone = stickDeadzone
        self.triggerThreshold = triggerThreshold
        self.repeatDelay = repeatDelay
        self.repeatRate = repeatRate
        self.holdDelay = holdDelay
        self.doublePressWindow = doublePressWindow
        self.pointerSpeed = pointerSpeed
        self.hapticsEnabled = hapticsEnabled
        self.onlyWhenDoricoFrontmost = onlyWhenDoricoFrontmost
    }
}

public struct ControllerProfile: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var bindings: [BindingKey: CommandAction]
    public var settings: ControllerSettings

    public init(
        id: UUID = UUID(),
        name: String,
        bindings: [BindingKey: CommandAction],
        settings: ControllerSettings = ControllerSettings()
    ) {
        self.id = id
        self.name = name
        self.bindings = bindings
        self.settings = settings
    }

    public func action(for key: BindingKey) -> CommandAction? {
        bindings[key]
    }

    public func hasBinding(input: XboxInput, gesture: BindingGesture) -> Bool {
        bindings.keys.contains { $0.input == input && $0.gesture == gesture }
    }
}

public struct ControllerEvent: Sendable {
    public var input: XboxInput
    public var isPressed: Bool
    public var value: Float
    public var timestamp: TimeInterval

    public init(input: XboxInput, isPressed: Bool, value: Float = 1, timestamp: TimeInterval) {
        self.input = input
        self.isPressed = isPressed
        self.value = value
        self.timestamp = timestamp
    }
}

public struct GestureEmission: Equatable, Sendable {
    public var input: XboxInput
    public var gesture: BindingGesture
    public var timestamp: TimeInterval

    public init(input: XboxInput, gesture: BindingGesture, timestamp: TimeInterval) {
        self.input = input
        self.gesture = gesture
        self.timestamp = timestamp
    }
}
