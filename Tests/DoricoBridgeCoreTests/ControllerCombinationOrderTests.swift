import XCTest
@testable import DoricoBridgeCore

final class ControllerCombinationOrderTests: XCTestCase {
    func testAllPermutationsOfThreeControlsUseTheSameBindingKey() {
        let expected = BindingKey(inputs: [.buttonA, .leftTrigger, .rightBumper])
        let permutations: [[XboxInput]] = [
            [.buttonA, .leftTrigger, .rightBumper],
            [.buttonA, .rightBumper, .leftTrigger],
            [.leftTrigger, .buttonA, .rightBumper],
            [.leftTrigger, .rightBumper, .buttonA],
            [.rightBumper, .buttonA, .leftTrigger],
            [.rightBumper, .leftTrigger, .buttonA]
        ]
        for permutation in permutations {
            XCTAssertEqual(BindingKey(inputs: Set(permutation)), expected)
        }
    }
}
