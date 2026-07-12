import AppKit
import SwiftUI
import NextDNSToolbarCore

@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let store: DashboardStore

    init(store: DashboardStore) {
        self.store = store
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "shield.lefthalf.filled", accessibilityDescription: "NextDNS Stats")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(togglePopover)
            button.toolTip = "NextDNS Stats"
        }

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 420, height: 640)
        popover.contentViewController = NSHostingController(rootView: DashboardView(store: store))
        popover.delegate = self

        if ProcessInfo.processInfo.arguments.contains("--open-popover") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.showPopover() }
        }
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover(attempt: Int = 0) {
        guard let button = statusItem.button, button.window != nil else {
            guard attempt < 10 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.showPopover(attempt: attempt + 1)
            }
            return
        }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        store.startRefreshing()
    }

    func popoverDidClose(_ notification: Notification) {
        store.stopRefreshing()
    }
}
