import Foundation

public enum DefaultCatalog {
    public static let actions: [ActionDescriptor] = {
        var list: [ActionDescriptor] = []
        func add(_ id: String, _ title: String, _ category: String, _ detail: String, _ action: CommandAction, repeatable: Bool = false) {
            list.append(ActionDescriptor(id: id, title: title, category: category, detail: detail, action: action, repeatable: repeatable))
        }

        add("navigate.left", "Move selection left", "Navigation", "Dorico selection navigation", .keyChord(KeyChord("left")), repeatable: true)
        add("navigate.right", "Move selection right", "Navigation", "Dorico selection navigation", .keyChord(KeyChord("right")), repeatable: true)
        add("navigate.up", "Move selection up", "Navigation", "Dorico selection navigation", .keyChord(KeyChord("up")), repeatable: true)
        add("navigate.down", "Move selection down", "Navigation", "Dorico selection navigation", .keyChord(KeyChord("down")), repeatable: true)
        add("activate", "Activate / Return", "Navigation", "Activate the current control or start note input when appropriate", .keyChord(KeyChord("return")))
        add("cancel", "Cancel / Escape", "Navigation", "Close the current popover, dialog, or selection state", .keyChord(KeyChord("escape")))
        add("delete", "Delete", "Edit", "Delete the current selection", .keyChord(KeyChord("delete")))
        add("play", "Play / Stop", "Playback", "Toggle playback", .keyChord(KeyChord("space")))
        add("undo", "Undo", "Edit", "Undo", .keyChord(KeyChord("z", modifiers: [.command])))
        add("redo", "Redo", "Edit", "Redo", .keyChord(KeyChord("z", modifiers: [.command, .shift])))
        add("copy", "Copy", "Edit", "Copy selection", .keyChord(KeyChord("c", modifiers: [.command])))
        add("cut", "Cut", "Edit", "Cut selection", .keyChord(KeyChord("x", modifiers: [.command])))
        add("paste", "Paste", "Edit", "Paste", .keyChord(KeyChord("v", modifiers: [.command])))
        add("select.all", "Select all", "Edit", "Select all", .keyChord(KeyChord("a", modifiers: [.command])))
        add("note.input", "Start note input", "Write", "Default Dorico Pro command Shift-N", .keyChord(KeyChord("n", modifiers: [.shift])))
        add("duration.16", "16th note", "Durations", "Default Dorico duration key 4", .keyChord(KeyChord("4")))
        add("duration.8", "Eighth note", "Durations", "Default Dorico duration key 5", .keyChord(KeyChord("5")))
        add("duration.4", "Quarter note", "Durations", "Default Dorico duration key 6", .keyChord(KeyChord("6")))
        add("duration.2", "Half note", "Durations", "Default Dorico duration key 7", .keyChord(KeyChord("7")))
        add("duration.1", "Whole note", "Durations", "Default Dorico duration key 8", .keyChord(KeyChord("8")))
        add("duration.dot", "Rhythm dot", "Durations", "Add a rhythm dot", .keyChord(KeyChord("period")))

        add("popover.dynamics", "Open dynamics popover", "Popovers", "Default Dorico Pro command Shift-D", .keyChord(KeyChord("d", modifiers: [.shift])))
        add("popover.ornaments", "Open ornaments popover", "Popovers", "Default Dorico Pro command Shift-O", .keyChord(KeyChord("o", modifiers: [.shift])))
        add("popover.meter", "Open time signature popover", "Popovers", "Default Dorico Pro command Shift-M", .keyChord(KeyChord("m", modifiers: [.shift])))
        add("popover.key", "Open key signature popover", "Popovers", "Default Dorico Pro command Shift-K", .keyChord(KeyChord("k", modifiers: [.shift])))
        add("popover.tempo", "Open tempo popover", "Popovers", "Default Dorico Pro command Shift-T", .keyChord(KeyChord("t", modifiers: [.shift])))
        add("popover.clef", "Open clef popover", "Popovers", "Default Dorico Pro command Shift-C", .keyChord(KeyChord("c", modifiers: [.shift])))
        add("popover.playing", "Open playing techniques popover", "Popovers", "Default Dorico Pro command Shift-P", .keyChord(KeyChord("p", modifiers: [.shift])))
        add("popover.bars", "Open bars and barlines popover", "Popovers", "Default Dorico Pro command Shift-B", .keyChord(KeyChord("b", modifiers: [.shift])))

        add("xbox.text.focused", "Xbox keyboard for focused Dorico field", "Xbox text entry", "Type into the currently focused Dorico field or an already-open popover", .controllerText(.focusedField))
        add("xbox.jump.commands", "Xbox keyboard for Jump Bar Commands", "Xbox text entry", "Open J, switch to Commands with Ctrl-1, type, and execute", .controllerText(.jumpBarCommands))
        add("xbox.jump.goto", "Xbox keyboard for Jump Bar Go To", "Xbox text entry", "Open J, switch to Go To with Ctrl-2, type, and execute", .controllerText(.jumpBarGoTo))
        add("xbox.popover.dynamics", "Xbox keyboard for dynamics", "Xbox text entry", "Enter and confirm a Dynamics popover instruction", .controllerText(.dynamicsPopover))
        add("xbox.popover.ornaments", "Xbox keyboard for ornaments", "Xbox text entry", "Enter and confirm an Ornaments popover instruction", .controllerText(.ornamentsPopover))
        add("xbox.popover.meter", "Xbox keyboard for time signatures", "Xbox text entry", "Enter and confirm a Time Signatures popover instruction", .controllerText(.meterPopover))
        add("xbox.popover.key", "Xbox keyboard for key signatures", "Xbox text entry", "Enter and confirm a Key Signatures popover instruction", .controllerText(.keySignaturePopover))
        add("xbox.popover.tempo", "Xbox keyboard for tempo", "Xbox text entry", "Enter and confirm a Tempo popover instruction", .controllerText(.tempoPopover))
        add("xbox.popover.clef", "Xbox keyboard for clefs", "Xbox text entry", "Enter and confirm a Clefs popover instruction", .controllerText(.clefPopover))
        add("xbox.popover.playing", "Xbox keyboard for playing techniques", "Xbox text entry", "Enter and confirm a Playing Techniques popover instruction", .controllerText(.playingTechniquesPopover))
        add("xbox.popover.bars", "Xbox keyboard for bars and barlines", "Xbox text entry", "Enter and confirm a Bars and Barlines popover instruction", .controllerText(.barsAndBarlinesPopover))

        add("access.focus.left", "Accessibility focus left", "Universal access", "Move to the nearest accessible Dorico control on the left", .accessibility(.move(.left)), repeatable: true)
        add("access.focus.right", "Accessibility focus right", "Universal access", "Move to the nearest accessible Dorico control on the right", .accessibility(.move(.right)), repeatable: true)
        add("access.focus.up", "Accessibility focus up", "Universal access", "Move to the nearest accessible Dorico control above", .accessibility(.move(.up)), repeatable: true)
        add("access.focus.down", "Accessibility focus down", "Universal access", "Move to the nearest accessible Dorico control below", .accessibility(.move(.down)), repeatable: true)
        add("access.press", "Press accessible control", "Universal access", "Press the currently focused Dorico control", .accessibility(.pressFocused))
        add("access.increment", "Increase accessible value", "Universal access", "Increase the focused slider, stepper, or adjustable value", .accessibility(.incrementFocused), repeatable: true)
        add("access.decrement", "Decrease accessible value", "Universal access", "Decrease the focused slider, stepper, or adjustable value", .accessibility(.decrementFocused), repeatable: true)
        add("access.menu", "Show focused control menu", "Universal access", "Open the menu for the currently focused Dorico control", .accessibility(.showFocusedMenu))
        add("access.scan.next", "Scan next Dorico control", "Universal access", "Move through all accessible controls in stable reading order", .accessibility(.scanNext), repeatable: true)
        add("access.scan.previous", "Scan previous Dorico control", "Universal access", "Move backward through all accessible controls", .accessibility(.scanPrevious), repeatable: true)

        add("pointer.toggle", "Toggle pointer mode", "Pointer", "Toggle Xbox pointer mode", .pointer(.toggle))
        add("pointer.click", "Pointer click", "Pointer", "Left-click at the Xbox pointer", .pointer(.leftClick))
        add("pointer.double", "Pointer double-click", "Pointer", "Double-click at the Xbox pointer", .pointer(.doubleClick))
        add("pointer.right", "Pointer right-click", "Pointer", "Right-click at the Xbox pointer", .pointer(.rightClick))
        add("pointer.scroll.up", "Pointer scroll up", "Pointer", "Scroll upward", .pointer(.scroll(dx: 0, dy: 4)), repeatable: true)
        add("pointer.scroll.down", "Pointer scroll down", "Pointer", "Scroll downward", .pointer(.scroll(dx: 0, dy: -4)), repeatable: true)
        add("pointer.scroll.left", "Pointer scroll left", "Pointer", "Scroll left", .pointer(.scroll(dx: -4, dy: 0)), repeatable: true)
        add("pointer.scroll.right", "Pointer scroll right", "Pointer", "Scroll right", .pointer(.scroll(dx: 4, dy: 0)), repeatable: true)
        add("bridge.dashboard", "Show bridge dashboard", "Bridge", "Open the controller dashboard", .internalCommand(.toggleDashboard))

        for index in 0..<512 {
            let address = MIDIAddress.address(for: index)
            add(
                "midi.slot.\(index + 1)",
                "MIDI Learn slot \(index + 1)",
                "Dorico MIDI Learn",
                "Virtual MIDI channel \(address.channel), note \(address.note)",
                .midiPulse(address)
            )
        }
        return list
    }()

