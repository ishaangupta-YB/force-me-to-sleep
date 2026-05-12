import Foundation
import AppKit
import Combine

/// Drives the bedtime escalation state machine, the morning wake-quote flow,
/// and the daily wind-down reminder. All timers live on the main actor; the
/// coordinator owns no Codable/persistent state of its own — settings and
/// "have we shown today" flags live in SettingsStore.
@MainActor
final class ReminderCoordinator: ObservableObject, ReminderControlling {

    // MARK: - Published state (UI binds to these)

    @Published private(set) var strike: Int = 0
    @Published private(set) var isReminderCycleActive: Bool = false
    @Published private(set) var nextSleepDate: Date?
    @Published private(set) var nextWindDownDate: Date?

    // MARK: - Dependencies

    private let settings: SettingsStore
    private let quotes: QuoteProviding
    private let notifications: NotificationManager
    private let overlay: any OverlayPresenting

    // MARK: - Timers

    private var sleepFireTimer: DispatchSourceTimer?
    private var escalationTimer: DispatchSourceTimer?
    private var windDownFireTimer: DispatchSourceTimer?

    init(settings: SettingsStore,
         quotes: QuoteProviding,
         notifications: NotificationManager,
         overlay: any OverlayPresenting) {
        self.settings = settings
        self.quotes = quotes
        self.notifications = notifications
        self.overlay = overlay
        self.notifications.coordinator = self
    }

    // MARK: - Lifecycle

    func bootstrap() {
        notifications.refreshAuthorizationStatus()
        notifications.registerCategories()
        reschedule()
        wakeMotivationIfDue()
    }

    func reschedule() {
        cancelTimers()
        scheduleNextSleep()
        scheduleNextWindDown()
        notifications.scheduleFallbackDailySleep(at: settings.sleepTime)
    }

    // MARK: - Sleep cycle

    private func scheduleNextSleep() {
        let target = DateUtil.nextOccurrence(of: settings.sleepTime)
        nextSleepDate = target

        let timer = makeTimer(at: target) { [weak self] in
            self?.sleepTimeReached()
        }
        sleepFireTimer = timer
        timer.resume()
    }

    private func sleepTimeReached() {
        // If the user already dismissed tonight's cycle (e.g. went to bed early
        // and clicked Dismiss), do not start another one.
        if settings.lastSleepCycleDay == DateUtil.dayKey() {
            scheduleNextSleep()
            return
        }
        beginCycle()
    }

    private func beginCycle() {
        strike = 1
        isReminderCycleActive = true
        notifications.postSleepReminder(strike: strike,
                                        of: settings.strikesBeforeOverlay,
                                        quote: quotes.random(.sleep))
        startEscalationTimer()
    }

    private func startEscalationTimer() {
        escalationTimer?.cancel()
        let interval = TimeInterval(max(1, settings.escalationMinutes) * 60)
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + interval, repeating: interval, leeway: .seconds(1))
        timer.setEventHandler { [weak self] in
            Task { @MainActor in self?.escalationTick() }
        }
        escalationTimer = timer
        timer.resume()
    }

    private func escalationTick() {
        guard isReminderCycleActive else { return }
        strike += 1

        if strike >= settings.strikesBeforeOverlay {
            presentOverlay()
        } else {
            notifications.postSleepReminder(strike: strike,
                                            of: settings.strikesBeforeOverlay,
                                            quote: quotes.random(.sleep))
        }
    }

    private func presentOverlay() {
        let quote = quotes.random(.sleep)
        overlay.present(quote: quote) { [weak self] in
            self?.dismissTonight()
        }
        escalationTimer?.cancel()
        escalationTimer = nil
    }

    // MARK: - Public reset triggers

    func dismissTonight() {
        isReminderCycleActive = false
        strike = 0
        settings.lastSleepCycleDay = DateUtil.dayKey()
        escalationTimer?.cancel(); escalationTimer = nil
        notifications.cancelAllSleepReminders()
        overlay.dismiss()
        // Schedule tomorrow.
        scheduleNextSleep()
    }

    func userSnoozed(minutes: Int) {
        escalationTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        let interval = TimeInterval(max(1, minutes) * 60)
        timer.schedule(deadline: .now() + interval, repeating: .never)
        timer.setEventHandler { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if self.isReminderCycleActive {
                    self.escalationTick()
                    self.startEscalationTimer()
                }
            }
        }
        escalationTimer = timer
        timer.resume()
    }

    func triggerSleepNow() {
        // Debug helper — pretend the sleep time just hit.
        if isReminderCycleActive {
            escalationTick()
        } else {
            beginCycle()
        }
    }

    // MARK: - Wind-down

    private func scheduleNextWindDown() {
        guard settings.windDownEnabled else { nextWindDownDate = nil; return }
        let target = DateUtil.nextOccurrence(of: settings.windDownTime)
        nextWindDownDate = target

        let timer = makeTimer(at: target) { [weak self] in
            self?.windDownReached()
        }
        windDownFireTimer = timer
        timer.resume()
    }

    private func windDownReached() {
        if settings.windDownEnabled {
            notifications.postWindDown(quote: quotes.random(.windDown))
        }
        scheduleNextWindDown()
    }

    // MARK: - Morning motivation

    /// Posts a morning quote once per day if it's before the user's cutoff.
    func wakeMotivationIfDue() {
        guard settings.wakeMotivationEnabled else { return }
        let today = DateUtil.dayKey()
        guard settings.lastWakeQuoteDay != today else { return }

        let cutoffToday = DateUtil.today(at: settings.wakeQuoteCutoff)
        guard Date() < cutoffToday else { return }

        let quote = quotes.random(.wake)
        notifications.postWakeMotivation(quote: quote)
        settings.lastWakeQuoteDay = today
    }

    // MARK: - System events

    /// Called by AppDelegate when the user's Mac is about to sleep — counts as
    /// "they got the message", we cancel the escalation cycle for tonight.
    func systemWillSleep() {
        guard isReminderCycleActive else { return }
        dismissTonight()
    }

    func systemDidWake() {
        wakeMotivationIfDue()
        // The fire-date timer may have missed its deadline while asleep; recompute.
        if nextSleepDate.map({ $0 < Date() }) ?? false {
            scheduleNextSleep()
        }
        if nextWindDownDate.map({ $0 < Date() }) ?? false {
            scheduleNextWindDown()
        }
    }

    func openMainWindowFromNotification() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    // MARK: - Helpers

    private func cancelTimers() {
        sleepFireTimer?.cancel(); sleepFireTimer = nil
        windDownFireTimer?.cancel(); windDownFireTimer = nil
    }

    private func makeTimer(at date: Date, handler: @escaping @MainActor () -> Void) -> DispatchSourceTimer {
        let interval = max(date.timeIntervalSinceNow, 1)
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + interval, repeating: .never, leeway: .seconds(1))
        timer.setEventHandler { Task { @MainActor in handler() } }
        return timer
    }
}
