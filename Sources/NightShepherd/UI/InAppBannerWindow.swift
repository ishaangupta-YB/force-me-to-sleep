import AppKit
import QuartzCore
import SwiftUI

/// Guaranteed-visible fallback for important reminders when Notification Center
/// suppresses banners for locally signed builds.
@MainActor
final class InAppBannerWindow {
    static let shared = InAppBannerWindow()

    private let size = NSSize(width: 360, height: 110)
    private let inset: CGFloat = 20
    private var window: NSWindow?
    private var dismissTask: Task<Void, Never>?
    private var isHovered = false

    private init() {}

    func show(title: String, quote: Quote, accent: Color = .accentColor) {
        dismissTask?.cancel()
        window?.orderOut(nil)
        isHovered = false

        NSSound(named: NSSound.Name("Glass"))?.play()

        let screen = screenContainingMouse()
        let finalFrame = frame(on: screen)
        let startFrame = finalFrame.offsetBy(dx: 0, dy: 30)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        let window = BannerWindow(
            contentRect: reduceMotion ? finalFrame : startFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.ignoresMouseEvents = false
        window.isReleasedWhenClosed = false
        window.alphaValue = reduceMotion ? 1 : 0

        let view = InAppBannerView(
            title: title,
            quote: quote,
            accent: accent,
            onDismiss: { [weak self] in self?.dismiss() },
            onHoverChanged: { [weak self] hovering in self?.setHovered(hovering) }
        )
        .frame(width: size.width, height: size.height)

        let host = NSHostingView(rootView: view)
        host.wantsLayer = true
        host.layer?.cornerRadius = 16
        host.layer?.masksToBounds = true
        window.contentView = host

        self.window = window
        window.orderFrontRegardless()

        if !reduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().setFrame(finalFrame, display: true)
                window.animator().alphaValue = 1
            }
        }

        scheduleDismiss()
    }

    func dismiss() {
        dismissTask?.cancel()
        guard let window else { return }
        self.window = nil

        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            window.orderOut(nil)
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        } completionHandler: {
            window.orderOut(nil)
        }
    }

    private func setHovered(_ hovering: Bool) {
        isHovered = hovering
        if !hovering {
            scheduleDismiss(after: 2)
        }
    }

    private func scheduleDismiss(after seconds: Int64 = 8) {
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                if self.isHovered {
                    self.scheduleDismiss(after: 1)
                } else {
                    self.dismiss()
                }
            }
        }
    }

    private func screenContainingMouse() -> NSScreen {
        let point = NSEvent.mouseLocation
        return NSScreen.screens.first { screen in
            NSMouseInRect(point, screen.frame, false)
        } ?? NSScreen.main ?? NSScreen.screens.first!
    }

    private func frame(on screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        return NSRect(
            x: visible.maxX - size.width - inset,
            y: visible.maxY - size.height - inset,
            width: size.width,
            height: size.height
        )
    }
}

private final class BannerWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

struct InAppBannerView: View {
    let title: String
    let quote: Quote
    let accent: Color
    let onDismiss: () -> Void
    let onHoverChanged: (Bool) -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 38, height: 38)
                    .blur(radius: 8)
                Image(systemName: "moon.stars.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(accent)
                    .shadow(color: accent.opacity(0.35), radius: 10)
                    .accessibilityHidden(true)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(quote.text)
                    .font(.subheadline)
                    .foregroundStyle(.primary.opacity(0.86))
                    .lineLimit(2)
                    .truncationMode(.tail)
                if let author = quote.author, !author.isEmpty {
                    Text("— \(author)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture(perform: onDismiss)
        .onHover(perform: onHoverChanged)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(quote.text)")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var background: some View {
        if reduceTransparency {
            Color(nsColor: .windowBackgroundColor)
        } else {
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                accent.opacity(0.10)
                LinearGradient(
                    colors: [Color.indigo.opacity(0.18), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}
