import XCTest
@testable import DoricoBridgeCore

final class KeyboardShortcutAndSequenceTests: XCTestCase {
    func testAllKeyboardModifiersCanExistTogether() {
        let modifiers = Set(KeyModifier.allCases)
        let shortcut = KeyChord(capturedKeyCode: 20, characters: "#", modifiers: modifiers)
        XCTAssertEqual(shortcut.modifiers, modifiers)
        XCTAssertEqual(shortcut.displayName, "⌃ + ⌥ + ⇧ + ⌘ + fn + ⇪ + #")
    }

    func testModifierOnlyShortcutContainsNoFakeKey() {
        let shortcut = KeyChord(modifiersOnly: [.command, .shift])
        XCTAssertTrue(shortcut.isModifierOnly)
        XCTAssertEqual(shortcut.key, "")
        XCTAssertNil(shortcut.virtualKeyCode)
        XCTAssertEqual(shortcut.displayName, "⇧ + ⌘")
    }

    func testCapturedPhysicalKeyCodeWinsOverLegacyName() {
        let shortcut = KeyChord(capturedKeyCode: 42, characters: "\\", modifiers: [.option])
        XCTAssertEqual(shortcut.virtualKeyCode, 42)
        XCTAssertEqual(shortcut.capturedCharacters, "\\")
        XCTAssertEqual(shortcut.displayName, "⌥ + \\")
    }

    func testSequenceMayNestAnySupportedActionKinds() throws {
        let nested = CommandAction.sequence([
            CommandStep(.keyChord(KeyChord("n", modifiers: [.shift]))),
            CommandStep(.controllerText(.ornamentsPopover), delayMilliseconds: 30),
            CommandStep(.typeText("tr"), delayMilliseconds: 40),
            CommandStep(.midiPulse(MIDIAddress(channel: 3, note: 66)), delayMilliseconds: 50),
            CommandStep(.menuPath(["Edit", "Delete"]), delayMilliseconds: 60),
            CommandStep(.accessibility(.pressFocused), delayMilliseconds: 70),
            CommandStep(.pointer(.doubleClick), delayMilliseconds: 80),
            CommandStep(.internalCommand(.showDashboard), delayMilliseconds: 90)
        ])
        let data = try JSONEncoder().encode(nested)
        XCTAssertEqual(try JSONDecoder().decode(CommandAction.self, from: data), nested)
    }
}
