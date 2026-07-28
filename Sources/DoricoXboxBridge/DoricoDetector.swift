#if os(macOS)
import AppKit
import Foundation

@MainActor
final class DoricoDetector {
    func runningApplication() -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { application in
            let name = application.localizedName?.lowercased() ?? ""
            let bundle = application.bundleIdentifier?.lowercased() ?? ""
            return name.contains("dorico") || bundle.contains("steinberg.dorico")
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
