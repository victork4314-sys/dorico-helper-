import XCTest
@testable import DoricoBridgeCore

final class AllButtonsCombinationTests: XCTestCase {
    func testEveryIndependentButtonAndTriggerCanResolveAsOneAction() {
        let allButtons: Set<XboxInput> = [
            .buttonA, .buttonB, .buttonX, .buttonY,
            .leftBumper, .rightBumper, .leftTrigger, .rightTrigger,
            .leftThumbstickButton, .rightThumbstickButton,
            .menu, .view, .guide
        ]
        let action = CommandAction.typeText("all buttons")
        let profile = ControllerProfile(name: "All buttons", bindings: [
            BindingKey(inputs: allButtons): action
        ])
        let emission = GestureEmission(
            inputs: allButtons,
            primaryInput: .guide,
            gesture: .press,
            timestamp: 1
        )
        XCTAssertEqual(
            BindingResolver().resolve(
                emission: emission,
                heldInputs: allButtons,
                pointerMode: false,
                helperUIActive: false,
                profile: profile
            ),
            action
        )
    }
}
