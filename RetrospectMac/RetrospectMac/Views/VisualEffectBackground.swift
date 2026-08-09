import SwiftUI
import AppKit

/// A frosted glass background backed by `NSVisualEffectView`, blending the desktop behind
/// the window. Used as the outer "card" surface.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blending
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blending
        view.state = .active
    }
}

/// Makes the host window translucent (so the glass shows the desktop through) and pins it to
/// the light appearance, since the journal is a fixed ink-on-cream surface.
struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarAppearsTransparent = true
            window.appearance = NSAppearance(named: .aqua)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
