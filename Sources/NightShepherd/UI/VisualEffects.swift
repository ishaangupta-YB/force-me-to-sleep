import SwiftUI
import AppKit

/// SwiftUI wrapper over `NSVisualEffectView`. On macOS 26 Tahoe these views
/// pick up the system "Liquid Glass" treatment automatically.
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .followsWindowActiveState
    var isEmphasized: Bool = false

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.isEmphasized = isEmphasized
        view.autoresizingMask = [.width, .height]
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
        nsView.isEmphasized = isEmphasized
    }
}

/// Background that honors `accessibilityReduceTransparency` automatically.
/// Use anywhere a vibrant material is wanted.
struct GlassBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var material: NSVisualEffectView.Material = .hudWindow

    var body: some View {
        if reduceTransparency {
            Color(nsColor: .windowBackgroundColor)
        } else {
            VisualEffectView(material: material, blendingMode: .behindWindow)
        }
    }
}
