#if os(macOS)
import AppKit
import CoreGraphics
import Foundation

@MainActor
final class FocusSelectorOverlay: NSObject {
    private enum Presentation {
        case outline
        case marker
    }

    private let panel: NSPanel
    private let selectorView: FocusSelectorView

    override init() {
        selectorView = FocusSelectorView(frame: .zero)
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.contentView = selectorView
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeApplicationChanged(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    func show(axFrame: CGRect, title: String) {
        guard axFrame.width > 1,
              axFrame.height > 1,
              let converted = Self.cocoaFrame(fromAXFrame: axFrame) else {
            hide()
            return
        }

        let screenFrame = converted.screen.visibleFrame
        let target = converted.frame.intersection(screenFrame)
        guard !target.isNull, target.width > 1, target.height > 1 else {
            hide()
            return
        }

        let isVeryLarge = target.width > screenFrame.width * 0.72 || target.height > screenFrame.height * 0.72
        let presentation: Presentation = isVeryLarge ? .marker : .outline
        let displayFrame: CGRect

        if isVeryLarge {
            let width = min(max(150, target.width * 0.32), 280)
            displayFrame = CGRect(
                x: target.minX + 10,
                y: target.maxY - 40,
                width: min(width, max(80, target.width - 20)),
                height: 30
            ).intersection(screenFrame)
        } else {
            displayFrame = target.insetBy(dx: -6, dy: -6).intersection(screenFrame)
        }

        guard !displayFrame.isNull, displayFrame.width > 1, displayFrame.height > 1 else {
            hide()
            return
        }

        selectorView.update(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            markerOnly: presentation == .marker
        )
        panel.setFrame(displayFrame, display: true)
        panel.alphaValue = 1
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    @objc private func activeApplicationChanged(_ notification: Notification) {
        guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        let identity = "\(application.localizedName ?? "") \(application.bundleIdentifier ?? "")".lowercased()
        if !identity.contains("dorico") {
            hide()
        }
    }

    private static func cocoaFrame(fromAXFrame axFrame: CGRect) -> (frame: CGRect, screen: NSScreen)? {
        let center = CGPoint(x: axFrame.midX, y: axFrame.midY)

        for screen in NSScreen.screens {
            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                continue
            }
            let displayID = CGDirectDisplayID(screenNumber.uint32Value)
            let quartzBounds = CGDisplayBounds(displayID)
            guard quartzBounds.contains(center) || quartzBounds.intersects(axFrame) else { continue }

            let cocoaFrame = CGRect(
                x: screen.frame.minX + (axFrame.minX - quartzBounds.minX),
                y: screen.frame.maxY - (axFrame.minY - quartzBounds.minY) - axFrame.height,
                width: axFrame.width,
                height: axFrame.height
            )
            return (cocoaFrame, screen)
        }

        guard let screen = NSScreen.main,
              let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        let quartzBounds = CGDisplayBounds(CGDirectDisplayID(screenNumber.uint32Value))
        return (
            CGRect(
                x: screen.frame.minX + (axFrame.minX - quartzBounds.minX),
                y: screen.frame.maxY - (axFrame.minY - quartzBounds.minY) - axFrame.height,
                width: axFrame.width,
                height: axFrame.height
            ),
            screen
        )
    }
}

@MainActor
private final class FocusSelectorView: NSView {
    private var title = ""
    private var markerOnly = false

    override var isOpaque: Bool { false }

    func update(title: String, markerOnly: Bool) {
        self.title = title.isEmpty ? "Dorico selection" : title
        self.markerOnly = markerOnly
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let accent = NSColor.controlAccentColor
        let outlineRect = bounds.insetBy(dx: 2.5, dy: 2.5)
        let outline = NSBezierPath(roundedRect: outlineRect, xRadius: markerOnly ? 8 : 7, yRadius: markerOnly ? 8 : 7)

        if markerOnly {
            accent.withAlphaComponent(0.94).setFill()
            outline.fill()
        } else {
            NSColor.black.withAlphaComponent(0.32).setStroke()
            outline.lineWidth = 5
            outline.stroke()
            accent.withAlphaComponent(0.98).setStroke()
            outline.lineWidth = 2.5
            outline.stroke()
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: markerOnly ? NSColor.white : NSColor.labelColor,
            .paragraphStyle: paragraph
        ]

        let badgeHeight: CGFloat = 21
        let badgeRect = NSRect(
            x: 6,
            y: markerOnly ? 4.5 : max(5, bounds.height - badgeHeight - 6),
            width: max(1, bounds.width - 12),
            height: badgeHeight
        )

        if !markerOnly {
            let badge = NSBezierPath(roundedRect: badgeRect, xRadius: 6, yRadius: 6)
            NSColor.windowBackgroundColor.withAlphaComponent(0.92).setFill()
            badge.fill()
            accent.withAlphaComponent(0.8).setStroke()
            badge.lineWidth = 1
            badge.stroke()
        }

        NSString(string: title).draw(
            in: badgeRect.insetBy(dx: 7, dy: 3),
            withAttributes: attributes
        )
    }
}
#endif
