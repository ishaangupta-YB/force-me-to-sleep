import AppKit
import SwiftUI

/// Wires the app to the system: hides the Dock icon, listens to sleep/wake
/// notifications, requests notification permission, and bootstraps the
/// reminder coordinator. All cross-cutting work lives here so the SwiftUI
/// scenes stay pure UI.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    let settings = SettingsStore.shared
    let quotes = QuoteLibrary.shared
    let notifications = NotificationManager()
    lazy var overlay: ShutdownOverlayWindow = .shared
    lazy var coordinator: ReminderCoordinator = ReminderCoordinator(
        settings: settings,
        quotes: quotes,
        notifications: notifications,
        overlay: overlay
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        SnoozeRelay.shared.coordinator = coordinator
        notifications.requestAuthorization()
        coordinator.bootstrap()

        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(workspaceWillSleep),
                       name: NSWorkspace.willSleepNotification, object: nil)
        nc.addObserver(self, selector: #selector(workspaceDidWake),
                       name: NSWorkspace.didWakeNotification, object: nil)
        nc.addObserver(self, selector: #selector(workspaceScreensDidWake),
                       name: NSWorkspace.screensDidWakeNotification, object: nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator.dismissTonight()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // When the user re-opens the app from Spotlight, surface the settings window.
        return true
    }

    @objc private func workspaceWillSleep() {
        Task { @MainActor in coordinator.systemWillSleep() }
    }

    @objc private func workspaceDidWake() {
        Task { @MainActor in coordinator.systemDidWake() }
    }

    @objc private func workspaceScreensDidWake() {
        Task { @MainActor in coordinator.systemDidWake() }
    }
}
