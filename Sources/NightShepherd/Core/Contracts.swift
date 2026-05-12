import Foundation
import SwiftUI

// MARK: - Quote model

struct Quote: Codable, Hashable, Identifiable {
    var id: String { text }
    let text: String
    let author: String?
}

enum Mood: String, Codable {
    case sleep
    case wake
    case windDown
}

// MARK: - User-facing settings keys (single source of truth)

enum SettingsKey {
    static let sleepTime           = "ns.sleepTime"
    static let windDownTime        = "ns.windDownTime"
    static let wakeQuoteCutoff     = "ns.wakeQuoteCutoff"
    static let escalationMinutes   = "ns.escalationMinutes"
    static let strikesBeforeOverlay = "ns.strikesBeforeOverlay"
    static let launchAtLogin       = "ns.launchAtLogin"
    static let windDownEnabled     = "ns.windDownEnabled"
    static let wakeMotivationEnabled = "ns.wakeMotivationEnabled"
    static let inAppBannerEnabled  = "ns.inAppBannerEnabled"
    static let onboardingComplete  = "ns.onboardingComplete"
    static let lastWakeQuoteDay    = "ns.lastWakeQuoteDay"
    static let lastSleepCycleDay   = "ns.lastSleepCycleDay"
}

enum NotificationCategory {
    static let sleepReminder = "SLEEP_REMINDER"
    static let wakeMotivation = "WAKE_MOTIVATION"
    static let windDown       = "WIND_DOWN"
}

enum NotificationAction {
    static let goingToBed = "GOING_TO_BED"
    static let snooze3    = "SNOOZE_3_MIN"
    static let gotIt      = "GOT_IT"
}

enum NotificationUserInfoKey {
    static let strikeIndex = "strikeIndex"
}

// MARK: - Protocols (the cross-module seam)

protocol QuoteProviding: AnyObject {
    func random(_ mood: Mood) -> Quote
}

@MainActor
protocol ReminderControlling: AnyObject, ObservableObject {
    var strike: Int { get }
    var isReminderCycleActive: Bool { get }
    var nextSleepDate: Date? { get }
    var nextWindDownDate: Date? { get }

    func bootstrap()
    func reschedule()
    func dismissTonight()
    func userSnoozed(minutes: Int)
    func triggerSleepNow()
}

@MainActor
protocol OverlayPresenting: AnyObject {
    var isPresented: Bool { get }
    func present(quote: Quote, onDismiss: @escaping () -> Void)
    func dismiss()
}

// MARK: - Defaults

enum Defaults {
    static let sleepHour: Int = 23
    static let sleepMinute: Int = 30
    static let windDownHour: Int = 22
    static let windDownMinute: Int = 30
    static let wakeCutoffHour: Int = 15
    static let wakeCutoffMinute: Int = 0
    static let escalationMinutes: Int = 3
    static let strikesBeforeOverlay: Int = 3
}

// MARK: - Date helpers (used everywhere)

enum DateUtil {
    /// Builds today's date with the hour/minute taken from `time`.
    static func today(at time: Date, calendar: Calendar = .current) -> Date {
        let comps = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(
            bySettingHour: comps.hour ?? 0,
            minute: comps.minute ?? 0,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    /// The next future fire-date matching `time`'s hour:minute.
    static func nextOccurrence(of time: Date, after reference: Date = Date(), calendar: Calendar = .current) -> Date {
        let comps = calendar.dateComponents([.hour, .minute], from: time)
        let candidate = calendar.nextDate(
            after: reference,
            matching: DateComponents(hour: comps.hour, minute: comps.minute),
            matchingPolicy: .nextTime
        ) ?? reference.addingTimeInterval(60)
        return candidate
    }

    static func dayKey(_ date: Date = Date(), calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d",
                      comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }
}