    public static let actionByID: [String: ActionDescriptor] = Dictionary(uniqueKeysWithValues: actions.map { ($0.id, $0) })

    public static func action(_ id: String) -> CommandAction {
        actionByID[id]?.action ?? .none
    }

    public static let legatoStyleProfile: ControllerProfile = {
        var bindings: [BindingKey: CommandAction] = [:]
        func bind(_ layer: MappingLayer = .base, _ input: XboxInput, _ actionID: String, _ gesture: BindingGesture = .press) {
            bindings[BindingKey(layer: layer, input: input, gesture: gesture)] = action(actionID)
        }

        bind(.base, .dpadLeft, "navigate.left")
        bind(.base, .dpadRight, "navigate.right")
        bind(.base, .dpadUp, "navigate.up")
        bind(.base, .dpadDown, "navigate.down")
        bind(.base, .leftStickLeft, "navigate.left")
        bind(.base, .leftStickRight, "navigate.right")
        bind(.base, .leftStickUp, "navigate.up")
        bind(.base, .leftStickDown, "navigate.down")
        bind(.base, .buttonA, "activate")
        bind(.base, .buttonB, "cancel")
        bind(.base, .buttonX, "delete")
        bind(.base, .buttonY, "note.input")
        bind(.base, .menu, "play")
        bind(.base, .view, "bridge.dashboard")
        bind(.base, .guide, "bridge.dashboard")
        bind(.base, .leftThumbstickButton, "undo")
        bind(.base, .rightThumbstickButton, "redo")
        bind(.base, .rightStickLeft, "access.focus.left")
        bind(.base, .rightStickRight, "access.focus.right")
        bind(.base, .rightStickUp, "access.focus.up")
        bind(.base, .rightStickDown, "access.focus.down")

        bind(.leftTrigger, .buttonA, "copy")
        bind(.leftTrigger, .buttonB, "cut")
        bind(.leftTrigger, .buttonX, "paste")
        bind(.leftTrigger, .buttonY, "select.all")
        bind(.leftTrigger, .dpadLeft, "navigate.left")
        bind(.leftTrigger, .dpadRight, "navigate.right")
        bind(.leftTrigger, .dpadUp, "navigate.up")
        bind(.leftTrigger, .dpadDown, "navigate.down")

        bind(.rightTrigger, .buttonB, "duration.16")
        bind(.rightTrigger, .buttonX, "duration.8")
        bind(.rightTrigger, .buttonA, "duration.4")
        bind(.rightTrigger, .buttonY, "duration.2")
        bind(.rightTrigger, .dpadUp, "duration.1")
        bind(.rightTrigger, .dpadRight, "duration.dot")

        bind(.bothTriggers, .buttonA, "xbox.popover.dynamics")
        bind(.bothTriggers, .buttonB, "xbox.popover.ornaments")
        bind(.bothTriggers, .buttonX, "xbox.popover.meter")
        bind(.bothTriggers, .buttonY, "xbox.popover.key")
        bind(.bothTriggers, .dpadUp, "xbox.popover.tempo")
        bind(.bothTriggers, .dpadDown, "xbox.popover.clef")
        bind(.bothTriggers, .dpadLeft, "xbox.popover.playing")
        bind(.bothTriggers, .dpadRight, "xbox.popover.bars")

        bind(.leftBumper, .buttonX, "xbox.jump.commands")
        bind(.leftBumper, .buttonY, "xbox.jump.goto")
        bind(.leftBumper, .buttonA, "xbox.text.focused")

        bind(.bothBumpers, .buttonA, "pointer.toggle")
        bind(.bothBumpers, .buttonB, "access.press")
        bind(.bothBumpers, .buttonX, "access.decrement")
        bind(.bothBumpers, .buttonY, "access.increment")
        bind(.bothBumpers, .dpadLeft, "access.scan.previous")
        bind(.bothBumpers, .dpadRight, "access.scan.next")
        bind(.bothBumpers, .dpadUp, "access.focus.up")
        bind(.bothBumpers, .dpadDown, "access.focus.down")
        bind(.bothBumpers, .menu, "access.menu")

        bindings[BindingKey(layer: .pointer, input: .leftStickLeft)] = .pointer(.move(dx: -18, dy: 0))
        bindings[BindingKey(layer: .pointer, input: .leftStickRight)] = .pointer(.move(dx: 18, dy: 0))
        bindings[BindingKey(layer: .pointer, input: .leftStickUp)] = .pointer(.move(dx: 0, dy: 18))
        bindings[BindingKey(layer: .pointer, input: .leftStickDown)] = .pointer(.move(dx: 0, dy: -18))
        bindings[BindingKey(layer: .pointer, input: .rightStickUp)] = .pointer(.scroll(dx: 0, dy: 4))
        bindings[BindingKey(layer: .pointer, input: .rightStickDown)] = .pointer(.scroll(dx: 0, dy: -4))
        bindings[BindingKey(layer: .pointer, input: .rightStickLeft)] = .pointer(.scroll(dx: -4, dy: 0))
        bindings[BindingKey(layer: .pointer, input: .rightStickRight)] = .pointer(.scroll(dx: 4, dy: 0))
        bindings[BindingKey(layer: .pointer, input: .buttonA)] = .pointer(.leftClick)
        bindings[BindingKey(layer: .pointer, input: .buttonY)] = .pointer(.doubleClick)
        bindings[BindingKey(layer: .pointer, input: .buttonX)] = .pointer(.rightClick)
        bindings[BindingKey(layer: .pointer, input: .buttonB)] = .pointer(.toggle)

        return ControllerProfile(name: "Dorico Pro — Legato style", bindings: bindings)
    }()
}
