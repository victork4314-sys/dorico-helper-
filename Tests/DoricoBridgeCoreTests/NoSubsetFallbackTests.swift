import XCTest
@testable import DoricoBridgeCore

final class NoSubsetFallbackTests: XCTestCase {
    func testEveryExtraHeldInputCreatesASeparateUnmappedContext() {
        let profile = ControllerProfile(name: "Exact", bindings: [
            BindingKey(inputs: [.buttonA]): .typeText("A")
        ])
        let resolver = BindingResolver()
        for extra in XboxInput.allCases where extra != .buttonA {
            XCTAssertNil(resolver.resolve(
                emission: GestureEmission(inputs: [.buttonA, extra], primaryInput: extra, gesture: .press, timestamp: 1),
                heldInputs: [.buttonA, extra],
                pointerMode: false,
                helperUIActive: false,
                profile: profile
            ), "A leaked into A + \(extra.displayName)")
        }
    }
}
