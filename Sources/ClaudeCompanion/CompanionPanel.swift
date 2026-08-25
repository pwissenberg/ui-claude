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

    /// Makes the standard editing shortcuts work.
    ///
    /// AppKit turns ⌘V into a `paste:` action by matching it against the Edit menu's
    /// key equivalents. A menu-bar-only app has no main menu, so that match never
    /// happens and the keystroke is simply dropped - you can type into Claude but
    /// not paste, copy, or select all. Dispatching the actions down the responder
    /// chain ourselves restores them without needing a menu to exist.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }
        // Anything with extra modifiers (⌘⌥, ⌘⌃) is not one of these shortcuts.
        guard flags.subtracting([.command, .shift]).isEmpty else {
            return super.performKeyEquivalent(with: event)
        }

        let action: Selector?
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "x": action = #selector(NSText.cut(_:))
        case "c": action = #selector(NSText.copy(_:))
        case "v": action = flags.contains(.shift)
            // ⌘⇧V is paste-and-match-style, which WebKit maps to pasting as plain text.
            ? Selector(("pasteAsPlainText:"))
            : #selector(NSText.paste(_:))
        case "a": action = #selector(NSText.selectAll(_:))
        // ⌘N starts a fresh conversation. There is no menu to carry the shortcut,
        // so it is dispatched here like the editing ones.
        case "n": action = #selector(AppDelegate.newChat(_:))
        case "z": action = flags.contains(.shift) ? Selector(("redo:")) : Selector(("undo:"))
        default: action = nil
        }

        if let action, NSApp.sendAction(action, to: nil, from: self) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
