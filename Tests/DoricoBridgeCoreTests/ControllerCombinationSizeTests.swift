import XCTest
@testable import DoricoBridgeCore

final class ControllerCombinationSizeTests: XCTestCase {
    func testBindingKeyAcceptsEverySupportedInputAtOnce() {
        let everyInput = Set(XboxInput.allCases)
        XCTAssertEqual(BindingKey(inputs: everyInput).inputs.count, XboxInput.allCases.count)
    }
}
