import XCTest
@testable import DoricoBridgeCore

final class SymbolShortcutTests: XCTestCase {
    func testEveryPrintableASCIICharacterCanBeStoredLiterally() {
        for scalarValue in 32...126 {
            let scalar = UnicodeScalar(scalarValue)!
            let symbol = String(Character(scalar))
            let shortcut = KeyChord(capturedKeyCode: UInt16(scalarValue), characters: symbol, modifiers: [.command])
            XCTAssertEqual(shortcut.capturedCharacters, symbol)
            XCTAssertEqual(shortcut.virtualKeyCode, UInt16(scalarValue))
        }
    }
}
