import XCTest
@testable import DoricoBridgeCore

final class SlowAssemblyTests: XCTestCase {
    func testNoTimeoutForDeliberatelySlowLargeCombination() {
        let profile = ControllerProfile(name: "Slow", bindings: [
            BindingKey(inputs: [.buttonA]): .typeText("small"),
            BindingKey(inputs: [.buttonA, .leftTrigger, .rightBumper]): .typeText("large")
        ])
        var engine = GestureEngine()
        XCTAssertTrue(engine.ingest(.init(input: .buttonA, isPressed: true, timestamp: 0), profile: profile).isEmpty)
        XCTAssertTrue(engine.tick(at: 10, profile: profile).isEmpty)
        XCTAssertTrue(engine.ingest(.init(input: .leftTrigger, isPressed: true, timestamp: 20), profile: profile).isEmpty)
        let output = engine.ingest(.init(input: .rightBumper, isPressed: true, timestamp: 30), profile: profile)
        XCTAssertEqual(output.map(\.inputs), [[.buttonA, .leftTrigger, .rightBumper]])
    }
}
