#if os(macOS)
import AppKit
import Combine
import Foundation
import SwiftUI
import DoricoBridgeCore

@MainActor
final class AppModel: ObservableObject {
    enum Section: String, CaseIterable, Identifiable {
        case status = "Status"
        case mappings = "Mappings"
        case commands = "Commands"
        case profiles = "Profiles"
        case settings = "Settings"
        case diagnostics = "Diagnostics"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .status: "bolt.horizontal.circle"
            case .mappings: "point.3.connected.trianglepath.dotted"
            case .commands: "list.bullet.rectangle"
            case .profiles: "person.2.crop.square.stack"
            case .settings: "slider.horizontal.3"
            case .diagnostics: "stethoscope"
            }
        }
    }

    struct UIItem: Identifiable {
        enum Kind { case action, adjustable, info }
        var id: String
        var title: String
        var detail: String
        var kind: Kind = .action
        var activate: () -> Void = {}
        var adjust: (Int) -> Void = { _ in }
    }

    @Published var bridgeEnabled = true
    @Published var dashboardVisible = true
    @Published var selectedSection: Section = .status
    @Published var selectedRow = 0
    @Published var controllerStatus = "No Xbox controller connected"
    @Published var doricoStatus = "Dorico Pro is not running"
    @Published var accessibilityStatus = "Accessibility permission not granted"
    @Published var midiStatus = "Virtual MIDI starting"
    @Published var lastInput = "None"
    @Published var lastAction = "None"
    @Published var pointerMode = false
    @Published var profiles: [ControllerProfile] = []
    @Published var activeProfileIndex = 0
    @Published var menuCommands: [ActionDescriptor] = []
    @Published var commandFilter = ""
    @Published var selectedLayer: MappingLayer = .base
    @Published var selectedGesture: BindingGesture = .press
    @Published var captureAction: ActionDescriptor?
    @Published var captureMessage: String?
    @Published var diagnosticsLog: [String] = []

    private let store = ProfileStore()
    private let detector = DoricoDetector()
    private let accessibility = DoricoAccessibility()
    private let midi = VirtualMIDI()
    private lazy var router = ActionRouter(detector: detector, accessibility: accessibility, midi: midi, model: self)
    private lazy var controller = XboxControllerManager(model: self)
    private var gestureEngine = GestureEngine()
    private let resolver = BindingResolver()
    private var heldInputs: Set<XboxInput> = []
    private var tickTimer: Timer?
    private var statusTimer: Timer?
    private var started = false

    var activeProfile: ControllerProfile {
        get {
            guard profiles.indices.contains(activeProfileIndex) else { return DefaultCatalog.legatoStyleProfile }
            return profiles[activeProfileIndex]
        }
        set {
            guard profiles.indices.contains(activeProfileIndex) else { return }
            profiles[activeProfileIndex] = newValue
            persistProfiles()
        }
    }

    var displayedCommands: [ActionDescriptor] {
        let all = DefaultCatalog.actions + menuCommands
        guard !commandFilter.isEmpty else { return all }
        return all.filter {
            $0.title.localizedCaseInsensitiveContains(commandFilter) ||
            $0.category.localizedCaseInsensitiveContains(commandFilter) ||
            $0.detail.localizedCaseInsensitiveContains(commandFilter)
        }
    }

    var uiItems: [UIItem] {
        switch selectedSection {
        case .status: statusItems
        case .mappings: mappingItems
        case .commands: commandItems
        case .profiles: profileItems
        case .settings: settingItems
        case .diagnostics: diagnosticItems
        }
    }

    func start() {
        guard !started else { return }
        started = true
        profiles = store.loadProfiles()
        if profiles.isEmpty { profiles = [DefaultCatalog.legatoStyleProfile] }
        activeProfileIndex = min(store.loadActiveIndex(), max(0, profiles.count - 1))
        midi.start()
        controller.start()
        refreshStatus()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        statusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshStatus() }
        }
        log("Bridge started")
    }

    func receiveControllerEvent(_ event: ControllerEvent) {
        lastInput = "\(event.input.displayName) \(event.isPressed ? "pressed" : "released")"
        if event.isPressed { heldInputs.insert(event.input) } else { heldInputs.remove(event.input) }

        if let captureAction, event.isPressed {
            if event.input == .buttonB {
                self.captureAction = nil
                captureMessage = "Mapping cancelled"
                controller.haptic(.cancel)
                return
            }
            var profile = activeProfile
            profile.bindings[BindingKey(layer: selectedLayer, input: event.input, gesture: selectedGesture)] = captureAction.action
            activeProfile = profile
            captureMessage = "\(event.input.displayName) now performs \(captureAction.title) in \(selectedLayer.displayName)"
            self.captureAction = nil
            controller.haptic(.success)
            return
        }

        for emission in gestureEngine.ingest(event, profile: activeProfile) {
            dispatch(emission)
        }
    }

    private func tick() {
        for emission in gestureEngine.tick(at: ProcessInfo.processInfo.systemUptime, profile: activeProfile) {
            dispatch(emission)
        }
    }

    private func dispatch(_ emission: GestureEmission) {
        guard bridgeEnabled else { return }
        let helperActive = NSApp.isActive && dashboardVisible
        guard let action = resolver.resolve(
            emission: emission,
            heldInputs: heldInputs,
            pointerMode: pointerMode,
            helperUIActive: helperActive,
            profile: activeProfile
        ) else { return }

        lastAction = action.summary
        Task { await router.execute(action) }
    }

    func handleInternal(_ command: BridgeInternalCommand) {
        switch command {
        case .showDashboard: showDashboard()
        case .hideDashboard: hideDashboard()
        case .toggleDashboard: toggleDashboard()
        case .helperUp: navigateRows(-1)
        case .helperDown: navigateRows(1)
        case .helperLeft: adjustSelected(-1)
        case .helperRight: adjustSelected(1)
        case .helperActivate: activateSelected()
        case .helperBack: helperBack()
        case .toggleBridge: bridgeEnabled.toggle()
        case .nextProfile: changeProfile(1)
        case .previousProfile: changeProfile(-1)
        case .speakContext: NSSpeechSynthesizer().startSpeaking(currentContextDescription)
        }
    }

    func setPointerMode(_ enabled: Bool) {
        pointerMode = enabled
        captureMessage = enabled ? "Pointer mode on" : "Pointer mode off"
        controller.haptic(.soft)
    }

    func showDashboard() {
        dashboardVisible = true
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }

    func hideDashboard() {
        dashboardVisible = false
        NSApp.hide(nil)
    }

    func toggleDashboard() {
        dashboardVisible ? hideDashboard() : showDashboard()
    }

    func selectSection(_ section: Section) {
        selectedSection = section
        selectedRow = 0
    }

    func navigateRows(_ delta: Int) {
        let count = max(1, uiItems.count)
        selectedRow = (selectedRow + delta + count) % count
        controller.haptic(.tick)
    }

    func adjustSelected(_ direction: Int) {
        let items = uiItems
        guard items.indices.contains(selectedRow) else { return }
        if items[selectedRow].kind == .adjustable {
            items[selectedRow].adjust(direction)
        } else {
            let sections = Section.allCases
            if let index = sections.firstIndex(of: selectedSection) {
                selectSection(sections[(index + direction + sections.count) % sections.count])
            }
        }
    }

    func activateSelected() {
        let items = uiItems
        guard items.indices.contains(selectedRow) else { return }
        items[selectedRow].activate()
        controller.haptic(.soft)
    }

    func helperBack() {
        if captureAction != nil {
            captureAction = nil
            captureMessage = "Mapping cancelled"
            return
        }
        if selectedSection != .status {
            selectSection(.status)
        } else {
            hideDashboard()
        }
    }

    func beginCapture(_ action: ActionDescriptor) {
        captureAction = action
        captureMessage = "Press the Xbox control to assign. B cancels."
        log("Capturing input for \(action.title)")
    }

    func clearBinding(_ key: BindingKey) {
        var profile = activeProfile
        profile.bindings.removeValue(forKey: key)
        activeProfile = profile
    }

    func scanDoricoMenus() {
        do {
            menuCommands = try accessibility.scanMenuCommands(detector: detector)
            log("Scanned \(menuCommands.count) Dorico menu commands")
        } catch {
            log("Menu scan failed: \(error.localizedDescription)")
        }
    }

    func requestAccessibility() {
        accessibility.requestPermission()
        refreshStatus()
    }

    func refreshStatus() {
        controllerStatus = controller.statusText
        doricoStatus = detector.runningApplication() == nil ? "Dorico Pro is not running" : "Dorico Pro detected"
        accessibilityStatus = accessibility.isTrusted ? "Accessibility permission granted" : "Accessibility permission not granted"
        midiStatus = midi.isReady ? "Dorico Xbox Bridge MIDI source ready" : "Virtual MIDI unavailable"
    }

    func changeProfile(_ delta: Int) {
        guard !profiles.isEmpty else { return }
        activeProfileIndex = (activeProfileIndex + delta + profiles.count) % profiles.count
        store.saveActiveIndex(activeProfileIndex)
        controller.haptic(.soft)
    }

    func duplicateActiveProfile() {
        var copy = activeProfile
        copy.id = UUID()
        copy.name += " Copy"
        profiles.append(copy)
        activeProfileIndex = profiles.count - 1
        persistProfiles()
    }

    func resetActiveProfile() {
        activeProfile = DefaultCatalog.legatoStyleProfile
    }

    func exportProfiles() { store.exportProfiles(profiles) }
    func importProfiles() {
        if let imported = store.importProfiles(), !imported.isEmpty {
            profiles = imported
            activeProfileIndex = 0
            persistProfiles()
        }
    }

    func testMIDI() {
        midi.sendPulse(MIDIAddress(channel: 1, note: 60))
        log("Sent MIDI test: channel 1, note 60")
    }

    func testHaptic() { controller.haptic(.success) }

    func log(_ message: String) {
        diagnosticsLog.insert("\(Date().formatted(date: .omitted, time: .standard)) — \(message)", at: 0)
        diagnosticsLog = Array(diagnosticsLog.prefix(100))
    }

    private func persistProfiles() {
        store.saveProfiles(profiles)
        store.saveActiveIndex(activeProfileIndex)
    }

    private var currentContextDescription: String {
        let row = uiItems.indices.contains(selectedRow) ? uiItems[selectedRow].title : "No item"
        return "\(selectedSection.rawValue), \(row). \(controllerStatus). \(doricoStatus)."
    }

    private var statusItems: [UIItem] {
        [
            UIItem(id: "bridge", title: bridgeEnabled ? "Disable bridge" : "Enable bridge", detail: "Controller input is currently \(bridgeEnabled ? "enabled" : "disabled")", activate: { [weak self] in self?.bridgeEnabled.toggle() }),
            UIItem(id: "dorico", title: "Activate Dorico Pro", detail: doricoStatus, activate: { [weak self] in self?.detector.activate() }),
            UIItem(id: "access", title: "Grant Accessibility permission", detail: accessibilityStatus, activate: { [weak self] in self?.requestAccessibility() }),
            UIItem(id: "midi", title: "Dorico MIDI Learn setup", detail: midiStatus, activate: { [weak self] in self?.selectSection(.commands) }),
            UIItem(id: "scan", title: "Scan every Dorico menu command", detail: "Build a live command list from the running Dorico Pro menu bar", activate: { [weak self] in self?.scanDoricoMenus() }),
            UIItem(id: "pointer", title: pointerMode ? "Turn pointer mode off" : "Turn pointer mode on", detail: "Fallback control for visual-only areas", activate: { [weak self] in self?.setPointerMode(!(self?.pointerMode ?? false)) })
        ]
    }

    private var mappingItems: [UIItem] {
        activeProfile.bindings
            .sorted {
                if $0.key.layer != $1.key.layer { return $0.key.layer.rawValue < $1.key.layer.rawValue }
                if $0.key.input != $1.key.input { return $0.key.input.rawValue < $1.key.input.rawValue }
                return $0.key.gesture.rawValue < $1.key.gesture.rawValue
            }
            .map { key, action in
                UIItem(
                    id: "\(key.layer.rawValue).\(key.input.rawValue).\(key.gesture.rawValue)",
                    title: "\(key.layer.displayName) · \(key.input.displayName) · \(key.gesture.displayName)",
                    detail: action.summary,
                    activate: { [weak self] in self?.clearBinding(key) }
                )
            }
    }

    private var commandItems: [UIItem] {
        displayedCommands.map { command in
            UIItem(id: command.id, title: command.title, detail: "\(command.category) — \(command.detail)", activate: { [weak self] in self?.beginCapture(command) })
        }
    }

    private var profileItems: [UIItem] {
        var items = profiles.enumerated().map { index, profile in
            UIItem(id: profile.id.uuidString, title: (index == activeProfileIndex ? "✓ " : "") + profile.name, detail: "\(profile.bindings.count) bindings", activate: { [weak self] in
                self?.activeProfileIndex = index
                self?.persistProfiles()
            })
        }
        items.append(UIItem(id: "duplicate", title: "Duplicate active profile", detail: "Create an editable copy", activate: { [weak self] in self?.duplicateActiveProfile() }))
        items.append(UIItem(id: "reset", title: "Reset active profile", detail: "Restore the complete Legato-style Dorico Pro mapping", activate: { [weak self] in self?.resetActiveProfile() }))
        items.append(UIItem(id: "export", title: "Export profiles", detail: "Save all mappings as JSON", activate: { [weak self] in self?.exportProfiles() }))
        items.append(UIItem(id: "import", title: "Import profiles", detail: "Load mappings from JSON", activate: { [weak self] in self?.importProfiles() }))
        return items
    }

    private var settingItems: [UIItem] {
        let settings = activeProfile.settings
        return [
            adjustableItem(id: "layer", title: "Mapping layer", detail: selectedLayer.displayName) { [weak self] delta in self?.cycleLayer(delta) },
            adjustableItem(id: "gesture", title: "Mapping gesture", detail: selectedGesture.displayName) { [weak self] delta in self?.cycleGesture(delta) },
            adjustableItem(id: "deadzone", title: "Stick deadzone", detail: String(format: "%.2f", settings.stickDeadzone)) { [weak self] delta in self?.changeSetting { $0.stickDeadzone = min(0.85, max(0.05, $0.stickDeadzone + Float(delta) * 0.02)) } },
            adjustableItem(id: "repeatDelay", title: "Repeat delay", detail: String(format: "%.2f s", settings.repeatDelay)) { [weak self] delta in self?.changeSetting { $0.repeatDelay = min(1.5, max(0.1, $0.repeatDelay + Double(delta) * 0.05)) } },
            adjustableItem(id: "repeatRate", title: "Repeat rate", detail: String(format: "%.3f s", settings.repeatRate)) { [weak self] delta in self?.changeSetting { $0.repeatRate = min(0.4, max(0.025, $0.repeatRate + Double(delta) * 0.01)) } },
            adjustableItem(id: "pointerSpeed", title: "Pointer speed", detail: String(format: "%.0f", settings.pointerSpeed)) { [weak self] delta in self?.changeSetting { $0.pointerSpeed = min(80, max(2, $0.pointerSpeed + Double(delta) * 2)) } },
            UIItem(id: "haptics", title: settings.hapticsEnabled ? "Disable haptics" : "Enable haptics", detail: "Xbox controller feedback", activate: { [weak self] in self?.changeSetting { $0.hapticsEnabled.toggle() } }),
            UIItem(id: "frontmost", title: settings.onlyWhenDoricoFrontmost ? "Allow background Dorico control" : "Restrict commands to frontmost Dorico", detail: settings.onlyWhenDoricoFrontmost ? "Commands require Dorico to be frontmost" : "The bridge activates Dorico before commands", activate: { [weak self] in self?.changeSetting { $0.onlyWhenDoricoFrontmost.toggle() } })
        ]
    }

    private var diagnosticItems: [UIItem] {
        [
            UIItem(id: "controller", title: "Controller", detail: controllerStatus, kind: .info),
            UIItem(id: "dorico", title: "Dorico Pro", detail: doricoStatus, kind: .info),
            UIItem(id: "access", title: "Accessibility", detail: accessibilityStatus, kind: .info),
            UIItem(id: "midi", title: "Virtual MIDI", detail: midiStatus, kind: .info),
            UIItem(id: "lastInput", title: "Last Xbox input", detail: lastInput, kind: .info),
            UIItem(id: "lastAction", title: "Last routed action", detail: lastAction, kind: .info),
            UIItem(id: "haptic", title: "Test Xbox haptic", detail: "Play a confirmation pulse", activate: { [weak self] in self?.testHaptic() }),
            UIItem(id: "midiTest", title: "Test MIDI output", detail: "Send channel 1, note 60", activate: { [weak self] in self?.testMIDI() }),
            UIItem(id: "rescan", title: "Rescan Dorico menus", detail: "Refresh live menu command coverage", activate: { [weak self] in self?.scanDoricoMenus() })
        ]
    }

    private func adjustableItem(id: String, title: String, detail: String, adjust: @escaping (Int) -> Void) -> UIItem {
        UIItem(id: id, title: title, detail: detail, kind: .adjustable, activate: { adjust(1) }, adjust: adjust)
    }

    private func cycleLayer(_ delta: Int) {
        let values = MappingLayer.allCases
        let index = values.firstIndex(of: selectedLayer) ?? 0
        selectedLayer = values[(index + delta + values.count) % values.count]
    }

    private func cycleGesture(_ delta: Int) {
        let values = BindingGesture.allCases
        let index = values.firstIndex(of: selectedGesture) ?? 0
        selectedGesture = values[(index + delta + values.count) % values.count]
    }

    private func changeSetting(_ mutation: (inout ControllerSettings) -> Void) {
        var profile = activeProfile
        mutation(&profile.settings)
        activeProfile = profile
        controller.updateThresholds()
    }
}
#endif
