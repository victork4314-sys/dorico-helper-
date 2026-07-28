import XCTest
@testable import DoricoBridgeCore

final class PhysicalCaptureSemanticsTests: XCTestCase {
    func testBMayParticipateInACombinationEvenThoughBAloneIsCancelInCaptureUI() {
        let combination: Set<XboxInput> = [.buttonB, .buttonA, .leftTrigger]
        let key = BindingKey(inputs: combination)
        XCTAssertEqual(key.inputs, combination)
        XCTAssertNotEqual(key.inputs, [.buttonB])
    }

    func testExactCombinationDisplayListsEveryMemberDeterministically() {
        let key = BindingKey(inputs: [.guide, .buttonA, .leftTrigger, .rightBumper])
        XCTAssertEqual(key.displayName, "A + RB + LT + Xbox / Guide")
        XCTAssertEqual(key.stableID, "normal.buttonA+rightBumper+leftTrigger+guide.press")
    }
}
