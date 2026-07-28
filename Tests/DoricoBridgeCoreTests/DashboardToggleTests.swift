import XCTest
@testable import DoricoBridgeCore

final class DashboardToggleTests: XCTestCase {
    func testViewAndGuideToggleDashboardWhileHelperIsActive() {
        let resolver = BindingResolver()
        for input in [XboxInput.view, .guide] {
            let action = resolver.resolve(
                emission: GestureEmission(input: input, gesture: .press, timestamp: 1),
                heldInputs: [input],
                pointerMode: false,
                helperUIActive: true,
                profile: DefaultCatalog.legatoStyleProfile
            )
            XCTAssertEqual(action, .internalCommand(.toggleDashboard))
        }
    }
}
