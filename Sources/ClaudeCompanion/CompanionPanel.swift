import AppKit

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
