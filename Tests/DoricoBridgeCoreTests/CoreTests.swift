import XCTest
@testable import DoricoBridgeCore

final class CoreTests: XCTestCase {
    func testLegacyLayerHelperStillReportsOldContexts() {
        let resolver = BindingResolver()
        XCTAssertEqual(resolver.activeLayer(heldInputs: [.leftTrigger], pointerMode: false), .leftTrigger)
        XCTAssertEqual(resolver.activeLayer(heldInputs: [.leftTrigger, .rightTrigger], pointerMode: false), .bothTriggers)
        XCTAssertEqual(resolver.activeLayer(heldInputs: [.leftBumper, .rightBumper], pointerMode: false), .bothBumpers)
        XCTAssertEqual(resolver.activeLayer(heldInputs: [.leftTrigger, .rightTrigger], pointerMode: true), .pointer)
    }

    func testBIsAlwaysBackInsideHelper() {
        let action = BindingResolver().resolve(
            emission: GestureEmission(input: .buttonB, gesture: .press, timestamp: 1),
            heldInputs: [.buttonB],
            pointerMode: false,
            helperUIActive: true,
            profile: DefaultCatalog.legatoStyleProfile
        )
        XCTAssertEqual(action, .internalCommand(.helperBack))
    }

    func testHelperConsumesUnmappedControls() {
        let resolver = BindingResolver()
        for input in [XboxInput.buttonX, .buttonY, .menu, .leftTrigger, .rightTrigger] {
            XCTAssertNil(resolver.resolve(
                emission: GestureEmission(input: input, gesture: .press, timestamp: 1),
                heldInputs: [input],
                pointerMode: false,
                helperUIActive: true,
                profile: DefaultCatalog.legatoStyleProfile
            ), "\(input.displayName) leaked through the active helper UI")
        }
    }

    func testHelperNavigationRemainsImmediate() {
        let resolver = BindingResolver()
        let profile = DefaultCatalog.legatoStyleProfile
        XCTAssertEqual(resolver.resolve(
            emission: GestureEmission(input: .leftBumper, gesture: .press, timestamp: 1),
            heldInputs: [.leftBumper], pointerMode: false, helperUIActive: true, profile: profile
        ), .internalCommand(.helperDecrease))
        XCTAssertEqual(resolver.resolve(
            emission: GestureEmission(input: .rightBumper, gesture: .repeatPress, timestamp: 1),
            heldInputs: [.rightBumper], pointerMode: false, helperUIActive: true, profile: profile
        ), .internalCommand(.helperIncrease))
        XCTAssertEqual(resolver.resolve(
            emission: GestureEmission(input: .dpadLeft, gesture: .press, timestamp: 1),
            heldInputs: [.dpadLeft], pointerMode: false, helperUIActive: true, profile: profile
        ), .internalCommand(.helperLeft))
    }

    func testRepeatFallsBackToExactPressBinding() {
        let action = BindingResolver().resolve(
            emission: GestureEmission(inputs: [.dpadRight], primaryInput: .dpadRight, gesture: .repeatPress, timestamp: 1),
            heldInputs: [.dpadRight],
            pointerMode: false,
            helperUIActive: false,
            profile: DefaultCatalog.legatoStyleProfile
        )
        XCTAssertEqual(action, .keyChord(KeyChord("right")))
    }

    func testDoublePressDefersAndReplacesSinglePress() {
        var profile = DefaultCatalog.legatoStyleProfile
        profile.bindings[BindingKey(inputs: [.buttonA], gesture: .doublePress)] = .internalCommand(.showDashboard)
        var engine = GestureEngine()
        XCTAssertTrue(engine.ingest(.init(input: .buttonA, isPressed: true, timestamp: 0), profile: profile).isEmpty)
        _ = engine.ingest(.init(input: .buttonA, isPressed: false, timestamp: 0.05), profile: profile)
        let second = engine.ingest(.init(input: .buttonA, isPressed: true, timestamp: 0.15), profile: profile)
        XCTAssertEqual(second.map(\.gesture), [.doublePress])
    }

