#if os(macOS)
import AppKit
import Foundation
import UniformTypeIdentifiers
import DoricoBridgeCore

@MainActor
final class ProfileStore {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
    private let decoder = JSONDecoder()

    private var directoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("DoricoXboxBridge", isDirectory: true)
    }

    private var profilesURL: URL { directoryURL.appendingPathComponent("profiles.json") }

    func loadProfiles() -> [ControllerProfile] {
        guard let data = try? Data(contentsOf: profilesURL),
              let profiles = try? decoder.decode([ControllerProfile].self, from: data) else {
            return [DefaultCatalog.legatoStyleProfile]
        }
        return profiles
    }

    func saveProfiles(_ profiles: [ControllerProfile]) {
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let data = try encoder.encode(profiles)
            try data.write(to: profilesURL, options: .atomic)
        } catch {
            NSSound.beep()
        }
    }

    func loadActiveIndex() -> Int {
        UserDefaults.standard.integer(forKey: "activeProfileIndex")
    }

    func saveActiveIndex(_ index: Int) {
        UserDefaults.standard.set(index, forKey: "activeProfileIndex")
    }

    func exportProfiles(_ profiles: [ControllerProfile]) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Dorico-Xbox-Profiles.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if let data = try? encoder.encode(profiles) {
            try? data.write(to: url, options: .atomic)
        }
    }

    func importProfiles() -> [ControllerProfile]? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode([ControllerProfile].self, from: data)
    }
}
#endif
