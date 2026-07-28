import Foundation

public enum DefaultCatalog {
    public static let actions: [ActionDescriptor] = {
        var list: [ActionDescriptor] = []
        func add(_ id: String, _ title: String, _ category: String, _ detail: String, _ action: CommandAction, repeatable: Bool = false) {
            list.append(ActionDescriptor(id: id, title: title, category: category, detail: detail, action: action, repeatable: repeatable))
        }

        add("place.note", "Place selected note", "Simple actions", "Enter the selected named pitch at Dorico's note-input caret", .midiPulse(BridgeDynamicMIDI.placeSelectedNote))
        add("pitch.up", "Move note pitch up", "Simple actions", "Move the note-input caret and selected pitch up one diatonic step", .midiPulse(BridgeDynamicMIDI.pitchUp), repeatable: true)
        add("pitch.down", "Move note pitch down", "Simple actions", "Move the note-input caret and selected pitch down one diatonic step", .midiPulse(BridgeDynamicMIDI.pitchDown), repeatable: true)
        add("delete", "Delete selection", "Simple actions", "Delete the current Dorico note, object, or selection", .keyChord(KeyChord("delete")))
        add("activate", "Confirm / Return", "Simple actions", "Confirm the active Dorico popover, field, or dialog", .keyChord(KeyChord("return")))
        add("cancel", "Cancel / close", "Simple actions", "Close the active popover, dialog, or mode", .keyChord(KeyChord("escape")))
        add("note.input", "Start note input", "Simple actions", "Dorico Shift-N", .keyChord(KeyChord("n", modifiers: [.shift])))
        add("play", "Play / Stop", "Simple actions", "Toggle Dorico playback", .keyChord(KeyChord("space")))
        add("undo", "Undo", "Simple actions", "Undo the last change", .keyChord(KeyChord("z", modifiers: [.command])))
        add("redo", "Redo", "Simple actions", "Redo the last undone change", .keyChord(KeyChord("z", modifiers: [.command, .shift])))
        add("copy", "Copy", "Simple actions", "Copy the current selection", .keyChord(KeyChord("c", modifiers: [.command])))
        add("cut", "Cut", "Simple actions", "Cut the current selection", .keyChord(KeyChord("x", modifiers: [.command])))
        add("paste", "Paste", "Simple actions", "Paste", .keyChord(KeyChord("v", modifiers: [.command])))
        add("select.all", "Select all", "Simple actions", "Select all", .keyChord(KeyChord("a", modifiers: [.command])))

        add("navigate.left", "Move selection left", "Navigation", "Dorico selection navigation", .keyChord(KeyChord("left")), repeatable: true)
        add("navigate.right", "Move selection right", "Navigation", "Dorico selection navigation", .keyChord(KeyChord("right")), repeatable: true)
        add("navigate.up", "Move selection up", "Navigation", "Dorico selection navigation", .keyChord(KeyChord("up")), repeatable: true)
        add("navigate.down", "Move selection down", "Navigation", "Dorico selection navigation", .keyChord(KeyChord("down")), repeatable: true)
        add("select.left", "Extend selection left", "Selection", "Shift-Left", .keyChord(KeyChord("left", modifiers: [.shift])), repeatable: true)
        add("select.right", "Extend selection right", "Selection", "Shift-Right", .keyChord(KeyChord("right", modifiers: [.shift])), repeatable: true)
        add("select.up", "Extend selection up", "Selection", "Shift-Up", .keyChord(KeyChord("up", modifiers: [.shift])), repeatable: true)
        add("select.down", "Extend selection down", "Selection", "Shift-Down", .keyChord(KeyChord("down", modifiers: [.shift])), repeatable: true)

        add("duration.16", "16th note", "Simple durations", "Dorico duration 4", .keyChord(KeyChord("4")))
        add("duration.8", "Eighth note", "Simple durations", "Dorico duration 5", .keyChord(KeyChord("5")))
        add("duration.4", "Quarter note", "Simple durations", "Dorico duration 6", .keyChord(KeyChord("6")))
        add("duration.2", "Half note", "Simple durations", "Dorico duration 7", .keyChord(KeyChord("7")))
        add("duration.1", "Whole note", "Simple durations", "Dorico duration 8", .keyChord(KeyChord("8")))
        add("duration.dot", "Rhythm dot", "Simple durations", "Dorico rhythm dot", .keyChord(KeyChord("period")))
        add("tie", "Tie", "Simple durations", "Dorico tie command", .keyChord(KeyChord("t")))

        add("xbox.popover.ornaments", "Ornaments", "Popovers", "Open the controller-written ornaments picker", .controllerText(.ornamentsPopover))
        add("xbox.text.focused", "Xbox keyboard for focused Dorico field", "Xbox text entry", "Type into a focused field or open popover", .controllerText(.focusedField))
        add("xbox.jump.commands", "Xbox keyboard for Jump Bar Commands", "Xbox text entry", "Open Jump Bar Commands", .controllerText(.jumpBarCommands))
        add("xbox.jump.goto", "Xbox keyboard for Jump Bar Go To", "Xbox text entry", "Open Jump Bar Go To", .controllerText(.jumpBarGoTo))
        add("xbox.popover.dynamics", "Dynamics", "Popovers", "Controller-written dynamics", .controllerText(.dynamicsPopover))
        add("xbox.popover.meter", "Time signature", "Popovers", "Controller-written time signature", .controllerText(.meterPopover))
        add("xbox.popover.key", "Key signature", "Popovers", "Controller-written key signature", .controllerText(.keySignaturePopover))
        add("xbox.popover.tempo", "Tempo", "Popovers", "Controller-written tempo", .controllerText(.tempoPopover))
        add("xbox.popover.clef", "Clef", "Popovers", "Controller-written clef", .controllerText(.clefPopover))
        add("xbox.popover.playing", "Playing technique", "Popovers", "Controller-written playing technique", .controllerText(.playingTechniquesPopover))
        add("xbox.popover.bars", "Bars and barlines", "Popovers", "Controller-written bars and barlines", .controllerText(.barsAndBarlinesPopover))

        add("access.focus.left", "Accessibility focus left", "Universal access", "Move to nearest accessible control on the left", .accessibility(.move(.left)), repeatable: true)
        add("access.focus.right", "Accessibility focus right", "Universal access", "Move to nearest accessible control on the right", .accessibility(.move(.right)), repeatable: true)
        add("access.focus.up", "Accessibility focus up", "Universal access", "Move to nearest accessible control above", .accessibility(.move(.up)), repeatable: true)
        add("access.focus.down", "Accessibility focus down", "Universal access", "Move to nearest accessible control below", .accessibility(.move(.down)), repeatable: true)
        add("access.scan.next", "Next accessible zone", "Legato zones", "Next reachable Dorico zone", .accessibility(.scanNext), repeatable: true)
        add("access.scan.previous", "Previous accessible zone", "Legato zones", "Previous reachable Dorico zone", .accessibility(.scanPrevious), repeatable: true)
        add("access.press", "Press accessible control", "Universal access", "Press the focused Dorico control", .accessibility(.pressFocused))
        add("access.increment", "Increase accessible value", "Universal access", "Increase focused value", .accessibility(.incrementFocused), repeatable: true)
        add("access.decrement", "Decrease accessible value", "Universal access", "Decrease focused value", .accessibility(.decrementFocused), repeatable: true)
        add("access.menu", "Show focused control menu", "Universal access", "Open the focused control menu", .accessibility(.showFocusedMenu))

        add("pointer.toggle", "Toggle pointer mode", "Pointer", "Turn controller pointer mode on or off", .pointer(.toggle))
        add("pointer.click", "Pointer click", "Pointer", "Left-click", .pointer(.leftClick))
        add("pointer.double", "Pointer double-click", "Pointer", "Double-click", .pointer(.doubleClick))
        add("pointer.right", "Pointer right-click", "Pointer", "Right-click", .pointer(.rightClick))
        add("pointer.scroll.up", "Scroll up", "Pointer", "Scroll upward", .pointer(.scroll(dx: 0, dy: 4)), repeatable: true)
        add("pointer.scroll.down", "Scroll down", "Pointer", "Scroll downward", .pointer(.scroll(dx: 0, dy: -4)), repeatable: true)
        add("pointer.scroll.left", "Scroll left", "Pointer", "Scroll left", .pointer(.scroll(dx: -4, dy: 0)), repeatable: true)
        add("pointer.scroll.right", "Scroll right", "Pointer", "Scroll right", .pointer(.scroll(dx: 4, dy: 0)), repeatable: true)
        add("bridge.dashboard", "Open Legato command area", "Bridge", "Open the controller dashboard", .internalCommand(.showDashboard))
        add("bridge.toggle", "Toggle bridge dashboard", "Bridge", "Open or close the dashboard", .internalCommand(.toggleDashboard))

        for index in 0..<512 {
            let address = MIDIAddress.address(for: index)
            add(
                "midi.slot.\(index + 1)",
                "MIDI Learn \(address.noteName) · Channel \(address.channel)",
                "Dorico MIDI Learn",
                "Virtual MIDI \(address.noteName) on channel \(address.channel)",
                .midiPulse(address)
            )
        }
        return list
    }()

