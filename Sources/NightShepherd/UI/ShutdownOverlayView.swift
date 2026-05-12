import SwiftUI

/// The third-strike fullscreen experience. Calm, intentional, hard to miss.
/// Designed to be persuasive, not punitive.
struct ShutdownOverlayView: View {
    let quote: Quote
    let onDismiss: () -> Void
    let onSnooze: () -> Void

    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var animateIn = false
    @State private var moonBreath = false
    @State private var starPhase: CGFloat = 0

    var body: some View {
        ZStack {
            background

            if !reduceTransparency {
                StarfieldView(phase: starPhase)
                    .opacity(0.55)
                    .allowsHitTesting(false)
            }

            VStack(spacing: 36) {
                Spacer()

                Image(systemName: "moon.stars.fill")
                    .font(.largeTitle.weight(.semibold))
                    .scaleEffect(1.6)
                    .foregroundStyle(.white.opacity(0.95))
                    .shadow(color: .indigo.opacity(0.6), radius: 28)
                    .scaleEffect(moonBreath ? 1.04 : 1.0)
                    .accessibilityHidden(true)

                VStack(spacing: 18) {
                    Text("It’s time to sleep.")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Strike 3 — your bedtime was \(format(time: settings.sleepTime))")
                        .font(.headline.weight(.regular))
                        .foregroundStyle(.white.opacity(0.68))
                        .multilineTextAlignment(.center)

                    Text(quote.text)
                        .font(.title2.weight(.regular))
                        .foregroundStyle(.white.opacity(0.88))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, 80)
                        .frame(maxWidth: 820)

                    if let author = quote.author, !author.isEmpty {
                        Text("— \(author)")
                            .font(.callout.weight(.medium).italic())
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                Spacer()

                HStack(spacing: 16) {
                    Button(action: onSnooze) {
                        Text("Snooze 5 minutes")
                            .font(.callout.weight(.medium))
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .background(
                        Capsule().fill(.white.opacity(0.08))
                            .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
                    )
                    .foregroundStyle(.white.opacity(0.9))
                    .accessibilityLabel("Snooze five minutes")

                    Button(action: onDismiss) {
                        HStack(spacing: 10) {
                            Image(systemName: "bed.double.fill")
                            Text("I’m going to bed")
                        }
                        .font(.headline.weight(.semibold))
                        .padding(.horizontal, 30)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .background(
                        Capsule().fill(
                            LinearGradient(colors: [
                                Color.accentColor.opacity(0.92),
                                Color.accentColor.opacity(0.70)
                            ], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    )
                    .foregroundStyle(.white)
                    .shadow(color: .blue.opacity(0.45), radius: 16, y: 8)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityLabel("I am going to bed. Dismiss reminder for tonight.")
                }
                .padding(.bottom, 80)
            }
            .padding(40)
            .opacity(animateIn ? 1 : 0)
            .scaleEffect(animateIn ? 1 : 0.96)
        }
        .ignoresSafeArea()
        .onAppear {
            if reduceMotion {
                animateIn = true
            } else {
                withAnimation(.easeOut(duration: 0.7)) {
                    animateIn = true
                }
                withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
                    starPhase = 1
                }
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    moonBreath = true
                }
            }
        }
    }

    private func format(time: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }

    @ViewBuilder
    private var background: some View {
        if reduceTransparency {
            Color(red: 0.04, green: 0.06, blue: 0.13).ignoresSafeArea()
        } else {
            ZStack {
                LinearGradient(colors: [
                    Color(red: 0.02, green: 0.04, blue: 0.10),
                    Color(red: 0.07, green: 0.04, blue: 0.18),
                    Color(red: 0.01, green: 0.02, blue: 0.06)
                ], startPoint: .top, endPoint: .bottom)

                RadialGradient(colors: [
                    Color(red: 0.30, green: 0.20, blue: 0.55).opacity(0.45),
                    .clear
                ], center: .topLeading, startRadius: 50, endRadius: 700)

                VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                    .opacity(0.35)
            }
            .ignoresSafeArea()
        }
    }
}

/// Soft animated starfield drawn with Canvas — cheap, no AppKit dependencies.
private struct StarfieldView: View {
    let phase: CGFloat

    var body: some View {
        Canvas { context, size in
            let stars = Self.stars
            for star in stars {
                let twinkle = 0.5 + 0.5 * sin((phase + star.offset) * .pi * 2)
                let x = star.x * size.width
                let y = star.y * size.height
                let radius = star.size * (0.6 + 0.4 * twinkle)
                let rect = CGRect(x: x - radius, y: y - radius,
                                  width: radius * 2, height: radius * 2)
                let opacity = 0.35 + 0.45 * twinkle
                context.opacity = opacity
                context.fill(Path(ellipseIn: rect), with: .color(.white))
            }
        }
    }

    private struct Star {
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let offset: CGFloat
    }

    private static let stars: [Star] = (0..<140).map { i in
        let seed = Double(i)
        return Star(
            x: CGFloat(fract(seed * 0.7321)),
            y: CGFloat(fract(seed * 0.9137)),
            size: CGFloat(0.6 + 1.8 * fract(seed * 0.3187)),
            offset: CGFloat(fract(seed * 0.5113))
        )
    }
}

private func fract(_ x: Double) -> Double { x - floor(x) }
