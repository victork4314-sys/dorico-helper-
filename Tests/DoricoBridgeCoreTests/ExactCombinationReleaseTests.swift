import XCTest
@testable import DoricoBridgeCore

final class ExactCombinationReleaseTests: XCTestCase {
    func testAConfiguredPrefixFiresOnceOnReleaseNotUnderTheLargerChord() {
        let profile = ControllerProfile(name: "Prefixes", bindings: [
            BindingKey(inputs: [.buttonA]): .typeText("A"),
            BindingKey(inputs: [.buttonA, .leftTrigger]): .typeText("A+LT")
        ])
        var engine = GestureEngine()

        XCTAssertTrue(engine.ingest(.init(input: .buttonA, isPressed: true, timestamp: 0), profile: profile).isEmpty)
        let singleRelease = engine.ingest(.init(input: .buttonA, isPressed: false, timestamp: 0.1), profile: profile)
        XCTAssertEqual(singleRelease.filter { $0.gesture == .press }.count, 1)

        engine.reset()
        XCTAssertTrue(engine.ingest(.init(input: .buttonA, isPressed: true, timestamp: 1), profile: profile).isEmpty)
        let larger = engine.ingest(.init(input: .leftTrigger, isPressed: true, timestamp: 1.5), profile: profile)
        XCTAssertEqual(larger.filter { $0.gesture == .press }.map(\.inputs), [[.buttonA, .leftTrigger]])
    }
}
