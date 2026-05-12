import Foundation
import UserNotifications
import AppKit
import SwiftUI

/// Wraps `UNUserNotificationCenter` with the categories, actions, and helpers
/// the ReminderCoordinator needs. Also acts as the UN delegate so notification
/// taps route back into the app on the main actor.
@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate, ObservableObject {

    weak var coordinator: ReminderCoordinator?

    private let center = UNUserNotificationCenter.current()

    /// Set to `true` once macOS has granted permission. Apps without permission
    /// fall back to in-process surfaces (status line + overlay) instead of system
    /// notifications.
    @Published private(set) var authorizationGranted: Bool = false

    /// Full system status for the Permissions tab.
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// Tracks the last error so the UI can show a "Notifications denied" hint.
    @Published private(set) var lastError: String?

    override init() {
        super.init()
        center.delegate = self
    }

    // MARK: - Setup

    func registerCategories() {
        let goingToBed = UNNotificationAction(
            identifier: NotificationAction.goingToBed,
            title: "I’m going to bed",
            options: [.foreground])
        let snooze = UNNotificationAction(
            identifier: NotificationAction.snooze3,
            title: "Snooze 3 minutes",
            options: [])
        let gotIt = UNNotificationAction(
            identifier: NotificationAction.gotIt,
            title: "Got it",
            options: [])

        let sleep = UNNotificationCategory(
            identifier: NotificationCategory.sleepReminder,
            actions: [goingToBed, snooze],
            intentIdentifiers: [],
            options: [.customDismissAction])
        let wake = UNNotificationCategory(
            identifier: NotificationCategory.wakeMotivation,
            actions: [gotIt],
            intentIdentifiers: [],
            options: [])
        let wind = UNNotificationCategory(
            identifier: NotificationCategory.windDown,
            actions: [gotIt],
            intentIdentifiers: [],
            options: [])

        center.setNotificationCategories([sleep, wake, wind])
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge, .provisional]) { [weak self] granted, error in
            Task { @MainActor in
                self?.authorizationGranted = granted
                self?.lastError = error?.localizedDescription
                self?.refreshAuthorizationStatus()
            }
        }
    }

    func refreshAuthorizationStatus() {
        center.getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                self?.authorizationStatus = settings.authorizationStatus
                self?.authorizationGranted = settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional
            }
        }
    }

    // MARK: - Posting

    func postSleepReminder(strike: Int, of total: Int, quote: Quote) {
        let title = "Time to sleep — Strike \(strike) of \(total)"
        showBanner(title: title, quote: quote, accent: .orange)

        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = quote.author.map { "— \($0)" } ?? ""
        content.body = quote.text
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.sleepReminder
        content.interruptionLevel = .timeSensitive
        content.userInfo = [NotificationUserInfoKey.strikeIndex: strike]
        content.threadIdentifier = "ns.sleep"
        deliver(content: content, identifier: "ns.sleep.strike.\(strike).\(Int(Date().timeIntervalSince1970))")
    }

    func postWakeMotivation(quote: Quote) {
        showBanner(title: "Good morning", quote: quote, accent: .accentColor)

        let content = UNMutableNotificationContent()
        content.title = "Good morning"
        content.subtitle = quote.author.map { "— \($0)" } ?? ""
        content.body = quote.text
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.wakeMotivation
        content.interruptionLevel = .active
        deliver(content: content, identifier: "ns.wake.\(DateUtil.dayKey())")
    }

    func postWindDown(quote: Quote) {
        showBanner(title: "Wind down", quote: quote, accent: .indigo)

        let content = UNMutableNotificationContent()
        content.title = "Wind down"
        content.subtitle = "Dim the lights · enable Night Shift"
        content.body = quote.text
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.windDown
        content.interruptionLevel = .active
        deliver(content: content, identifier: "ns.winddown.\(DateUtil.dayKey())")
    }

    /// Daily fallback so we still surface a reminder even if the in-process
    /// timer was killed somehow.
    func scheduleFallbackDailySleep(at time: Date) {
        let id = "ns.sleep.daily.fallback"
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: comps.hour, minute: comps.minute),
            repeats: true)

        let content = UNMutableNotificationContent()
        content.title = "Time to sleep"
        content.body = "Open Night Shepherd to dismiss tonight or get a quote."
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.sleepReminder
        content.interruptionLevel = .timeSensitive

        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(req)
    }

    func showTestBanner() {
        showBanner(
            title: "Night Shepherd test banner",
            quote: Quote(text: "This is the in-app fallback: visible, audible, and independent of Notification Center banners.", author: "Night Shepherd"),
            accent: .accentColor
        )
    }

    func cancelAllSleepReminders() {
        center.getPendingNotificationRequests { reqs in
            let ids = reqs.map(\.identifier).filter { $0.hasPrefix("ns.sleep.") && !$0.hasSuffix("daily.fallback") }
            Task { @MainActor [weak self] in
                self?.center.removePendingNotificationRequests(withIdentifiers: ids)
                self?.center.removeDeliveredNotifications(withIdentifiers: ids)
            }
        }
    }

    private func deliver(content: UNNotificationContent, identifier: String) {
        let req = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        center.add(req) { [weak self] error in
            if let error = error {
                Task { @MainActor in self?.lastError = error.localizedDescription }
            }
        }
    }

    private func showBanner(title: String, quote: Quote, accent: Color) {
        guard SettingsStore.shared.inAppBannerEnabled else { return }
        InAppBannerWindow.shared.show(title: title, quote: quote, accent: accent)
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show banner + sound even when the app is in front.
        completionHandler([.banner, .sound, .list])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let actionID = response.actionIdentifier
        Task { @MainActor [weak self] in
            guard let coordinator = self?.coordinator else { completionHandler(); return }
            switch actionID {
            case NotificationAction.goingToBed:
                coordinator.dismissTonight()
            case NotificationAction.snooze3:
                coordinator.userSnoozed(minutes: 3)
            case UNNotificationDefaultActionIdentifier:
                coordinator.openMainWindowFromNotification()
            case UNNotificationDismissActionIdentifier:
                break
            default:
                break
            }
            completionHandler()
        }
    }
}
