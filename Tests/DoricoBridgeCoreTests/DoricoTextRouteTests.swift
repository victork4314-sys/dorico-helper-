import XCTest
@testable import DoricoBridgeCore

final class DoricoTextRouteTests: XCTestCase {
    func testEveryControllerTextRouteIsInTheCommandCatalog() {
        let expected: [String: DoricoTextRoute] = [
            "xbox.text.focused": .focusedField,
            "xbox.jump.commands": .jumpBarCommands,
            "xbox.jump.goto": .jumpBarGoTo,
            "xbox.popover.dynamics": .dynamicsPopover,
            "xbox.popover.ornaments": .ornamentsPopover,
            "xbox.popover.meter": .meterPopover,
            "xbox.popover.key": .keySignaturePopover,
            "xbox.popover.tempo": .tempoPopover,
            "xbox.popover.clef": .clefPopover,
            "xbox.popover.playing": .playingTechniquesPopover,
            "xbox.popover.bars": .barsAndBarlinesPopover
        ]

        for (id, route) in expected {
            XCTAssertEqual(DefaultCatalog.action(id), .controllerText(route), "Wrong or missing controller text action: \(id)")
        }
    }

    func testDefaultXboxProfileRoutesAllTextDrivenPopoversThroughControllerKeyboard() {
        let profile = DefaultCatalog.legatoStyleProfile
        let expected: [(XboxInput, DoricoTextRoute)] = [
            (.buttonA, .dynamicsPopover),
            (.buttonB, .ornamentsPopover),
            (.buttonX, .meterPopover),
            (.buttonY, .keySignaturePopover),
            (.dpadUp, .tempoPopover),
            (.dpadDown, .clefPopover),
            (.dpadLeft, .playingTechniquesPopover),
            (.dpadRight, .barsAndBarlinesPopover)
        ]

        for (input, route) in expected {
            XCTAssertEqual(
                profile.action(for: BindingKey(layer: .bothTriggers, input: input)),
                .controllerText(route),
                "Both-trigger route is wrong for \(input.displayName)"
            )
        }
    }

    func testDefaultLeftBumperLayerProvidesFocusedTextAndBothJumpBarModes() {
        let profile = DefaultCatalog.legatoStyleProfile
        XCTAssertEqual(profile.action(for: BindingKey(layer: .leftBumper, input: .buttonA)), .controllerText(.focusedField))
        XCTAssertEqual(profile.action(for: BindingKey(layer: .leftBumper, input: .buttonX)), .controllerText(.jumpBarCommands))
        XCTAssertEqual(profile.action(for: BindingKey(layer: .leftBumper, input: .buttonY)), .controllerText(.jumpBarGoTo))
    }
}
