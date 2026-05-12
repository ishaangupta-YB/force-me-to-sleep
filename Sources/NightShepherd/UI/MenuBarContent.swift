import SwiftUI
import AppKit

/// Contents of the MenuBarExtra popover. Compact, status-aware, keyboard-friendly.
struct MenuBarContent: View {

    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var coordinator: ReminderCoordinator

    @State private var now = Date()
    private let tick = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 12) {
            header
            statusBlock
            actionButtons
            Divider().opacity(0.4)
            footer
        }
        .padding(14)
        .frame(width: 300)
        .background {
            ZStack(alignment: .top) {
                GlassBackground(material: .hudWindow)
                LinearGradient(
                    colors: [Color.indigo.opacity(0.22), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 64)
                .allowsHitTesting(false)
            }
        }
        .onReceive(tick) { now = $0 }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "moon.stars.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .shadow(color: .accentColor.opacity(0.35), radius: 10)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("Night Shepherd")
                    .font(.headline.weight(.semibold))
                Text(headlineSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var statusBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            if coordinator.isReminderCycleActive {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                    Text("Strike \(coordinator.strike) of \(settings.strikesBeforeOverlay)")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                }
                Text("Dismiss now to stop tonight’s reminders.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text(nextLine)
                        .font(.subheadline)
                    Spacer()
                }
                Text("Wind down at \(format(time: settings.windDownTime)) · wake quotes before \(format(time: settings.wakeQuoteCutoff))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.45))
                .background(
                    GlassBackground(material: .hudWindow)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var actionButtons: some View {
        VStack(spacing: 8) {
            if coordinator.isReminderCycleActive {
                Button(action: { coordinator.dismissTonight() }) {
                    HStack {
                        Image(systemName: "bed.double.fill")
                        Text("I’m going to bed").fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.vertical, 6).padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .accessibilityLabel("I am going to bed")
            } else {
                Button(action: { coordinator.triggerSleepNow() }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Trigger reminder now")
                        Spacer()
                    }
                    .padding(.vertical, 4).padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .help("Sends a sleep reminder immediately — useful for testing.")
                .accessibilityLabel("Trigger reminder now")
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape")
                    Text("Settings…")
                }
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Open settings")

            Spacer()

            Button {
                NSApp.terminate(nil)
            } label: {
                Text("Quit")
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q", modifiers: .command)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Quit Night Shepherd")
        }
        .font(.caption)
    }

    // MARK: - Formatting

    private var headlineSubtitle: String {
        coordinator.isReminderCycleActive
            ? "Reminder cycle active"
            : "Bedtime · \(format(time: settings.sleepTime))"
    }

    private var nextLine: String {
        guard let date = coordinator.nextSleepDate else { return "No reminder scheduled" }
        return "Next reminder \(relative(date))"
    }

    private func format(time: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: time)
    }

    private func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: now)
    }
}
