import XCTest
@testable import DoricoBridgeCore

final class CoreTests: XCTestCase {
    func testLayerPrecedence() {
        let resolver = BindingResolver()
        XCTAssertEqual(resolver.activeLayer(heldInputs: [.leftTrigger], pointerMode: false), .leftTrigger)
        XCTAssertEqual(resolver.activeLayer(heldInputs: [.leftTrigger, .rightTrigger], pointerMode: false), .bothTriggers)
        XCTAssertEqual(resolver.activeLayer(heldInputs: [.leftBumper, .rightBumper], pointerMode: false), .bothBumpers)
        XCTAssertEqual(resolver.activeLayer(heldInputs: [.leftTrigger, .rightTrigger], pointerMode: true), .pointer)
    }

    func testBIsAlwaysBackInsideHelper() {
        let resolver = BindingResolver()
        let action = resolver.resolve(
            emission: GestureEmission(input: .buttonB, gesture: .press, timestamp: 1),
            heldInputs: [], pointerMode: false, helperUIActive: true,
            profile: DefaultCatalog.legatoStyleProfile
        )
        XCTAssertEqual(action, .internalCommand(.helperBack))
    }

    func testHelperConsumesUnmappedControls() {
        let resolver = BindingResolver()
        for input in [XboxInput.buttonX, .buttonY, .menu, .leftTrigger, .rightTrigger] {
            XCTAssertNil(resolver.resolve(
                emission: GestureEmission(input: input, gesture: .press, timestamp: 1),
                heldInputs: [input], pointerMode: false, helperUIActive: true,
                profile: DefaultCatalog.legatoStyleProfile
            ), "\(input.displayName) leaked through the active helper UI")
        }
    }

    func testHelperBumpersAdjustWithoutStealingDirectionalMovement() {
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
            heldInputs: [], pointerMode: false, helperUIActive: true, profile: profile
        ), .internalCommand(.helperLeft))
    }

    func testRepeatFallsBackToPressBindingWithinSameLayer() {
        let action = BindingResolver().resolve(
            emission: GestureEmission(input: .dpadRight, gesture: .repeatPress, timestamp: 1),
            heldInputs: [], pointerMode: false, helperUIActive: false,
            profile: DefaultCatalog.legatoStyleProfile
        )
        XCTAssertEqual(action, .keyChord(KeyChord("right")))
    }

    func testDoublePressDefersSinglePress() {
        var profile = DefaultCatalog.legatoStyleProfile
        profile.bindings[BindingKey(layer: .base, input: .buttonA, gesture: .doublePress)] = .internalCommand(.showDashboard)
        var engine = GestureEngine()
        XCTAssertTrue(engine.ingest(ControllerEvent(input: .buttonA, isPressed: true, timestamp: 0), profile: profile).isEmpty)
        _ = engine.ingest(ControllerEvent(input: .buttonA, isPressed: false, timestamp: 0.05), profile: profile)
        let second = engine.ingest(ControllerEvent(input: .buttonA, isPressed: true, timestamp: 0.15), profile: profile)
        XCTAssertEqual(second.map(\.gesture), [.doublePress])
    }

    func testSinglePressEmitsAfterDoubleWindow() {
        var profile = DefaultCatalog.legatoStyleProfile
        profile.bindings[BindingKey(layer: .base, input: .buttonA, gesture: .doublePress)] = .internalCommand(.showDashboard)
        var engine = GestureEngine()
        _ = engine.ingest(ControllerEvent(input: .buttonA, isPressed: true, timestamp: 0), profile: profile)
        _ = engine.ingest(ControllerEvent(input: .buttonA, isPressed: false, timestamp: 0.05), profile: profile)
        XCTAssertEqual(engine.tick(at: 0.30, profile: profile).map(\.gesture), [.press])
    }

    func testMIDIAddressUsesAllChannels() {
        XCTAssertEqual(MIDIAddress.address(for: 0), MIDIAddress(channel: 1, note: 0))
        XCTAssertEqual(MIDIAddress.address(for: 127), MIDIAddress(channel: 1, note: 127))
        XCTAssertEqual(MIDIAddress.address(for: 128), MIDIAddress(channel: 2, note: 0))
        XCTAssertEqual(MIDIAddress.address(for: 511), MIDIAddress(channel: 4, note: 127))
    }

    func testProfileRoundTrip() throws {
        let data = try JSONEncoder().encode(DefaultCatalog.legatoStyleProfile)
        let decoded = try JSONDecoder().decode(ControllerProfile.self, from: data)
        XCTAssertEqual(decoded.name, DefaultCatalog.legatoStyleProfile.name)
        XCTAssertEqual(decoded.bindings.count, DefaultCatalog.legatoStyleProfile.bindings.count)
    }

    func testControllerTextActionRoundTrip() throws {
        let original = CommandAction.controllerText(.jumpBarCommands)
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(CommandAction.self, from: data), original)
    }

    func testDefaultProfileUsesExactLegatoFaceAndStickClickLayout() {
        let profile = DefaultCatalog.legatoStyleProfile
        XCTAssertEqual(profile.action(for: BindingKey(layer: .base, input: .buttonA)), DefaultCatalog.action("activate"))
        XCTAssertEqual(profile.action(for: BindingKey(layer: .base, input: .buttonB)), DefaultCatalog.action("cancel"))
        XCTAssertEqual(profile.action(for: BindingKey(layer: .base, input: .buttonX)), .controllerText(.ornamentsPopover))
        XCTAssertEqual(profile.action(for: BindingKey(layer: .base, input: .buttonY)), .internalCommand(.showDashboard))
        XCTAssertEqual(profile.action(for: BindingKey(layer: .base, input: .leftThumbstickButton)), DefaultCatalog.action("play"))
        XCTAssertEqual(profile.action(for: BindingKey(layer: .base, input: .rightThumbstickButton)), .pointer(.toggle))
    }

    func testUniversalActionCatalogRemainsAvailableForAddMapping() {
        let requiredIDs = [
            "access.focus.left", "access.focus.right", "access.focus.up", "access.focus.down",
            "access.press", "access.increment", "access.decrement", "access.menu",
            "access.scan.next", "access.scan.previous",
            "pointer.toggle", "pointer.click", "pointer.double", "pointer.right",
            "pointer.scroll.up", "pointer.scroll.down", "pointer.scroll.left", "pointer.scroll.right"
        ]
        for id in requiredIDs {
            XCTAssertNotNil(DefaultCatalog.actionByID[id], "Missing Add Mapping action: \(id)")
            XCTAssertNotEqual(DefaultCatalog.action(id), .none)
        }
    }

    func testBothBumpersHaveOnlyTheLegatoComboAction() {
        let profile = DefaultCatalog.legatoStyleProfile
        XCTAssertEqual(profile.action(for: BindingKey(layer: .bothBumpers, input: .rightBumper)), .internalCommand(.showDashboard))
        XCTAssertNil(profile.action(for: BindingKey(layer: .bothBumpers, input: .buttonB)))
        XCTAssertNil(profile.action(for: BindingKey(layer: .bothBumpers, input: .buttonX)))
        XCTAssertNil(profile.action(for: BindingKey(layer: .bothBumpers, input: .buttonY)))
    }
}