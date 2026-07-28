import XCTest
@testable import DoricoBridgeCore

final class ControllerInputStateTests: XCTestCase {
    func testInitialReleasedPollDoesNotManufactureAnEvent() {
        var state = ControllerInputState()
        XCTAssertNil(state.eventIfChanged(input: .buttonA, pressed: false, value: 0, timestamp: 1))
        XCTAssertFalse(state.isPressed(.buttonA))
    }

    func testInitialHeldControlIsDelivered() {
        var state = ControllerInputState()
        let event = state.eventIfChanged(input: .buttonA, pressed: true, value: 1, timestamp: 1)
        XCTAssertEqual(event?.input, .buttonA)
        XCTAssertEqual(event?.isPressed, true)
    }

    func testCallbackAndPollingPathsCannotDoubleTrigger() {
        var state = ControllerInputState()
        let callback = state.eventIfChanged(input: .dpadRight, pressed: true, value: 1, timestamp: 1)
        let pollingDuplicate = state.eventIfChanged(input: .dpadRight, pressed: true, value: 1, timestamp: 1.001)
        XCTAssertNotNil(callback)
        XCTAssertNil(pollingDuplicate)
    }

    func testPollingBackupCanDeliverWhenCallbackNeverArrives() {
        var state = ControllerInputState()
        _ = state.eventIfChanged(input: .buttonY, pressed: false, value: 0, timestamp: 1)
        let pollingEvent = state.eventIfChanged(input: .buttonY, pressed: true, value: 1, timestamp: 2)
        XCTAssertEqual(pollingEvent?.input, .buttonY)
        XCTAssertEqual(pollingEvent?.isPressed, true)
    }

    func testReleaseAndResetRecovery() {
        var state = ControllerInputState()
        _ = state.eventIfChanged(input: .leftTrigger, pressed: true, value: 1, timestamp: 1)
        let release = state.eventIfChanged(input: .leftTrigger, pressed: false, value: 0, timestamp: 2)
        XCTAssertEqual(release?.isPressed, false)
        XCTAssertTrue(state.pressedInputs.isEmpty)

        state.reset()
        let recoveredPress = state.eventIfChanged(input: .leftTrigger, pressed: true, value: 1, timestamp: 3)
        XCTAssertEqual(recoveredPress?.isPressed, true)
    }
}
