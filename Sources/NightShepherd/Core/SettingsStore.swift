import Foundation
import SwiftUI
import Combine

/// Single source of truth for user-facing preferences.
/// Backed by UserDefaults via @AppStorage so writes are tiny and instant.
@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @AppStorage(SettingsKey.sleepTime)             var sleepTimeRaw: Double = 0
    @AppStorage(SettingsKey.windDownTime)          var windDownTimeRaw: Double = 0
    @AppStorage(SettingsKey.wakeQuoteCutoff)       var wakeQuoteCutoffRaw: Double = 0
    @AppStorage(SettingsKey.escalationMinutes)     var escalationMinutes: Int = Defaults.escalationMinutes
    @AppStorage(SettingsKey.strikesBeforeOverlay)  var strikesBeforeOverlay: Int = Defaults.strikesBeforeOverlay
    @AppStorage(SettingsKey.launchAtLogin)         var launchAtLogin: Bool = false
    @AppStorage(SettingsKey.windDownEnabled)       var windDownEnabled: Bool = true
    @AppStorage(SettingsKey.wakeMotivationEnabled) var wakeMotivationEnabled: Bool = true
    @AppStorage(SettingsKey.inAppBannerEnabled)    var inAppBannerEnabled: Bool = true
    @AppStorage(SettingsKey.onboardingComplete)    var onboardingComplete: Bool = false
    @AppStorage(SettingsKey.lastWakeQuoteDay)      var lastWakeQuoteDay: String = ""
    @AppStorage(SettingsKey.lastSleepCycleDay)     var lastSleepCycleDay: String = ""

    var sleepTime: Date {
        get { Date(timeIntervalSinceReferenceDate: sleepTimeRaw) }
        set { sleepTimeRaw = newValue.timeIntervalSinceReferenceDate; objectWillChange.send() }
    }

    var windDownTime: Date {
        get { Date(timeIntervalSinceReferenceDate: windDownTimeRaw) }
        set { windDownTimeRaw = newValue.timeIntervalSinceReferenceDate; objectWillChange.send() }
    }

    var wakeQuoteCutoff: Date {
        get { Date(timeIntervalSinceReferenceDate: wakeQuoteCutoffRaw) }
        set { wakeQuoteCutoffRaw = newValue.timeIntervalSinceReferenceDate; objectWillChange.send() }
    }

    private init() {
        // Seed default times on first launch (when the stored sentinel is still 0).
        if sleepTimeRaw == 0 {
            sleepTimeRaw = Self.makeTime(hour: Defaults.sleepHour, minute: Defaults.sleepMinute).timeIntervalSinceReferenceDate
        }
        if windDownTimeRaw == 0 {
            windDownTimeRaw = Self.makeTime(hour: Defaults.windDownHour, minute: Defaults.windDownMinute).timeIntervalSinceReferenceDate
        }
        if wakeQuoteCutoffRaw == 0 {
            wakeQuoteCutoffRaw = Self.makeTime(hour: Defaults.wakeCutoffHour, minute: Defaults.wakeCutoffMinute).timeIntervalSinceReferenceDate
        }
    }

    private static func makeTime(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }
}