    func testSinglePressEmitsAfterDoubleWindow() {
        var profile = DefaultCatalog.legatoStyleProfile
        profile.bindings[BindingKey(inputs: [.buttonA], gesture: .doublePress)] = .internalCommand(.showDashboard)
        var engine = GestureEngine()
        _ = engine.ingest(.init(input: .buttonA, isPressed: true, timestamp: 0), profile: profile)
        _ = engine.ingest(.init(input: .buttonA, isPressed: false, timestamp: 0.05), profile: profile)
        XCTAssertEqual(engine.tick(at: 0.30, profile: profile).map(\.gesture), [.press])
    }

    func testMIDIAddressUsesAllChannels() {
        XCTAssertEqual(MIDIAddress.address(for: 0), MIDIAddress(channel: 1, note: 0))
        XCTAssertEqual(MIDIAddress.address(for: 127), MIDIAddress(channel: 1, note: 127))
        XCTAssertEqual(MIDIAddress.address(for: 128), MIDIAddress(channel: 2, note: 0))
        XCTAssertEqual(MIDIAddress.address(for: 511), MIDIAddress(channel: 4, note: 127))
    }

    func testMIDIPitchesUseMusicalNames() {
        XCTAssertEqual(MIDIAddress.noteName(for: 0), "C-1")
        XCTAssertEqual(MIDIAddress.noteName(for: 59), "B3")
        XCTAssertEqual(MIDIAddress.noteName(for: 60), "C4")
        XCTAssertEqual(MIDIAddress.noteName(for: 61), "C♯4")
        XCTAssertEqual(MIDIAddress.noteName(for: 127), "G9")
        XCTAssertEqual(MIDIAddress(channel: 2, note: 61).displayName, "C♯4 · Channel 2")
    }

    func testDynamicNoteAddressesAreReservedOutsideMIDILearnCatalog() {
        let catalogAddresses = Set((0..<512).map(MIDIAddress.address(for:)))
        XCTAssertFalse(catalogAddresses.contains(BridgeDynamicMIDI.placeSelectedNote))
        XCTAssertFalse(catalogAddresses.contains(BridgeDynamicMIDI.pitchUp))
        XCTAssertFalse(catalogAddresses.contains(BridgeDynamicMIDI.pitchDown))
        XCTAssertTrue(BridgeDynamicMIDI.isReserved(BridgeDynamicMIDI.placeSelectedNote))
    }

    func testExactBindingKeyIsOrderIndependent() {
        XCTAssertEqual(
            BindingKey(inputs: [.buttonA, .leftTrigger, .dpadLeft]),
            BindingKey(inputs: [.dpadLeft, .buttonA, .leftTrigger])
        )
    }

    func testLegacyBindingKeyJSONMigratesToExactInputSet() throws {
        let data = Data(#"{"layer":"leftTrigger","input":"buttonA","gesture":"press"}"#.utf8)
        let key = try JSONDecoder().decode(BindingKey.self, from: data)
        XCTAssertEqual(key.inputs, [.leftTrigger, .buttonA])
        XCTAssertFalse(key.pointerMode)
        XCTAssertEqual(key.gesture, .press)
    }

    func testProfileRoundTripPreservesArbitraryCombinations() throws {
        var original = DefaultCatalog.legatoStyleProfile
        original.bindings[BindingKey(inputs: [.buttonA, .buttonB, .leftTrigger, .rightBumper])] = .typeText("custom")
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(ControllerProfile.self, from: data), original)
    }

