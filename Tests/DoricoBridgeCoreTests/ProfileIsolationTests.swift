import XCTest
@testable import DoricoBridgeCore

final class ProfileIsolationTests: XCTestCase {
    func testProfilesDoNotShareBindingDictionaries() {
        var first = ControllerProfile(name: "First", bindings: [
            BindingKey(inputs: [.buttonA]): .typeText("first")
        ])
        let second = ControllerProfile(name: "Second", bindings: [
            BindingKey(inputs: [.buttonA]): .typeText("second")
        ])

        first.bindings[BindingKey(inputs: [.buttonB])] = .typeText("only first")

        XCTAssertEqual(first.action(for: BindingKey(inputs: [.buttonA])), .typeText("first"))
        XCTAssertEqual(second.action(for: BindingKey(inputs: [.buttonA])), .typeText("second"))
        XCTAssertNil(second.action(for: BindingKey(inputs: [.buttonB])))
    }

    func testNormalAndPointerBindingsStaySeparateWithinOneProfile() {
        let profile = ControllerProfile(name: "Contexts", bindings: [
            BindingKey(inputs: [.buttonA], pointerMode: false): .typeText("normal"),
            BindingKey(inputs: [.buttonA], pointerMode: true): .typeText("pointer")
        ])
        XCTAssertEqual(profile.action(for: [.buttonA], gesture: .press, pointerMode: false), .typeText("normal"))
        XCTAssertEqual(profile.action(for: [.buttonA], gesture: .press, pointerMode: true), .typeText("pointer"))
    }
}
