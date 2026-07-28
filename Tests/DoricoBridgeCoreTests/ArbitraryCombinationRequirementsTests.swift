import XCTest
@testable import DoricoBridgeCore

final class ArbitraryCombinationRequirementsTests: XCTestCase {
    func testAllIndependentPhysicalButtonsFitInOneExactBinding() {
        let everyButton: Set<XboxInput> = [
            .buttonA, .buttonB, .buttonX, .buttonY,
            .leftBumper, .rightBumper, .leftTrigger, .rightTrigger,
            .leftThumbstickButton, .rightThumbstickButton,
            .menu, .view, .guide
        ]
        let key = BindingKey(inputs: everyButton)
        XCTAssertEqual(key.inputs, everyButton)
        XCTAssertEqual(key.orderedInputs.count, everyButton.count)
    }

    func testSymbolsAndEverySupportedModifierRemainLiteral() {
        let symbols = ["#", "+", "=", "[", "]", "\\", ";", "'", ",", ".", "/", "-", "`", "~", "?", "|"]
        for (index, symbol) in symbols.enumerated() {
            let chord = KeyChord(
                capturedKeyCode: UInt16(index),
                characters: symbol,
                modifiers: [.command, .shift, .option, .control, .function, .capsLock]
            )
            XCTAssertEqual(chord.capturedCharacters, symbol)
            XCTAssertTrue(chord.displayName.hasSuffix(symbol))
        }
    }

    func testSequencePreservesCustomOrderAndDelays() {
        let first = CommandStep(.keyChord(KeyChord("n", modifiers: [.shift])), delayMilliseconds: 0)
        let second = CommandStep(.midiPulse(MIDIAddress(channel: 1, note: 60)), delayMilliseconds: 125)
        let third = CommandStep(.pointer(.leftClick), delayMilliseconds: 25)
        let sequence = CommandAction.sequence([first, second, third])

        guard case .sequence(let steps) = sequence else {
            return XCTFail("Expected a sequence")
        }
        XCTAssertEqual(steps, [first, second, third])
        XCTAssertEqual(steps.map(\.delayMilliseconds), [0, 125, 25])
    }
}
