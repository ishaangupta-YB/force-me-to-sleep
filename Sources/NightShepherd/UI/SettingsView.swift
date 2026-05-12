import SwiftUI
import AppKit
import UserNotifications
import ServiceManagement

/// Settings window content. Organised into four tabs that respect the macOS
/// HIG: Tab keyboard navigation, semantic fonts, dark mode, accessibility labels.
struct SettingsView: View {

    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var coordinator: ReminderCoordinator
    @EnvironmentObject private var notifications: NotificationManager

    var body: some View {
        TabView {
            ScheduleTab()
                .tabItem { Label("Schedule", systemImage: "clock").font(.title3) }
            GeneralTab()
                .tabItem { Label("General", systemImage: "gearshape").font(.title3) }
            QuotesTab()
                .tabItem { Label("Quotes", systemImage: "quote.bubble").font(.title3) }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle").font(.title3) }
        }
        .frame(minWidth: 560, idealWidth: 600, minHeight: 460, idealHeight: 500)
        .padding(16)
        .modifier(SettingsWindowMaterial())
    }
}

// MARK: - Schedule

private struct ScheduleTab: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var coordinator: ReminderCoordinator

    var body: some View {
        Form {
            Section("Bedtime") {
                DatePicker("Sleep time",
                           selection: bindingTime(\.sleepTimeRaw),
                           displayedComponents: .hourAndMinute)
                    .accessibilityLabel("Daily sleep reminder time")
                    .onChange(of: settings.sleepTimeRaw) { _, _ in coordinator.reschedule() }

                Stepper(value: $settings.escalationMinutes, in: 1...30) {
                    Text("Escalate every \(settings.escalationMinutes) min")
                }
                .onChange(of: settings.escalationMinutes) { _, _ in coordinator.reschedule() }
                .accessibilityLabel("Escalation interval")

                Stepper(value: $settings.strikesBeforeOverlay, in: 2...10) {
                    Text("\(settings.strikesBeforeOverlay) strikes before fullscreen overlay")
                }
                .accessibilityLabel("Strikes before fullscreen overlay")
            }

            Section("Wind-down") {
                Toggle("Enable wind-down reminder", isOn: $settings.windDownEnabled)
                    .onChange(of: settings.windDownEnabled) { _, _ in coordinator.reschedule() }
                    .accessibilityLabel("Enable wind-down reminder")
                DatePicker("Wind-down time",
                           selection: bindingTime(\.windDownTimeRaw),
                           displayedComponents: .hourAndMinute)
                    .disabled(!settings.windDownEnabled)
                    .onChange(of: settings.windDownTimeRaw) { _, _ in coordinator.reschedule() }
                    .accessibilityLabel("Daily wind-down reminder time")
            }

            Section("Morning motivation") {
                Toggle("Send a morning quote on wake", isOn: $settings.wakeMotivationEnabled)
                    .accessibilityLabel("Send a morning quote on wake")
                DatePicker("Send only before",
                           selection: bindingTime(\.wakeQuoteCutoffRaw),
                           displayedComponents: .hourAndMinute)
                    .disabled(!settings.wakeMotivationEnabled)
                    .accessibilityLabel("Morning quote cutoff time")
            }

            Section {
                summary
            }
        }
        .formStyle(.grouped)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let next = coordinator.nextSleepDate {
                Label("Next sleep reminder: \(format(next))",
                      systemImage: "moon.stars")
            }
            if let next = coordinator.nextWindDownDate {
                Label("Next wind-down: \(format(next))",
                      systemImage: "lightbulb")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func bindingTime(_ keyPath: ReferenceWritableKeyPath<SettingsStore, Double>) -> Binding<Date> {
        Binding(
            get: { Date(timeIntervalSinceReferenceDate: settings[keyPath: keyPath]) },
            set: { settings[keyPath: keyPath] = $0.timeIntervalSinceReferenceDate }
        )
    }

    private func format(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        let day = Calendar.current.isDateInToday(date) ? "today"
                : Calendar.current.isDateInTomorrow(date) ? "tomorrow"
                : DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
        return "\(day) at \(f.string(from: date))"
    }
}

// MARK: - General

private struct GeneralTab: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var coordinator: ReminderCoordinator
    @EnvironmentObject private var notifications: NotificationManager
    @State private var launchAtLoginError: String?
    @State private var loginItemStatus: SMAppService.Status = SMAppService.mainApp.status
    @State private var appIsInApplications = LaunchAtLogin.canRegister

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch Night Shepherd at login", isOn: Binding(
                    get: { settings.launchAtLogin && LaunchAtLogin.isEnabled },
                    set: { newValue in
                        do {
                            try LaunchAtLogin.set(newValue)
                            settings.launchAtLogin = newValue
                            launchAtLoginError = nil
                            refreshPermissions()
                        } catch {
                            launchAtLoginError = error.localizedDescription
                            refreshPermissions()
                        }
                    }
                ))
                .accessibilityLabel("Launch Night Shepherd at login")
                if let error = launchAtLoginError {
                    Text(error).font(.caption).foregroundStyle(.orange)
                }
            }

            Section("Permissions") {
                VStack(spacing: 0) {
                    PermissionRow(
                        icon: notificationStatus.isHealthy ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                        iconColor: notificationStatus.isHealthy ? .green : .orange,
                        title: "Notifications",
                        detail: notificationStatus.detail,
                        status: notificationStatus.status,
                        statusColor: notificationStatus.isHealthy ? .green : .orange
                    ) {
                        Button("Open System Settings", action: openNotificationSettings)
                            .accessibilityLabel("Open notification settings")
                    }

                    PermissionSeparator()

                    PermissionRow(
                        icon: loginStatusInfo.isHealthy ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                        iconColor: loginStatusInfo.isHealthy ? .green : .orange,
                        title: "Login Items",
                        detail: loginStatusInfo.detail,
                        status: loginStatusInfo.status,
                        statusColor: loginStatusInfo.isHealthy ? .green : .orange
                    ) {
                        Button("Reveal in Finder", action: revealAppInFinder)
                            .accessibilityLabel("Reveal Night Shepherd in Finder")
                    }

                    if !appIsInApplications {
                        HStack(spacing: 8) {
                            Image(systemName: "folder.badge.gearshape")
                                .foregroundStyle(.orange)
                                .accessibilityHidden(true)
                            Text("Move Night Shepherd to /Applications to enable Launch at Login.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                    }

                    PermissionSeparator()

                    PermissionRow(
                        icon: "checkmark.seal.fill",
                        iconColor: .green,
                        title: "In-App Banners",
                        detail: settings.inAppBannerEnabled
                            ? "Enabled. No system permission needed."
                            : "Disabled. System notifications still post.",
                        status: settings.inAppBannerEnabled ? "Enabled" : "Disabled",
                        statusColor: settings.inAppBannerEnabled ? .green : .secondary
                    ) {
                        Toggle("", isOn: $settings.inAppBannerEnabled)
                            .labelsHidden()
                            .accessibilityLabel("Show in-app banner notifications")
                    }
                }
                .padding(.vertical, 2)

                Button("Re-check permissions", action: refreshPermissions)
                    .accessibilityLabel("Re-check permissions")
            }

            Section("Test") {
                Button("Trigger sleep reminder now") {
                    coordinator.triggerSleepNow()
                }
                .accessibilityLabel("Trigger sleep reminder now")
                Button("Show test banner now") {
                    notifications.showTestBanner()
                }
                .accessibilityLabel("Show test banner now")
                Button("Reset tonight’s cycle") {
                    coordinator.dismissTonight()
                }
                .accessibilityLabel("Reset tonight's cycle")
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: refreshPermissions)
    }

    private var notificationStatus: PermissionStatus {
        switch notifications.authorizationStatus {
        case .authorized:
            return PermissionStatus(status: "Authorized", detail: "Banners, sounds, and Notification Center history can be used.", isHealthy: true)
        case .denied:
            return PermissionStatus(status: "Denied", detail: "Open System Settings to allow Night Shepherd notifications.", isHealthy: false)
        case .notDetermined:
            return PermissionStatus(status: "Not Asked", detail: "Notification permission has not been granted yet.", isHealthy: false)
        case .provisional:
            return PermissionStatus(status: "Provisional", detail: "Notifications may appear quietly until fully authorized.", isHealthy: false)
        case .ephemeral:
            return PermissionStatus(status: "Ephemeral", detail: "Temporary notification access is active.", isHealthy: false)
        @unknown default:
            return PermissionStatus(status: "Unknown", detail: "macOS returned an unrecognized notification status.", isHealthy: false)
        }
    }

    private var loginStatusInfo: PermissionStatus {
        switch loginItemStatus {
        case .enabled:
            return PermissionStatus(status: "Enabled", detail: "Night Shepherd can start automatically at login.", isHealthy: true)
        case .notRegistered:
            return PermissionStatus(status: "Not Registered", detail: "Turn on Launch at Login after installing the app.", isHealthy: false)
        case .requiresApproval:
            return PermissionStatus(status: "Requires Approval", detail: "Approve Night Shepherd in System Settings to finish setup.", isHealthy: false)
        case .notFound:
            return PermissionStatus(status: "Not Found", detail: "macOS cannot find this app as a login item yet.", isHealthy: false)
        @unknown default:
            return PermissionStatus(status: "Unknown", detail: "macOS returned an unrecognized login-item status.", isHealthy: false)
        }
    }

    private func refreshPermissions() {
        notifications.refreshAuthorizationStatus()
        loginItemStatus = SMAppService.mainApp.status
        appIsInApplications = LaunchAtLogin.canRegister
    }

    private func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }

    private func revealAppInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }
}

