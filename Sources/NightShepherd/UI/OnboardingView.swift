import SwiftUI
import AppKit

/// First-launch flow that captures the three times that matter and asks for
/// notification permission. Lightweight — three screens, one progress dots row.
struct OnboardingView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var coordinator: ReminderCoordinator
    @EnvironmentObject private var notifications: NotificationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step: Int = 0
    @State private var animateIn = false
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            onboardingBackground

            VStack(spacing: 24) {
                Spacer().frame(height: 20)
                Image(systemName: "moon.stars.fill")
                    .font(.system(.largeTitle, design: .default, weight: .semibold))
                    .scaleEffect(1.25)
                    .foregroundStyle(Color.accentColor)
                    .shadow(color: .accentColor.opacity(0.35), radius: 18)
                    .accessibilityHidden(true)
                Text("Welcome to Night Shepherd")
                    .font(.title.weight(.semibold))
                Text(stepSubtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Group {
                    switch step {
                    case 0: timesStep
                    case 1: cutoffStep
                    case 2: permissionStep
                    default: EmptyView()
                    }
                }
                .id(step)
                .transition(.opacity)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: step)
                .padding(.horizontal, 30)

                Spacer()

                HStack {
                    if step > 0 {
                        Button("Back") { step -= 1 }
                            .keyboardShortcut(.cancelAction)
                            .accessibilityLabel("Back")
                    }
                    Spacer()
                    dotsView
                    Spacer()
                    Button(step == 2 ? "Get started" : "Continue") {
                        if step == 2 {
                            settings.onboardingComplete = true
                            coordinator.reschedule()
                            onComplete()
                        } else {
                            step += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityLabel(step == 2 ? "Get started" : "Continue")
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 24)
            }
            .opacity(animateIn ? 1 : 0)
            .offset(y: reduceMotion ? 0 : (animateIn ? 0 : 10))
        }
        .frame(width: 540, height: 460)
        .onAppear {
            if reduceMotion {
                animateIn = true
            } else {
                withAnimation(.easeOut(duration: 0.45)) {
                    animateIn = true
                }
            }
        }
    }

    private var onboardingBackground: some View {
        ZStack {
            GlassBackground(material: .underWindowBackground)
            LinearGradient(
                colors: [Color.accentColor.opacity(0.16), Color.indigo.opacity(0.08), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .allowsHitTesting(false)
        }
    }

    private var stepSubtitle: String {
        switch step {
        case 0: return "Tell me when you want to sleep and wind down. You can change these any time in Settings."
        case 1: return "On mornings you wake up before this cutoff, I’ll send you a quick motivational quote."
        case 2: return "I deliver three calm reminders — then a fullscreen overlay. Allow notifications so the first two can reach you."
        default: return ""
        }
    }

    private var timesStep: some View {
        Form {
            DatePicker("Sleep time",
                       selection: timeBinding(\.sleepTimeRaw),
                       displayedComponents: .hourAndMinute)
                .accessibilityLabel("Daily sleep reminder time")
            DatePicker("Wind-down time",
                       selection: timeBinding(\.windDownTimeRaw),
                       displayedComponents: .hourAndMinute)
                .accessibilityLabel("Daily wind-down reminder time")
        }
        .formStyle(.grouped)
    }

    private var cutoffStep: some View {
        Form {
            DatePicker("Wake quote cutoff",
                       selection: timeBinding(\.wakeQuoteCutoffRaw),
                       displayedComponents: .hourAndMinute)
                .accessibilityLabel("Morning quote cutoff time")
            Toggle("Send a morning quote on wake", isOn: $settings.wakeMotivationEnabled)
                .accessibilityLabel("Send a morning quote on wake")
        }
        .formStyle(.grouped)
    }

    private var permissionStep: some View {
        VStack(spacing: 12) {
            Button("Allow notifications") {
                notifications.requestAuthorization()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityLabel("Allow notifications")
            Text(notifications.authorizationGranted
                 ? "Notifications enabled — you’re good to go."
                 : "If macOS doesn’t show a prompt, open System Settings → Notifications → Night Shepherd.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var dotsView: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(i == step ? Color.accentColor : Color.secondary.opacity(0.35))
                    .frame(width: 7, height: 7)
            }
        }
    }

    private func timeBinding(_ keyPath: ReferenceWritableKeyPath<SettingsStore, Double>) -> Binding<Date> {
        Binding(
            get: { Date(timeIntervalSinceReferenceDate: settings[keyPath: keyPath]) },
            set: { settings[keyPath: keyPath] = $0.timeIntervalSinceReferenceDate }
        )
    }
}
