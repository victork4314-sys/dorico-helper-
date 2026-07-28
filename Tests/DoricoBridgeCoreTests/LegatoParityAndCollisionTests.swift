import XCTest
@testable import DoricoBridgeCore

final class LegatoParityAndCollisionTests: XCTestCase {
    private let profile = DefaultCatalog.legatoStyleProfile
    private let resolver = BindingResolver()

    func testExactLegatoPhysicalBaseLayout() {
        let expected: [(XboxInput, CommandAction)] = [
            (.buttonA, DefaultCatalog.action("place.note")),
            (.buttonB, DefaultCatalog.action("cancel")),
            (.buttonX, DefaultCatalog.action("xbox.popover.ornaments")),
            (.buttonY, DefaultCatalog.action("bridge.dashboard")),
            (.leftBumper, DefaultCatalog.action("access.scan.previous")),
            (.rightBumper, DefaultCatalog.action("access.scan.next")),
            (.view, DefaultCatalog.action("undo")),
            (.menu, DefaultCatalog.action("bridge.dashboard")),
            (.leftThumbstickButton, DefaultCatalog.action("play")),
            (.rightThumbstickButton, DefaultCatalog.action("pointer.toggle"))
        ]
        for (input, action) in expected {
            XCTAssertEqual(profile.action(for: BindingKey(layer: .base, input: input)), action, "Wrong Legato base action for \(input.displayName)")
        }
    }

    func testDpadAndLeftStickAreIdenticalInBaseAndSelectionLayers() {
        let pairs: [(XboxInput, XboxInput)] = [
            (.dpadLeft, .leftStickLeft), (.dpadRight, .leftStickRight),
            (.dpadUp, .leftStickUp), (.dpadDown, .leftStickDown)
        ]
        for layer in [MappingLayer.base, .leftTrigger] {
            for (dpad, stick) in pairs {
                XCTAssertEqual(
                    profile.action(for: BindingKey(layer: layer, input: dpad)),
                    profile.action(for: BindingKey(layer: layer, input: stick)),
                    "D-pad and left stick differ in \(layer.displayName)"
                )
            }
        }
    }

    func testBaseUpDownUseDynamicPitchMovement() {
        XCTAssertEqual(profile.action(for: BindingKey(layer: .base, input: .dpadUp)), DefaultCatalog.action("pitch.up"))
        XCTAssertEqual(profile.action(for: BindingKey(layer: .base, input: .dpadDown)), DefaultCatalog.action("pitch.down"))
        XCTAssertEqual(profile.action(for: BindingKey(layer: .base, input: .leftStickUp)), DefaultCatalog.action("pitch.up"))
        XCTAssertEqual(profile.action(for: BindingKey(layer: .base, input: .leftStickDown)), DefaultCatalog.action("pitch.down"))
    }

    func testEveryPhysicalSlotHasOnlyOneAction() {
        let keys = Array(profile.bindings.keys)
        XCTAssertEqual(Set(keys).count, keys.count)
    }

    func testUnmappedModifierCombinationNeverFallsBackToBase() {
        let action = resolver.resolve(
            emission: GestureEmission(input: .menu, gesture: .press, timestamp: 1),
            heldInputs: [.leftTrigger, .menu],
            pointerMode: false,
            helperUIActive: false,
            profile: profile
        )
        XCTAssertNil(action, "LT + Menu incorrectly fell through to base Menu")
    }

    func testStandaloneBumperUsesBaseLayer() {
        XCTAssertEqual(
            resolver.resolve(
                emission: GestureEmission(input: .leftBumper, gesture: .press, timestamp: 1),
                heldInputs: [.leftBumper],
                pointerMode: false,
                helperUIActive: false,
                profile: profile
            ),
            DefaultCatalog.action("access.scan.previous")
        )
    }

    func testBothBumpersResolveOnlyTheComboAction() {
        XCTAssertEqual(
            resolver.resolve(
                emission: GestureEmission(input: .rightBumper, gesture: .press, timestamp: 1),
                heldInputs: [.leftBumper, .rightBumper],
                pointerMode: false,
                helperUIActive: false,
                profile: profile
            ),
            DefaultCatalog.action("bridge.dashboard")
        )
    }

    func testBumperComboSuppressesFirstSinglePress() {
        var engine = GestureEngine()
        XCTAssertTrue(engine.ingest(ControllerEvent(input: .leftBumper, isPressed: true, timestamp: 1), profile: profile).isEmpty)
        let second = engine.ingest(ControllerEvent(input: .rightBumper, isPressed: true, timestamp: 1.05), profile: profile)
        XCTAssertEqual(second, [GestureEmission(input: .rightBumper, gesture: .press, timestamp: 1.05)])
        XCTAssertTrue(engine.tick(at: 1.13, profile: profile).isEmpty, "Delayed LB single leaked after LB+RB combo")
    }

    func testSingleBumperFiresAfterComboWindow() {
        var engine = GestureEngine()
        XCTAssertTrue(engine.ingest(ControllerEvent(input: .leftBumper, isPressed: true, timestamp: 1), profile: profile).isEmpty)
        XCTAssertEqual(
            engine.tick(at: 1.121, profile: profile),
            [GestureEmission(input: .leftBumper, gesture: .press, timestamp: 1.120)]
        )
    }

    func testRightStickScrollsNormallyAndMovesPointerInPointerMode() {
        XCTAssertEqual(profile.action(for: BindingKey(layer: .base, input: .rightStickUp)), DefaultCatalog.action("pointer.scroll.up"))
        XCTAssertEqual(
            profile.action(for: BindingKey(layer: .pointer, input: .rightStickUp)),
            .pointer(.move(dx: 0, dy: 18))
        )
    }
}
