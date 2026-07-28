import Foundation

public enum DoricoApplicationIdentity {
    public static func matches(localizedName: String?, bundleIdentifier: String?) -> Bool {
        let bundle = bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if bundle.hasPrefix("com.steinberg.dorico") || bundle.contains(".steinberg.dorico") {
            return true
        }

        let name = localizedName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if name == "dorico" || name == "dorico pro" {
            return true
        }

        for prefix in ["dorico ", "dorico pro "] where name.hasPrefix(prefix) {
            let suffix = name.dropFirst(prefix.count)
            if !suffix.isEmpty, suffix.allSatisfy({ $0.isNumber || $0 == "." }) {
                return true
            }
        }
        return false
    }
}
