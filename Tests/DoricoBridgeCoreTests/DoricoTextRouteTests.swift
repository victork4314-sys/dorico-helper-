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

    func testExactLegatoDefaultUsesOnlyOrnamentsOnBaseX() {
        let profile = DefaultCatalog.legatoStyleProfile
        XCTAssertEqual(profile.action(for: BindingKey(layer: .base, input: .buttonX)), .controllerText(.ornamentsPopover))
        XCTAssertNil(profile.action(for: BindingKey(layer: .bothTriggers, input: .buttonA)))
        XCTAssertNil(profile.action(for: BindingKey(layer: .leftBumper, input: .buttonA)))
    }

    func testEveryOtherTextRouteRemainsAvailableForAddMapping() {
        let ids = [
            "xbox.text.focused", "xbox.jump.commands", "xbox.jump.goto",
            "xbox.popover.dynamics", "xbox.popover.meter", "xbox.popover.key",
            "xbox.popover.tempo", "xbox.popover.clef", "xbox.popover.playing",
            "xbox.popover.bars"
        ]
        for id in ids {
            XCTAssertNotEqual(DefaultCatalog.action(id), .none, "Add Mapping lost text route \(id)")
        }
    }
}