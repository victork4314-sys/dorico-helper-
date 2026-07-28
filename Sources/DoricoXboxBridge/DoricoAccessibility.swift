#if os(macOS)
import ApplicationServices
import AppKit
import Foundation
import DoricoBridgeCore

@MainActor
final class DoricoAccessibility {
    enum BridgeError: LocalizedError {
        case permissionRequired
        case doricoNotRunning
        case menuUnavailable
        case commandNotFound(String)
        case noFocusedElement
        case noFocusableElements

        var errorDescription: String? {
            switch self {
            case .permissionRequired: "Accessibility permission is required"
            case .doricoNotRunning: "Dorico Pro is not running"
            case .menuUnavailable: "Dorico Pro menu bar is unavailable"
            case .commandNotFound(let path): "Dorico command not found: \(path)"
            case .noFocusedElement: "Dorico has no focused accessible element"
            case .noFocusableElements: "No accessible Dorico controls were found"
            }
        }
    }

    private struct Candidate {
        var element: AXUIElement
        var frame: CGRect
        var title: String
    }

    var isTrusted: Bool { AXIsProcessTrusted() }

    func requestPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    func scanMenuCommands(detector: DoricoDetector) throws -> [ActionDescriptor] {
        guard isTrusted else { throw BridgeError.permissionRequired }
        guard let app = detector.runningApplication() else { throw BridgeError.doricoNotRunning }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        guard let menuBar: AXUIElement = attribute(application, kAXMenuBarAttribute) else {
            throw BridgeError.menuUnavailable
        }

        var commands: [ActionDescriptor] = []
        var seen = Set<String>()
        for child in children(of: menuBar) {
            collectMenuCommands(from: child, path: [], output: &commands, seen: &seen, depth: 0)
        }
        return commands.sorted {
            if $0.category != $1.category { return $0.category < $1.category }
            return $0.title < $1.title
        }
    }

    func performMenuPath(_ path: [String], detector: DoricoDetector) throws {
        guard isTrusted else { throw BridgeError.permissionRequired }
        guard let app = detector.runningApplication() else { throw BridgeError.doricoNotRunning }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        guard let menuBar: AXUIElement = attribute(application, kAXMenuBarAttribute) else {
            throw BridgeError.menuUnavailable
        }
        guard let target = findMenuElement(path: path, in: menuBar, depth: 0) else {
            throw BridgeError.commandNotFound(path.joined(separator: " › "))
        }
        let error = AXUIElementPerformAction(target, kAXPressAction as CFString)
        if error != .success { throw BridgeError.commandNotFound(path.joined(separator: " › ")) }
    }

    func perform(_ operation: AccessibilityOperation, detector: DoricoDetector) throws {
        guard isTrusted else { throw BridgeError.permissionRequired }
        guard let app = detector.runningApplication() else { throw BridgeError.doricoNotRunning }
        let application = AXUIElementCreateApplication(app.processIdentifier)

        switch operation {
        case .move(let direction):
            try moveFocus(direction, application: application)
        case .pressFocused:
            try performOnFocused(application: application, preferredActions: [kAXPressAction])
        case .incrementFocused:
            try performOnFocused(application: application, preferredActions: [kAXIncrementAction])
        case .decrementFocused:
            try performOnFocused(application: application, preferredActions: [kAXDecrementAction])
        case .showFocusedMenu:
            try performOnFocused(application: application, preferredActions: [kAXShowMenuAction, kAXPressAction])
        case .scanNext:
            try scanFocus(application: application, delta: 1)
        case .scanPrevious:
            try scanFocus(application: application, delta: -1)
        }
    }