private struct PermissionStatus {
    let status: String
    let detail: String
    let isHealthy: Bool
}

private struct PermissionRow<Accessory: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let detail: String
    let status: String
    let statusColor: Color
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                    StatusPill(text: status, color: statusColor)
                }
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            accessory
                .controlSize(.small)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }
}

private struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
                    .overlay(Capsule().stroke(color.opacity(0.24), lineWidth: 1))
            )
    }
}

private struct PermissionSeparator: View {
    var body: some View {
        Divider()
            .padding(.leading, 46)
            .opacity(0.55)
    }
}

private struct SettingsWindowMaterial: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.containerBackground(.regularMaterial, for: .window)
        } else {
            content
        }
    }
}

// MARK: - Quotes

private struct QuotesTab: View {
    @State private var sampleSleep: Quote = .placeholder
    @State private var sampleWake: Quote = .placeholder
    @State private var sampleWind: Quote = .placeholder

    var body: some View {
        Form {
            Section("Bundled quote bank") {
                Text("Night Shepherd ships with a curated, offline library of sleep, wake, and wind-down quotes. Press Refresh to preview random picks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Refresh samples", action: refreshAll)
                    .accessibilityLabel("Refresh quote samples")
            }
            Section("Sleep sample") { quoteRow(sampleSleep) }
            Section("Wake sample") { quoteRow(sampleWake) }
            Section("Wind-down sample") { quoteRow(sampleWind) }
        }
        .formStyle(.grouped)
        .onAppear(perform: refreshAll)
    }

    private func quoteRow(_ q: Quote) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("“\(q.text)”").font(.subheadline)
            if let a = q.author { Text("— \(a)").font(.caption).foregroundStyle(.secondary) }
        }
        .padding(.vertical, 4)
    }

    private func refreshAll() {
        sampleSleep = QuoteLibrary.shared.random(.sleep)
        sampleWake = QuoteLibrary.shared.random(.wake)
        sampleWind = QuoteLibrary.shared.random(.windDown)
    }
}

private extension Quote {
    static let placeholder = Quote(text: "Loading…", author: nil)
}

// MARK: - About

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "moon.stars.fill")
                .font(.largeTitle.weight(.semibold))
                .scaleEffect(1.35)
                .foregroundStyle(Color.accentColor)
                .shadow(color: .accentColor.opacity(0.25), radius: 16)
                .accessibilityHidden(true)
            Text("Night Shepherd")
                .font(.title2.weight(.semibold))
            Text(version)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("A tiny menu-bar coach that forces your sleep cycle back into shape.")
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(v) (\(b)) · macOS 26 Tahoe"
    }
}
