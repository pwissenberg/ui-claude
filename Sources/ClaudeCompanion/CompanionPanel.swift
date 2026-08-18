import AppKit

extension NSImage {
    /// A resizable rounded-rectangle mask for `NSVisualEffectView.maskImage`.
    ///
    /// A layer `cornerRadius` rounds the view's *contents* but does not clip the
    /// backdrop blur, which keeps sampling the full square window bounds - visible
    /// as a bright halo around the panel over a light background. `maskImage` masks
    /// the effect itself, so the blur stops at the rounded edge.
    ///
    /// Cap insets make the middle stretch, so one small image fits any panel size.
    static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.set()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

/// A borderless floating panel that CAN take keyboard focus.
///
/// By default a borderless `NSWindow`/`NSPanel` returns `false` from
/// `canBecomeKey`, which would stop the embedded web view from receiving typed
/// text. Overriding these two properties lets the user type into Claude while
/// keeping the clean, chrome-less rounded look.
final class CompanionPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// Pressing Escape dismisses the panel (AppKit routes Esc to cancelOperation).
    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }
}
