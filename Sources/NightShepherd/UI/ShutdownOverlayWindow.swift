import AppKit
import SwiftUI

/// Multi-screen, full-screen, top-most overlay used for the third strike.
/// Uses `.screenSaver` window level so it covers everything except the Force
/// Quit dialog. One window per attached display, all dismissed together.
@MainActor
final class ShutdownOverlayWindow: OverlayPresenting {

    static let shared = ShutdownOverlayWindow()

    private var windows: [NSWindow] = []

    var isPresented: Bool { !windows.isEmpty }

    private init() {}

    func present(quote: Quote, onDismiss: @escaping () -> Void) {
        dismiss()

        let screens = NSScreen.screens.isEmpty ? [NSScreen.main].compactMap { $0 } : NSScreen.screens
        windows = screens.map { screen in
            let window = OverlayWindow(
                contentRect: screen.frame,
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false,
                screen: screen)
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.isReleasedWhenClosed = false
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true

            let host = NSHostingView(rootView: ShutdownOverlayView(
                quote: quote,
                onDismiss: { [weak self] in
                    self?.dismiss()
                    onDismiss()
                },
                onSnooze: { [weak self] in
                    self?.dismiss()
                    SnoozeRelay.shared.notify(minutes: 5)
                }
            )
            .environmentObject(SettingsStore.shared))
            host.autoresizingMask = [.width, .height]
            window.contentView = host

            window.makeKeyAndOrderFront(nil)
            return window
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss() {
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
    }
}

/// Borderless overlay window that still accepts key events so the buttons
/// respond to Return/Esc and VoiceOver.
private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Tiny pub-sub so the overlay's "Snooze" button can talk back to the
/// coordinator without holding a direct reference.
@MainActor
final class SnoozeRelay {
    static let shared = SnoozeRelay()
    weak var coordinator: ReminderCoordinator?

    func notify(minutes: Int) {
        coordinator?.userSnoozed(minutes: minutes)
    }
}