    private func collectMenuCommands(
        from element: AXUIElement,
        path: [String],
        output: inout [ActionDescriptor],
        seen: inout Set<String>,
        depth: Int
    ) {
        guard depth < 12 else { return }
        let title = normalizedTitle(element)
        let role: String = attribute(element, kAXRoleAttribute) ?? ""
        let nextPath = title.isEmpty ? path : path + [title]
        let childElements = children(of: element)
        let actions = actionNames(of: element)

        if role == kAXMenuItemRole as String,
           !title.isEmpty,
           actions.contains(kAXPressAction as String),
           childElements.isEmpty || !containsMenuItems(childElements) {
            let key = nextPath.joined(separator: "\u{1F}")
            if seen.insert(key).inserted {
                let category = nextPath.dropLast().first ?? "Dorico menu"
                output.append(ActionDescriptor(
                    id: "menu." + stableIdentifier(key),
                    title: title,
                    category: category,
                    detail: nextPath.joined(separator: " › "),
                    action: .menuPath(nextPath)
                ))
            }
        }

        for child in childElements {
            collectMenuCommands(from: child, path: nextPath, output: &output, seen: &seen, depth: depth + 1)
        }
    }

    private func findMenuElement(path: [String], in root: AXUIElement, depth: Int) -> AXUIElement? {
        guard !path.isEmpty, depth < 16 else { return nil }
        let desired = path[0]

        for child in children(of: root) where normalizedTitle(child) == desired {
            if path.count == 1 { return child }
            _ = AXUIElementPerformAction(child, kAXPressAction as CFString)
            RunLoop.current.run(until: Date().addingTimeInterval(0.025))
            if let found = findMenuElement(path: Array(path.dropFirst()), in: child, depth: depth + 1) {
                return found
            }
            for descendant in children(of: child) {
                if let found = findMenuElement(path: Array(path.dropFirst()), in: descendant, depth: depth + 1) {
                    return found
                }
            }
        }

        for child in children(of: root) {
            if let found = findMenuElement(path: path, in: child, depth: depth + 1) { return found }
        }
        return nil
    }

    private func moveFocus(_ direction: FocusDirection, application: AXUIElement) throws {
        guard let current: AXUIElement = attribute(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute) ?? attribute(application, kAXFocusedUIElementAttribute) else {
            throw BridgeError.noFocusedElement
        }
        guard let window: AXUIElement = attribute(application, kAXFocusedWindowAttribute) else {
            throw BridgeError.noFocusableElements
        }
        let candidates = collectCandidates(from: window)
        guard !candidates.isEmpty else { throw BridgeError.noFocusableElements }

        let origin = frame(of: current)?.center ?? candidates[0].frame.center
        let filtered = candidates.filter { candidate in
            guard !CFEqual(candidate.element, current) else { return false }
            let point = candidate.frame.center
            switch direction {
            case .left: point.x < origin.x - 1
            case .right: point.x > origin.x + 1
            case .up: point.y < origin.y - 1
            case .down: point.y > origin.y + 1
            }
        }

        let selected = filtered.min { lhs, rhs in
            directionalScore(lhs.frame.center, from: origin, direction: direction) < directionalScore(rhs.frame.center, from: origin, direction: direction)
        } ?? wrapCandidate(candidates, direction: direction)

        guard let selected else { throw BridgeError.noFocusableElements }
        setFocused(selected.element)
    }

    private func scanFocus(application: AXUIElement, delta: Int) throws {
        guard let window: AXUIElement = attribute(application, kAXFocusedWindowAttribute) else {
            throw BridgeError.noFocusableElements
        }
        let candidates = collectCandidates(from: window).sorted {
            if abs($0.frame.midY - $1.frame.midY) > 8 { return $0.frame.midY < $1.frame.midY }
            return $0.frame.midX < $1.frame.midX
        }
        guard !candidates.isEmpty else { throw BridgeError.noFocusableElements }
        let current: AXUIElement? = attribute(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute)
        let currentIndex = current.flatMap { element in candidates.firstIndex { CFEqual($0.element, element) } } ?? (delta > 0 ? -1 : 0)
        let next = (currentIndex + delta + candidates.count) % candidates.count
        setFocused(candidates[next].element)
    }

