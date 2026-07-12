import AppKit
import SwiftUI
import NextDNSToolbarCore

@main
@MainActor
struct NextDNSStatsApp {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var previewWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = DashboardStore()
        menuBarController = MenuBarController(store: store)
        if ProcessInfo.processInfo.arguments.contains("--preview-window") {
            let window = NSWindow(contentViewController: NSHostingController(rootView: DashboardView(store: store)))
            window.title = "NextDNS Stats Preview"
            window.setContentSize(NSSize(width: 420, height: 640))
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.center()
            window.orderFrontRegardless()
            previewWindow = window
            store.startRefreshing()
        }
    }
}