    public static let actionByID = Dictionary(uniqueKeysWithValues: actions.map { ($0.id, $0) })
    public static func action(_ id: String) -> CommandAction { actionByID[id]?.action ?? .none }

    public static let legatoStyleProfile: ControllerProfile = {
        var bindings: [BindingKey: CommandAction] = [:]
        func bind(_ layer: MappingLayer = .base, _ input: XboxInput, _ actionID: String, _ gesture: BindingGesture = .press) {
            let key = BindingKey(layer: layer, input: input, gesture: gesture)
            precondition(bindings[key] == nil, "Duplicate Legato mapping slot: \(key)")
            bindings[key] = action(actionID)
        }

        bind(.base, .buttonA, "place.note")
        bind(.base, .buttonB, "cancel")
        bind(.base, .buttonX, "xbox.popover.ornaments")
        bind(.base, .buttonY, "bridge.dashboard")
        bind(.base, .leftBumper, "access.scan.previous")
        bind(.base, .rightBumper, "access.scan.next")
        bind(.base, .view, "undo")
        bind(.base, .menu, "bridge.dashboard")
        bind(.base, .leftThumbstickButton, "play")
        bind(.base, .rightThumbstickButton, "pointer.toggle")
        bind(.base, .guide, "bridge.toggle")

        for input in [XboxInput.dpadLeft, .leftStickLeft] { bind(.base, input, "navigate.left") }
        for input in [XboxInput.dpadRight, .leftStickRight] { bind(.base, input, "navigate.right") }
        for input in [XboxInput.dpadUp, .leftStickUp] { bind(.base, input, "pitch.up") }
        for input in [XboxInput.dpadDown, .leftStickDown] { bind(.base, input, "pitch.down") }

        bind(.base, .rightStickUp, "pointer.scroll.up")
        bind(.base, .rightStickDown, "pointer.scroll.down")
        bind(.base, .rightStickLeft, "pointer.scroll.left")
        bind(.base, .rightStickRight, "pointer.scroll.right")

        bind(.leftTrigger, .buttonA, "copy")
        bind(.leftTrigger, .buttonB, "cut")
        bind(.leftTrigger, .buttonX, "paste")
        bind(.leftTrigger, .buttonY, "select.all")
        for input in [XboxInput.dpadLeft, .leftStickLeft] { bind(.leftTrigger, input, "select.left") }
        for input in [XboxInput.dpadRight, .leftStickRight] { bind(.leftTrigger, input, "select.right") }
        for input in [XboxInput.dpadUp, .leftStickUp] { bind(.leftTrigger, input, "select.up") }
        for input in [XboxInput.dpadDown, .leftStickDown] { bind(.leftTrigger, input, "select.down") }

        bind(.rightTrigger, .buttonB, "duration.16")
        bind(.rightTrigger, .buttonX, "duration.8")
        bind(.rightTrigger, .buttonA, "duration.4")
        bind(.rightTrigger, .buttonY, "duration.2")
        bind(.rightTrigger, .dpadUp, "duration.1")
        bind(.rightTrigger, .leftStickUp, "duration.1")
        bind(.rightTrigger, .dpadRight, "duration.dot")
        bind(.rightTrigger, .leftStickRight, "duration.dot")
        bind(.rightTrigger, .dpadLeft, "tie")
        bind(.rightTrigger, .leftStickLeft, "tie")

        bind(.bothBumpers, .rightBumper, "bridge.dashboard")

        for input in [XboxInput.leftStickLeft, .rightStickLeft] { bindings[BindingKey(layer: .pointer, input: input)] = .pointer(.move(dx: -18, dy: 0)) }
        for input in [XboxInput.leftStickRight, .rightStickRight] { bindings[BindingKey(layer: .pointer, input: input)] = .pointer(.move(dx: 18, dy: 0)) }
        for input in [XboxInput.leftStickUp, .rightStickUp] { bindings[BindingKey(layer: .pointer, input: input)] = .pointer(.move(dx: 0, dy: 18)) }
        for input in [XboxInput.leftStickDown, .rightStickDown] { bindings[BindingKey(layer: .pointer, input: input)] = .pointer(.move(dx: 0, dy: -18)) }
        bindings[BindingKey(layer: .pointer, input: .buttonA)] = .pointer(.leftClick)
        bindings[BindingKey(layer: .pointer, input: .buttonX)] = .pointer(.rightClick)
        bindings[BindingKey(layer: .pointer, input: .buttonY)] = .pointer(.doubleClick)
        bindings[BindingKey(layer: .pointer, input: .buttonB)] = .pointer(.toggle)

        return ControllerProfile(name: "Dorico Pro — exact Legato controls", bindings: bindings)
    }()
}
