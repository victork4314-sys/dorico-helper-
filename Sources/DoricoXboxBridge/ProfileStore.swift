#if os(macOS)
import AppKit
import Foundation
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

    private var exchangeDirectoryURL: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Dorico Xbox Bridge Profiles", isDirectory: true)
    }

    private var profilesURL: URL { directoryURL.appendingPathComponent("profiles.json") }
    private var exportedProfilesURL: URL { exchangeDirectoryURL.appendingPathComponent("Dorico-Xbox-Profiles.json") }

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
        do {
            try FileManager.default.createDirectory(at: exchangeDirectoryURL, withIntermediateDirectories: true)
            let data = try encoder.encode(profiles)
            try data.write(to: exportedProfilesURL, options: .atomic)
        } catch {
            NSSound.beep()
        }
    }

    func importProfiles() -> [ControllerProfile]? {
        do {
            try FileManager.default.createDirectory(at: exchangeDirectoryURL, withIntermediateDirectories: true)
            let keys: Set<URLResourceKey> = [.contentModificationDateKey, .isRegularFileKey]
            let files = try FileManager.default.contentsOfDirectory(
                at: exchangeDirectoryURL,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles]
            )
            let candidates = files
                .filter { $0.pathExtension.lowercased() == "json" }
                .filter { (try? $0.resourceValues(forKeys: keys).isRegularFile) == true }
                .sorted {
                    let left = (try? $0.resourceValues(forKeys: keys).contentModificationDate) ?? .distantPast
                    let right = (try? $1.resourceValues(forKeys: keys).contentModificationDate) ?? .distantPast
                    return left > right
                }
            guard let newest = candidates.first else { return nil }
            let data = try Data(contentsOf: newest)
            return try decoder.decode([ControllerProfile].self, from: data)
        } catch {
            NSSound.beep()
            return nil
        }
    }
}
#endif
