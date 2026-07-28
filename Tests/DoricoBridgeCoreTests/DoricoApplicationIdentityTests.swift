import XCTest
@testable import DoricoBridgeCore

final class DoricoApplicationIdentityTests: XCTestCase {
    func testRecognizesDoricoProApplicationNamesAndBundles() {
        XCTAssertTrue(DoricoApplicationIdentity.matches(localizedName: "Dorico", bundleIdentifier: nil))
        XCTAssertTrue(DoricoApplicationIdentity.matches(localizedName: "Dorico 6", bundleIdentifier: nil))
        XCTAssertTrue(DoricoApplicationIdentity.matches(localizedName: "Dorico Pro 6.1", bundleIdentifier: nil))
        XCTAssertTrue(DoricoApplicationIdentity.matches(localizedName: "Anything", bundleIdentifier: "com.steinberg.dorico6"))
    }

    func testRejectsHelperAndOtherDoricoNamedUtilities() {
        XCTAssertFalse(DoricoApplicationIdentity.matches(localizedName: "Dorico Xbox Bridge", bundleIdentifier: "org.figureloom.dorico-xbox-bridge"))
        XCTAssertFalse(DoricoApplicationIdentity.matches(localizedName: "Dorico Download Assistant", bundleIdentifier: "com.example.downloader"))
        XCTAssertFalse(DoricoApplicationIdentity.matches(localizedName: "Safari", bundleIdentifier: "com.apple.Safari"))
        XCTAssertFalse(DoricoApplicationIdentity.matches(localizedName: nil, bundleIdentifier: nil))
    }
}
