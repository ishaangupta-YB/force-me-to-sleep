import SwiftUI

@main
struct NightShepherdApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            menuBarContent
        } label: {
            Image(systemName: "moon.stars")
                .accessibilityLabel("Night Shepherd menu")
        }
        .menuBarExtraStyle(.window)

        Settings {
            RootSettingsContainer()
                .environmentObject(delegate.settings)
                .environmentObject(delegate.coordinator)
                .environmentObject(delegate.notifications)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Night Shepherd") {
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
            }
            CommandGroup(after: .appSettings) {
                Button("Trigger Reminder Now") {
                    delegate.coordinator.triggerSleepNow()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])

                Button("Show Test Banner Now") {
                    delegate.notifications.showTestBanner()
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])
            }
        }
    }

    @ViewBuilder
    private var menuBarContent: some View {
        MenuBarContent()
            .environmentObject(delegate.settings)
            .environmentObject(delegate.coordinator)
            .environmentObject(delegate.notifications)
    }
}

/// Switches between the onboarding flow and the tabbed settings on first launch.
struct RootSettingsContainer: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        Group {
            if settings.onboardingComplete {
                SettingsView()
            } else {
                OnboardingView(onComplete: { settings.onboardingComplete = true })
            }
        }
        .frame(minWidth: 560, minHeight: 460)
    }
}
