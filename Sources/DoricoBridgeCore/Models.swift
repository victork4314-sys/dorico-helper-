import Foundation

public enum XboxInput: String, Codable, CaseIterable, Hashable, Sendable {
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

public enum BindingGesture: String, Codable, CaseIterable, Hashable, Sendable {
    case press, release, hold, doublePress, repeatPress

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

/// Retained for old profile migration and the normal/pointer context selector.
/// New mappings use exact arbitrary input sets and are not restricted to these layers.
public enum MappingLayer: String, Codable, CaseIterable, Hashable, Sendable {
    case base, leftTrigger, rightTrigger, bothTriggers
    case leftBumper, rightBumper, bothBumpers, pointer

    public var displayName: String {
        switch self {
        case .base: "Normal context"
        case .leftTrigger: "Legacy: Hold LT"
        case .rightTrigger: "Legacy: Hold RT"
        case .bothTriggers: "Legacy: Hold LT + RT"
        case .leftBumper: "Legacy: Hold LB"
        case .rightBumper: "Legacy: Hold RB"
        case .bothBumpers: "Legacy: Hold LB + RB"
        case .pointer: "Pointer mode"
        }
    }

    public var modifierInputs: Set<XboxInput> {
        switch self {
        case .base, .pointer: []
        case .leftTrigger: [.leftTrigger]
        case .rightTrigger: [.rightTrigger]
        case .bothTriggers: [.leftTrigger, .rightTrigger]
        case .leftBumper: [.leftBumper]
        case .rightBumper: [.rightBumper]
        case .bothBumpers: [.leftBumper, .rightBumper]
        }
    }

    public static let userSelectableCases: [MappingLayer] = [.base, .pointer]
}

/// An exact unordered set of controller inputs. Extra held controls are a different binding.
public struct BindingKey: Hashable, Codable, Sendable {
    public var inputs: Set<XboxInput>
    public var pointerMode: Bool
    public var gesture: BindingGesture

    public init(inputs: Set<XboxInput>, pointerMode: Bool = false, gesture: BindingGesture = .press) {
        precondition(!inputs.isEmpty, "A controller mapping must contain at least one input")
        self.inputs = inputs
        self.pointerMode = pointerMode
        self.gesture = gesture
    }

    /// Migrates all old layer/input call sites into a real exact input set.
    public init(layer: MappingLayer, input: XboxInput, gesture: BindingGesture = .press) {
        self.inputs = layer.modifierInputs.union([input])
        self.pointerMode = layer == .pointer
        self.gesture = gesture
    }

    public var orderedInputs: [XboxInput] { XboxInput.allCases.filter(inputs.contains) }

    public var displayName: String {
        let controls = orderedInputs.map(\.displayName).joined(separator: " + ")
        return pointerMode ? "Pointer mode · \(controls)" : controls
    }

    public var stableID: String {
        let controls = orderedInputs.map(\.rawValue).joined(separator: "+")
        return "\(pointerMode ? "pointer" : "normal").\(controls).\(gesture.rawValue)"
    }

    /// Compatibility only for old UI and tests.
    public var layer: MappingLayer {
        if pointerMode { return .pointer }
        if inputs.contains(.leftTrigger), inputs.contains(.rightTrigger) { return .bothTriggers }
        if inputs.contains(.leftBumper), inputs.contains(.rightBumper) { return .bothBumpers }
        if inputs.contains(.leftTrigger) { return .leftTrigger }
        if inputs.contains(.rightTrigger) { return .rightTrigger }
        if inputs.contains(.leftBumper) { return .leftBumper }
        if inputs.contains(.rightBumper) { return .rightBumper }
        return .base
    }

    /// Compatibility only. Returns a deterministic representative input.
    public var input: XboxInput {
        let modifiers = layer.modifierInputs
        return orderedInputs.first(where: { !modifiers.contains($0) }) ?? orderedInputs.last ?? .buttonA
    }

    private enum CodingKeys: String, CodingKey { case inputs, pointerMode, gesture, layer, input }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let gesture = try container.decodeIfPresent(BindingGesture.self, forKey: .gesture) ?? .press
        if let decodedInputs = try container.decodeIfPresent(Set<XboxInput>.self, forKey: .inputs), !decodedInputs.isEmpty {
            inputs = decodedInputs
            pointerMode = try container.decodeIfPresent(Bool.self, forKey: .pointerMode) ?? false
            self.gesture = gesture
            return
        }
        let oldLayer = try container.decodeIfPresent(MappingLayer.self, forKey: .layer) ?? .base
        let oldInput = try container.decode(XboxInput.self, forKey: .input)
        self.init(layer: oldLayer, input: oldInput, gesture: gesture)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(inputs, forKey: .inputs)
        try container.encode(pointerMode, forKey: .pointerMode)
        try container.encode(gesture, forKey: .gesture)
    }
}

public enum KeyModifier: String, Codable, CaseIterable, Hashable, Sendable {
    case command, shift, option, control, function, capsLock

    public var symbol: String {
        switch self {
        case .command: "⌘"
        case .shift: "⇧"
        case .option: "⌥"
        case .control: "⌃"
        case .function: "fn"
        case .capsLock: "⇪"
        }
    }

    public var displayName: String {
        switch self {
        case .command: "Command"
        case .shift: "Shift"
        case .option: "Option"
        case .control: "Control"
        case .function: "Fn / Globe"
        case .capsLock: "Caps Lock"
        }
    }
}

/// A keyboard shortcut. Captured shortcuts preserve the physical macOS key code so every
/// punctuation mark, symbol, function key, localized key, and modifier combination can replay.
public struct KeyChord: Codable, Hashable, Sendable {
    public var key: String
    public var modifiers: Set<KeyModifier>
    public var virtualKeyCode: UInt16?
    public var capturedCharacters: String?

