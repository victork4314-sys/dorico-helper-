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

    func testLegacyAliasesStillWork() {
        var aliases = DoricoVoiceAliasBook()
        aliases.teach(samples: ["wait note", "weight note", "ate note"], canonicalPhrase: "eighth note")
        XCTAssertEqual(DoricoVoiceLanguage.parseBatch("weight note", aliases: aliases).commands.first?.label, "Eighth note")
    }

    func testEveryDefaultCatalogActionTitleIsVoiceAddressable() {
        XCTAssertEqual(DoricoVoiceLanguage.supportedCatalogActionCount, DefaultCatalog.actions.count)
        for descriptor in DefaultCatalog.actions {
            let parsed = DoricoVoiceLanguage.catalogCommand(descriptor.title, fuzzy: false)
            XCTAssertNotNil(parsed, "Missing voice catalog action for \(descriptor.id): \(descriptor.title)")
            XCTAssertEqual(parsed?.action, descriptor.action, "Wrong voice action for \(descriptor.id)")
        }
    }

    func testNaturalCatalogAliasesResolve() {
        XCTAssertEqual(
            DoricoVoiceLanguage.parseBatch("pointer double click").commands.first?.label,
            "Pointer double-click"
        )
        XCTAssertEqual(
            DoricoVoiceLanguage.parseBatch("next accessible zone").commands.first?.label,
            "Next accessible zone"
        )
        XCTAssertEqual(
            DoricoVoiceLanguage.parseBatch("increase focused value").commands.first?.label,
            "Increase accessible value"
        )
    }

    func testSiriStyleCalibrationGeneralizesSoundCorrections() {
        var calibration = DoricoVoiceCalibrationProfile()
        calibration.learn(
            expected: "Dorico enter C sharp four then add staccato and a tie",
            heard: "Dorico enter see sharp for then add stack auto and a tie"
        )

        XCTAssertEqual(
            calibration.apply(to: "stack auto"),
            "staccato"
        )
        XCTAssertEqual(
            DoricoVoiceLanguage.parseBatch("stack auto", calibration: calibration).commands.first?.label,
            "Staccato"
        )
    }

    func testFiveDifferentSetupPhrasesCompleteOneVoiceProfile() {
        var calibration = DoricoVoiceCalibrationProfile()
        for prompt in DoricoVoiceLanguage.calibrationPrompts {
            calibration.learn(expected: prompt, heard: prompt)
        }
        XCTAssertEqual(DoricoVoiceLanguage.calibrationPrompts.count, 5)
        XCTAssertTrue(calibration.isComplete)
        XCTAssertEqual(calibration.completedPromptCount, 5)
    }

    func testMIDIActionTitlesAcceptSpokenPitchAndChannelNumbers() {
        guard let descriptor = DefaultCatalog.actions.first(where: {
            $0.title.contains("C♯-1") && $0.title.contains("Channel 1")
        }) else {
            return XCTFail("Expected the catalog to contain MIDI C-sharp minus one on channel one")
        }
        let command = DoricoVoiceLanguage.parseBatch("midi learn C sharp minus one channel one").commands.first
        XCTAssertEqual(command?.action, descriptor.action)
    }

    func testExplicitDoricoCommandFallsThroughToJumpBar() {
        let command = DoricoVoiceLanguage.parseBatch("Dorico command open print mode options").commands.first
        XCTAssertEqual(command?.label, "Dorico command: open print mode options")
        guard case .sequence(let steps) = command?.action else {
            return XCTFail("Expected a Jump Bar action sequence")
        }
        XCTAssertEqual(steps.count, 4)
    }

    func testSpeechHintsIncludeEveryCatalogTitle() {
        let hints = Set(DoricoVoiceLanguage.speechHints)
        for descriptor in DefaultCatalog.actions {
            XCTAssertTrue(hints.contains(descriptor.title), "Missing speech hint for \(descriptor.id)")
        }
    }

    func testRuntimeContextualStringsNeverExceedAppleLimit() {
        let hundreds = (0..<700).map { "Dorico action \($0)" }
        let result = DoricoVoiceRuntimePolicy.contextualStrings(priority: [], fallback: hundreds)
        XCTAssertEqual(result.count, DoricoVoiceRuntimePolicy.maximumContextualStrings)
        XCTAssertEqual(result.first, "Dorico action 0")
        XCTAssertEqual(result.last, "Dorico action 99")
    }

    func testRuntimeContextualStringsPrioritizeAndDeduplicateSetupTerms() {
        let result = DoricoVoiceRuntimePolicy.contextualStrings(
            priority: ["staccato", "C sharp", "STACCATO", "  fermata  "],
            fallback: ["quarter note", "c sharp"],
            limit: 4
        )
        XCTAssertEqual(result, ["staccato", "C sharp", "fermata", "quarter note"])
    }

    func testRuntimeAudioInputValidationRejectsFatalTapFormats() {
        XCTAssertFalse(DoricoVoiceRuntimePolicy.isUsableAudioInput(sampleRate: 0, channelCount: 1))
        XCTAssertFalse(DoricoVoiceRuntimePolicy.isUsableAudioInput(sampleRate: 48_000, channelCount: 0))
        XCTAssertFalse(DoricoVoiceRuntimePolicy.isUsableAudioInput(sampleRate: .infinity, channelCount: 2))
        XCTAssertTrue(DoricoVoiceRuntimePolicy.isUsableAudioInput(sampleRate: 48_000, channelCount: 1))
    }
}
