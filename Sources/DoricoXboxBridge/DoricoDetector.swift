#if os(macOS)
import AppKit
import Foundation
import DoricoBridgeCore

@MainActor
final class DoricoDetector {
    func runningApplication() -> NSRunningApplication? {
        let ownProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        return NSWorkspace.shared.runningApplications.first { application in
            guard application.processIdentifier != ownProcessIdentifier else { return false }
            return DoricoApplicationIdentity.matches(
                localizedName: application.localizedName,
                bundleIdentifier: application.bundleIdentifier
            )
        }
    }

    func isFrontmost() -> Bool {
        guard let dorico = runningApplication() else { return false }
        return NSWorkspace.shared.frontmostApplication?.processIdentifier == dorico.processIdentifier
    }

    @discardableResult
    func activate() -> Bool {
        guard let dorico = runningApplication() else { return false }
        return dorico.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }
}
#endif
