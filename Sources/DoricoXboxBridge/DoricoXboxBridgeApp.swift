#if os(macOS)
import SwiftUI
import DoricoBridgeCore

@main
struct DoricoXboxBridgeApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Dorico Xbox Bridge", id: "dashboard") {
            ContentView(model: model)
                .frame(minWidth: 860, minHeight: 560)
                .onAppear { model.start() }
        }
        .defaultSize(width: 980, height: 680)

        MenuBarExtra("Dorico Xbox Bridge", systemImage: model.bridgeEnabled ? "gamecontroller.fill" : "gamecontroller") {
            Button(model.dashboardVisible ? "Hide Dashboard" : "Show Dashboard") {
                model.toggleDashboard()
            }
            Button(model.bridgeEnabled ? "Disable Bridge" : "Enable Bridge") {
                model.bridgeEnabled.toggle()
            }
            Divider()
            Text(model.controllerStatus)
            Text(model.doricoStatus)
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
    }
}
#else
import Foundation

@main
struct UnsupportedPlatformMain {
    static func main() {
        print("Dorico Xbox Bridge is a native macOS app. Core logic is testable on this platform; the app target builds on macOS CI.")
    }
}
#endif
