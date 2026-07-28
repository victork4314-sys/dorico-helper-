import XCTest
@testable import DoricoBridgeCore

final class ModifierOnlyShortcutTests: XCTestCase {
    func testEveryNonEmptyModifierSetCanBeRepresentedWithoutARegularKey() {
        let modifiers = KeyModifier.allCases
        for mask in 1..<(1 << modifiers.count) {
            var selected = Set<KeyModifier>()
            for (index, modifier) in modifiers.enumerated() where mask & (1 << index) != 0 {
                selected.insert(modifier)
            }
            let shortcut = KeyChord(modifiersOnly: selected)
            XCTAssertTrue(shortcut.isModifierOnly)
            XCTAssertEqual(shortcut.modifiers, selected)
        }
    }
}
