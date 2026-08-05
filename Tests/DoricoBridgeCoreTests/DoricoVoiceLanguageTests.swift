import XCTest
@testable import DoricoBridgeCore

final class DoricoVoiceLanguageTests: XCTestCase {
    func testBritishAndAmericanDurationsMatch() {
        XCTAssertEqual(DoricoVoiceLanguage.parseBatch("eighth note").commands.first?.label, "Eighth note")
        XCTAssertEqual(DoricoVoiceLanguage.parseBatch("quaver").commands.first?.label, "Eighth note")
        XCTAssertEqual(DoricoVoiceLanguage.parseBatch("semiquaver").commands.first?.label, "16th note")
    }

    func testImperfectPhrasesResolveWithoutExactPasswords() {
        XCTAssertEqual(DoricoVoiceLanguage.parseBatch("quater note").commands.first?.label, "Quarter note")
        XCTAssertEqual(DoricoVoiceLanguage.parseBatch("stacato").commands.first?.label, "Staccato")
    }

    func testDenseUtteranceSplitsInOrder() {
        let batch = DoricoVoiceLanguage.parseBatch("quarter note C sharp four staccato")
        XCTAssertEqual(batch.commands.map(\.label), ["Quarter note", "Enter C#4", "Staccato"])
        XCTAssertTrue(batch.unrecognizedSegments.isEmpty)
    }

    func testSpokenNumbersDriveDoricoBarsAndNavigation() {
        let add = DoricoVoiceLanguage.parseBatch("please add twenty five bars")
        XCTAssertEqual(add.commands.first?.label, "Add 25 bars")

        let move = DoricoVoiceLanguage.parseBatch("go left by a bar")
        XCTAssertEqual(move.commands.first?.label, "Move left 1 bar")

        let goTo = DoricoVoiceLanguage.parseBatch("go to bar thirty two")
        XCTAssertEqual(goTo.commands.first?.label, "Go to bar 32")
    }

    func testScoreStructureUsesMusicLanguage() {
        XCTAssertEqual(DoricoVoiceLanguage.parseBatch("time signature three four").commands.first?.label, "Time signature 3/4")
        XCTAssertEqual(DoricoVoiceLanguage.parseBatch("key signature E flat major").commands.first?.label, "Key signature e flat major")
    }

    func testThreeSampleTrainingAliasesARecognitionResult() {
        var aliases = DoricoVoiceAliasBook()
        aliases.teach(samples: ["wait note", "weight note", "ate note"], canonicalPhrase: "eighth note")
        XCTAssertEqual(DoricoVoiceLanguage.parseBatch("weight note", aliases: aliases).commands.first?.label, "Eighth note")
    }
}