    public init(_ key: String, modifiers: Set<KeyModifier> = []) {
        self.key = key.lowercased()
        self.modifiers = modifiers
        virtualKeyCode = nil
        capturedCharacters = nil
    }

    public init(capturedKeyCode: UInt16, characters: String, modifiers: Set<KeyModifier>) {
        key = characters
        self.modifiers = modifiers
        virtualKeyCode = capturedKeyCode
        capturedCharacters = characters
    }

    public init(modifiersOnly: Set<KeyModifier>) {
        key = ""
        modifiers = modifiersOnly
        virtualKeyCode = nil
        capturedCharacters = nil
    }

    public var isModifierOnly: Bool { key.isEmpty && virtualKeyCode == nil && !modifiers.isEmpty }

    public var displayName: String {
        let order: [KeyModifier] = [.control, .option, .shift, .command, .function, .capsLock]
        let prefixes = order.filter(modifiers.contains).map(\.symbol)
        let base = capturedCharacters?.isEmpty == false ? capturedCharacters! : legacyDisplayName(for: key)
        return (prefixes + (base.isEmpty ? [] : [base])).joined(separator: " + ")
    }

    private func legacyDisplayName(for key: String) -> String {
        switch key.lowercased() {
        case "return", "enter": "Return"
        case "escape", "esc": "Escape"
        case "delete", "backspace": "Delete"
        case "forwarddelete": "Forward Delete"
        case "space": "Space"
        case "tab": "Tab"
        case "left": "←"
        case "right": "→"
        case "up": "↑"
        case "down": "↓"
        case "pageup": "Page Up"
        case "pagedown": "Page Down"
        default: key.isEmpty ? "" : key.uppercased()
        }
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

    public static func noteName(for note: UInt8) -> String {
        let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
        let value = Int(note)
        return "\(names[value % 12])\(value / 12 - 1)"
    }

    public var noteName: String { Self.noteName(for: note) }
    public var displayName: String { "\(noteName) · Channel \(channel)" }
}

public enum FocusDirection: String, Codable, Sendable { case up, down, left, right }

public enum AccessibilityOperation: Codable, Hashable, Sendable {
    case move(FocusDirection)
    case pressFocused, incrementFocused, decrementFocused, showFocusedMenu
    case scanNext, scanPrevious
}

public enum PointerOperation: Codable, Hashable, Sendable {
    case move(dx: Double, dy: Double)
    case scroll(dx: Double, dy: Double)
    case leftClick, rightClick, doubleClick, toggle
}

public enum DoricoTextRoute: String, Codable, CaseIterable, Hashable, Sendable {
    case focusedField, jumpBarCommands, jumpBarGoTo
    case dynamicsPopover, ornamentsPopover, meterPopover, keySignaturePopover
    case tempoPopover, clefPopover, playingTechniquesPopover, barsAndBarlinesPopover

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
    case showDashboard, hideDashboard, toggleDashboard
    case helperUp, helperDown, helperLeft, helperRight
    case helperDecrease, helperIncrease, helperActivate, helperBack
    case toggleBridge, nextProfile, previousProfile, speakContext
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
        case .midiPulse(let address): "MIDI \(address.displayName)"
        case .menuPath(let path): path.joined(separator: " › ")
        case .accessibility(let operation): "Accessibility: \(String(describing: operation))"
        case .pointer(let operation): "Pointer: \(String(describing: operation))"
        case .sequence(let steps): "Sequence (\(steps.count) actions)"
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

    public init(id: String, title: String, category: String, detail: String, action: CommandAction, repeatable: Bool = false) {
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

    public init(id: UUID = UUID(), name: String, bindings: [BindingKey: CommandAction], settings: ControllerSettings = ControllerSettings()) {
        self.id = id
        self.name = name
        self.bindings = bindings
        self.settings = settings
    }

    public func action(for key: BindingKey) -> CommandAction? { bindings[key] }

    public func action(for inputs: Set<XboxInput>, gesture: BindingGesture, pointerMode: Bool) -> CommandAction? {
        bindings[BindingKey(inputs: inputs, pointerMode: pointerMode, gesture: gesture)]
    }

    public func hasBinding(inputs: Set<XboxInput>, gesture: BindingGesture, pointerMode: Bool) -> Bool {
        action(for: inputs, gesture: gesture, pointerMode: pointerMode) != nil
    }

    public func hasStrictSuperset(of inputs: Set<XboxInput>, pointerMode: Bool, gesture: BindingGesture? = nil) -> Bool {
        bindings.keys.contains { key in
            key.pointerMode == pointerMode &&
            (gesture == nil || key.gesture == gesture) &&
            inputs.isStrictSubset(of: key.inputs)
        }
    }

    public func hasBinding(input: XboxInput, gesture: BindingGesture) -> Bool {
        bindings.keys.contains { $0.inputs == [input] && !$0.pointerMode && $0.gesture == gesture }
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
    public var inputs: Set<XboxInput>
    public var primaryInput: XboxInput
    public var gesture: BindingGesture
    public var timestamp: TimeInterval

    public var input: XboxInput { primaryInput }

    public init(inputs: Set<XboxInput>, primaryInput: XboxInput, gesture: BindingGesture, timestamp: TimeInterval) {
        precondition(!inputs.isEmpty, "A gesture emission must contain at least one input")
        self.inputs = inputs
        self.primaryInput = primaryInput
        self.gesture = gesture
        self.timestamp = timestamp
    }

    public init(input: XboxInput, gesture: BindingGesture, timestamp: TimeInterval) {
        self.init(inputs: [input], primaryInput: input, gesture: gesture, timestamp: timestamp)
    }
}