    func testCapturedAndModifierOnlyShortcutsRoundTrip() throws {
        let captured = KeyChord(capturedKeyCode: 20, characters: "#", modifiers: [.command, .shift])
        let modifierOnly = KeyChord(modifiersOnly: [.control, .option, .function, .capsLock])
        for chord in [captured, modifierOnly] {
            let data = try JSONEncoder().encode(chord)
            XCTAssertEqual(try JSONDecoder().decode(KeyChord.self, from: data), chord)
        }
        XCTAssertEqual(captured.displayName, "⇧ + ⌘ + #")
        XCTAssertEqual(modifierOnly.displayName, "⌃ + ⌥ + fn + ⇪")
    }

    func testMixedActionSequenceRoundTrip() throws {
        let original = CommandAction.sequence([
            CommandStep(.keyChord(KeyChord(capturedKeyCode: 20, characters: "#", modifiers: [.command, .shift]))),
            CommandStep(.typeText("hello"), delayMilliseconds: 75),
            CommandStep(.midiPulse(MIDIAddress(channel: 2, note: 61)), delayMilliseconds: 125),
            CommandStep(.pointer(.leftClick), delayMilliseconds: 10),
            CommandStep(.menuPath(["Edit", "Delete"]), delayMilliseconds: 40)
        ])
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(CommandAction.self, from: data), original)
        XCTAssertEqual(original.summary, "Sequence (5 actions)")
    }

    func testControllerTextActionRoundTrip() throws {
        let original = CommandAction.controllerText(.jumpBarCommands)
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(CommandAction.self, from: data), original)
    }

    func testDefaultProfileUsesExactLegatoFaceAndStickClickLayout() {
        let profile = DefaultCatalog.legatoStyleProfile
        XCTAssertEqual(profile.action(for: BindingKey(inputs: [.buttonA])), DefaultCatalog.action("place.note"))
        XCTAssertEqual(profile.action(for: BindingKey(inputs: [.buttonB])), DefaultCatalog.action("cancel"))
        XCTAssertEqual(profile.action(for: BindingKey(inputs: [.buttonX])), .controllerText(.ornamentsPopover))
        XCTAssertEqual(profile.action(for: BindingKey(inputs: [.buttonY])), .internalCommand(.showDashboard))
        XCTAssertEqual(profile.action(for: BindingKey(inputs: [.leftThumbstickButton])), DefaultCatalog.action("play"))
        XCTAssertEqual(profile.action(for: BindingKey(inputs: [.rightThumbstickButton])), .pointer(.toggle))
    }

    func testSimpleActionsAreAvailableWithoutDoricoMenuScan() {
        let requiredIDs = [
            "place.note", "delete", "activate", "cancel", "note.input", "play",
            "undo", "redo", "pitch.up", "pitch.down", "duration.4"
        ]
        for id in requiredIDs {
            XCTAssertNotNil(DefaultCatalog.actionByID[id], "Missing simple mapping action: \(id)")
            XCTAssertNotEqual(DefaultCatalog.action(id), .none)
        }
    }

    func testMIDICatalogUsesNamesInsteadOfRawNoteLabels() {
        let middleC = DefaultCatalog.actionByID["midi.slot.61"]
        XCTAssertEqual(middleC?.title, "MIDI Learn C4 · Channel 1")
        XCTAssertEqual(middleC?.detail, "Virtual MIDI C4 on channel 1")
    }

    func testUniversalActionCatalogRemainsAvailableForMapping() {
        let requiredIDs = [
            "access.focus.left", "access.focus.right", "access.focus.up", "access.focus.down",
            "access.press", "access.increment", "access.decrement", "access.menu",
            "access.scan.next", "access.scan.previous",
            "pointer.toggle", "pointer.click", "pointer.double", "pointer.right",
            "pointer.scroll.up", "pointer.scroll.down", "pointer.scroll.left", "pointer.scroll.right"
        ]
        for id in requiredIDs {
            XCTAssertNotNil(DefaultCatalog.actionByID[id], "Missing mapping action: \(id)")
            XCTAssertNotEqual(DefaultCatalog.action(id), .none)
        }
    }
}
