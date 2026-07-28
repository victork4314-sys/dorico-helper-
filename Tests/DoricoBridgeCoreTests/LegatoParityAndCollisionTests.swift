import XCTest
@testable import DoricoBridgeCore

final class LegatoParityAndCollisionTests: XCTestCase {
    private let profile = DefaultCatalog.legatoStyleProfile
    private let resolver = BindingResolver()

    private func arbitraryProfile(includeAllControls: Bool = false) -> ControllerProfile {
        var bindings: [BindingKey: CommandAction] = [
            BindingKey(inputs: [.buttonA]): .typeText("single"),
            BindingKey(inputs: [.buttonA, .leftTrigger]): .typeText("double"),
            BindingKey(inputs: [.buttonA, .leftTrigger, .rightBumper]): .typeText("triple"),
            BindingKey(inputs: [.dpadLeft, .dpadRight, .buttonA]): .typeText("opposites")
        ]
        if includeAllControls {
            bindings[BindingKey(inputs: Set(XboxInput.allCases))] = .typeText("all")
        }
        return ControllerProfile(name: "Arbitrary", bindings: bindings)
    }

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
            XCTAssertEqual(profile.action(for: BindingKey(inputs: [input])), action, "Wrong Legato base action for \(input.displayName)")
        }
    }

    func testDpadAndLeftStickRemainIdenticalInBaseAndLTCombinations() {
        let pairs: [(XboxInput, XboxInput)] = [
            (.dpadLeft, .leftStickLeft), (.dpadRight, .leftStickRight),
            (.dpadUp, .leftStickUp), (.dpadDown, .leftStickDown)
        ]
        for (dpad, stick) in pairs {
            XCTAssertEqual(
                profile.action(for: BindingKey(inputs: [dpad])),
                profile.action(for: BindingKey(inputs: [stick]))
            )
            XCTAssertEqual(
                profile.action(for: BindingKey(inputs: [.leftTrigger, dpad])),
                profile.action(for: BindingKey(inputs: [.leftTrigger, stick]))
            )
        }
    }

    func testBaseUpDownUseDynamicPitchMovement() {
        XCTAssertEqual(profile.action(for: BindingKey(inputs: [.dpadUp])), DefaultCatalog.action("pitch.up"))
        XCTAssertEqual(profile.action(for: BindingKey(inputs: [.dpadDown])), DefaultCatalog.action("pitch.down"))
        XCTAssertEqual(profile.action(for: BindingKey(inputs: [.leftStickUp])), DefaultCatalog.action("pitch.up"))
        XCTAssertEqual(profile.action(for: BindingKey(inputs: [.leftStickDown])), DefaultCatalog.action("pitch.down"))
    }

    func testEveryExactBindingKeyIsUnique() {
        let keys = Array(profile.bindings.keys)
        XCTAssertEqual(Set(keys).count, keys.count)
    }

    func testResolverNeverFallsBackToSmallerCombination() {
        let custom = arbitraryProfile()
        XCTAssertNil(resolver.resolve(
            emission: GestureEmission(inputs: [.buttonA, .leftTrigger, .buttonX], primaryInput: .buttonX, gesture: .press, timestamp: 1),
            heldInputs: [.buttonA, .leftTrigger, .buttonX],
            pointerMode: false,
            helperUIActive: false,
            profile: custom
        ))
    }

    func testSingleCombinationDefersUntilReleaseWhenLargerCombinationExists() {
        var engine = GestureEngine()
        let custom = arbitraryProfile()
        XCTAssertTrue(engine.ingest(.init(input: .buttonA, isPressed: true, timestamp: 0), profile: custom).isEmpty)
        let released = engine.ingest(.init(input: .buttonA, isPressed: false, timestamp: 0.1), profile: custom)
        XCTAssertEqual(released.map(\.gesture), [.press, .release])
        XCTAssertEqual(released.first?.inputs, [.buttonA])
    }

    func testThreeButtonCombinationSuppressesSingleAndTwoButtonActions() {
        var engine = GestureEngine()
        let custom = arbitraryProfile()
        XCTAssertTrue(engine.ingest(.init(input: .buttonA, isPressed: true, timestamp: 0), profile: custom).isEmpty)
        XCTAssertTrue(engine.ingest(.init(input: .leftTrigger, isPressed: true, timestamp: 0.1), profile: custom).isEmpty)
        let output = engine.ingest(.init(input: .rightBumper, isPressed: true, timestamp: 0.2), profile: custom)
        XCTAssertEqual(output, [
            GestureEmission(
                inputs: [.buttonA, .leftTrigger, .rightBumper],
                primaryInput: .rightBumper,
                gesture: .press,
                timestamp: 0.2
            )
        ])
    }

    func testOppositeDirectionsCanExistInOneCombination() {
        let custom = arbitraryProfile()
        XCTAssertEqual(
            custom.action(for: BindingKey(inputs: [.dpadRight, .buttonA, .dpadLeft])),
            .typeText("opposites")
        )
    }

    func testPartialReleaseNeverSynthesizesSmallerMappings() {
        var engine = GestureEngine()
        let custom = arbitraryProfile()
        _ = engine.ingest(.init(input: .buttonA, isPressed: true, timestamp: 0), profile: custom)
        _ = engine.ingest(.init(input: .leftTrigger, isPressed: true, timestamp: 0.1), profile: custom)
        _ = engine.ingest(.init(input: .rightBumper, isPressed: true, timestamp: 0.2), profile: custom)
        XCTAssertEqual(
            engine.ingest(.init(input: .rightBumper, isPressed: false, timestamp: 0.3), profile: custom).map(\.gesture),
            [.release]
        )
        XCTAssertTrue(engine.ingest(.init(input: .leftTrigger, isPressed: false, timestamp: 0.4), profile: custom).isEmpty)
        XCTAssertTrue(engine.ingest(.init(input: .buttonA, isPressed: false, timestamp: 0.5), profile: custom).isEmpty)
    }

    func testAllControllerInputsCanBeOneBinding() {
        let allInputs = Set(XboxInput.allCases)
        let custom = ControllerProfile(name: "All", bindings: [
            BindingKey(inputs: allInputs): .typeText("all")
        ])
        var engine = GestureEngine()
        var output: [GestureEmission] = []
        for (index, input) in XboxInput.allCases.enumerated() {
            output += engine.ingest(
                .init(input: input, isPressed: true, timestamp: Double(index) * 0.03),
                profile: custom
            )
        }
        XCTAssertEqual(output.count, 1)
        XCTAssertEqual(output.first?.inputs, allInputs)
        XCTAssertEqual(
            resolver.resolve(
                emission: try! XCTUnwrap(output.first),
                heldInputs: allInputs,
                pointerMode: false,
                helperUIActive: false,
                profile: custom
            ),
            .typeText("all")
        )
    }

    func testAssemblyOrderDoesNotChangeTheExactCombination() {
        let custom = ControllerProfile(name: "Order", bindings: [
            BindingKey(inputs: [.buttonA, .leftTrigger]): .typeText("same")
        ])

        func output(first: XboxInput, second: XboxInput) -> Set<XboxInput>? {
            var engine = GestureEngine()
            _ = engine.ingest(.init(input: first, isPressed: true, timestamp: 0), profile: custom)
            return engine.ingest(.init(input: second, isPressed: true, timestamp: 0.2), profile: custom).first?.inputs
        }

        XCTAssertEqual(output(first: .buttonA, second: .leftTrigger), [.buttonA, .leftTrigger])
        XCTAssertEqual(output(first: .leftTrigger, second: .buttonA), [.buttonA, .leftTrigger])
    }

    func testPointerContextIsIndependentFromNormalContext() {
        let custom = ControllerProfile(name: "Pointer", bindings: [
            BindingKey(inputs: [.buttonA], pointerMode: false): .typeText("normal"),
            BindingKey(inputs: [.buttonA], pointerMode: true): .typeText("pointer")
        ])
        let emission = GestureEmission(input: .buttonA, gesture: .press, timestamp: 1)
        XCTAssertEqual(resolver.resolve(emission: emission, heldInputs: [.buttonA], pointerMode: false, helperUIActive: false, profile: custom), .typeText("normal"))
        XCTAssertEqual(resolver.resolve(emission: emission, heldInputs: [.buttonA], pointerMode: true, helperUIActive: false, profile: custom), .typeText("pointer"))
    }

    func testRightStickScrollsNormallyAndMovesPointerInPointerMode() {
        XCTAssertEqual(profile.action(for: BindingKey(inputs: [.rightStickUp])), DefaultCatalog.action("pointer.scroll.up"))
        XCTAssertEqual(
            profile.action(for: BindingKey(inputs: [.rightStickUp], pointerMode: true)),
            .pointer(.move(dx: 0, dy: 18))
        )
    }
}
