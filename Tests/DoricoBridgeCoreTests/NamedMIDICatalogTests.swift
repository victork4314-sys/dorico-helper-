import XCTest
@testable import DoricoBridgeCore

final class NamedMIDICatalogTests: XCTestCase {
    func testEveryMIDICatalogEntryContainsItsMusicalPitchName() {
        for index in 0..<512 {
            let address = MIDIAddress.address(for: index)
            let descriptor = DefaultCatalog.actionByID["midi.slot.\(index + 1)"]
            XCTAssertNotNil(descriptor)
            XCTAssertTrue(descriptor?.title.contains(address.noteName) == true)
            XCTAssertTrue(descriptor?.detail.contains(address.noteName) == true)
        }
    }
}