    private func performOnFocused(application: AXUIElement, preferredActions: [String]) throws {
        guard let focused: AXUIElement = attribute(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute) ?? attribute(application, kAXFocusedUIElementAttribute) else {
            throw BridgeError.noFocusedElement
        }
        let supported = actionNames(of: focused)
        for action in preferredActions where supported.contains(action) {
            if AXUIElementPerformAction(focused, action as CFString) == .success { return }
        }
        throw BridgeError.noFocusedElement
    }

    private func collectCandidates(from root: AXUIElement) -> [Candidate] {
        var output: [Candidate] = []
        var visited = 0

        func walk(_ element: AXUIElement, depth: Int) {
            guard depth < 24, visited < 4000 else { return }
            visited += 1

            let hidden: Bool = attribute(element, kAXHiddenAttribute) ?? false
            if !hidden, let frame = frame(of: element), frame.width > 1, frame.height > 1 {
                let actions = actionNames(of: element)
                let role: String = attribute(element, kAXRoleAttribute) ?? ""
                let focusable = isSettable(element, kAXFocusedAttribute) ||
                    actions.contains(kAXPressAction as String) ||
                    actions.contains(kAXIncrementAction as String) ||
                    actions.contains(kAXShowMenuAction as String) ||
                    [kAXButtonRole, kAXCheckBoxRole, kAXRadioButtonRole, kAXTextFieldRole, kAXSliderRole, kAXPopUpButtonRole, kAXMenuButtonRole, kAXCellRole, kAXRowRole].map { $0 as String }.contains(role)
                if focusable {
                    output.append(Candidate(element: element, frame: frame, title: normalizedTitle(element)))
                }
            }
            for child in children(of: element) { walk(child, depth: depth + 1) }
        }

        walk(root, depth: 0)
        return output
    }

    private func wrapCandidate(_ candidates: [Candidate], direction: FocusDirection) -> Candidate? {
        switch direction {
        case .left: candidates.max { $0.frame.midX < $1.frame.midX }
        case .right: candidates.min { $0.frame.midX < $1.frame.midX }
        case .up: candidates.max { $0.frame.midY < $1.frame.midY }
        case .down: candidates.min { $0.frame.midY < $1.frame.midY }
        }
    }

    private func directionalScore(_ point: CGPoint, from origin: CGPoint, direction: FocusDirection) -> CGFloat {
        let dx = abs(point.x - origin.x)
        let dy = abs(point.y - origin.y)
        switch direction {
        case .left, .right: dx + dy * 0.42
        case .up, .down: dy + dx * 0.42
        }
    }

    private func setFocused(_ element: AXUIElement) {
        if isSettable(element, kAXFocusedAttribute) {
            AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        } else {
            _ = AXUIElementPerformAction(element, kAXRaiseAction as CFString)
        }
    }

    private func normalizedTitle(_ element: AXUIElement) -> String {
        let values: [String?] = [
            attribute(element, kAXTitleAttribute),
            attribute(element, kAXDescriptionAttribute),
            attribute(element, kAXValueAttribute),
            attribute(element, kAXHelpAttribute)
        ]
        return values.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty } ?? ""
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        attribute(element, kAXChildrenAttribute) ?? []
    }

    private func actionNames(of element: AXUIElement) -> [String] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success else { return [] }
        return names as? [String] ?? []
    }

    private func isSettable(_ element: AXUIElement, _ attributeName: String) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, attributeName as CFString, &settable) == .success && settable.boolValue
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        guard let positionValue: AXValue = attribute(element, kAXPositionAttribute),
              let sizeValue: AXValue = attribute(element, kAXSizeAttribute) else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &position),
              AXValueGetValue(sizeValue, .cgSize, &size) else { return nil }
        return CGRect(origin: position, size: size)
    }

    private func containsMenuItems(_ elements: [AXUIElement]) -> Bool {
        elements.contains { element in
            let role: String = attribute(element, kAXRoleAttribute) ?? ""
            return role == kAXMenuRole as String || role == kAXMenuItemRole as String || containsMenuItems(children(of: element))
        }
    }

    private func stableIdentifier(_ text: String) -> String {
        var hash: UInt64 = 1469598103934665603
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return String(hash, radix: 16)
    }

    private func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
#endif
