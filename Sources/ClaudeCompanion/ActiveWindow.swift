import AppKit
import CoreGraphics

/// Locates the window the user is actually working in.
///
/// Uses `CGWindowListCopyWindowInfo`, which reports window geometry and owning
/// process without needing the Accessibility *or* Screen Recording permission -
/// only window *titles* and *images* are gated by those. The Accessibility API
/// (`AXUIElement`) would do the same job but costs the user a permission prompt.
enum ActiveWindow {
    /// Windows below this size are toolbars, tooltips, and notification banners
    /// rather than something a person is working in.
    private static let minimumSize = CGSize(width: 120, height: 80)

    /// The frontmost normal window of `pid` that is genuinely on a display, in
    /// Cocoa screen coordinates, together with the screen showing it.
    ///
    /// Windows belonging to full-screen apps on *other* Spaces are reported at
    /// parked coordinates outside the real display arrangement (several unrelated
    /// apps share one bogus origin), so any window that fails to land on a screen
    /// is skipped rather than used to position anything.
    static func focusedWindow(ofPID pid: pid_t) -> (frame: CGRect, screen: NSScreen)? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID)
            as? [[String: Any]] else { return nil }

        // The list is ordered front to back, so the first usable match is the one
        // the user is working in.
        for window in windows {
            guard let owner = window[kCGWindowOwnerPID as String] as? pid_t, owner == pid,
                  // Layer 0 is a normal application window.
                  let layer = window[kCGWindowLayer as String] as? Int, layer == 0,
                  let boundsDict = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict)
            else { continue }

            guard bounds.width >= minimumSize.width,
                  bounds.height >= minimumSize.height else { continue }

            let frame = cocoaFrame(fromDisplayFrame: bounds)
            guard let screen = screen(containing: frame) else {
                Log.info("skipping off-display window at \(bounds.origin) (other Space)")
                continue
            }
            return (frame, screen)
        }
        return nil
    }

    /// The screen a Cocoa-space rect sits on, chosen by its centre point.
    private static func screen(containing frame: CGRect) -> NSScreen? {
        let centre = CGPoint(x: frame.midX, y: frame.midY)
        return NSScreen.screens.first { $0.frame.contains(centre) }
            // A window can be dragged partly off-screen; fall back to any overlap.
            ?? NSScreen.screens.first { $0.frame.intersects(frame) }
    }

    /// Core Graphics window bounds use the primary display's top-left as the origin
    /// with y growing downward; Cocoa uses its bottom-left with y growing upward.
    private static func cocoaFrame(fromDisplayFrame frame: CGRect) -> CGRect {
        // `NSScreen.screens.first` is the primary display, which defines the origin
        // of both coordinate systems.
        guard let primary = NSScreen.screens.first else { return frame }
        return CGRect(
            x: frame.origin.x,
            y: primary.frame.maxY - frame.origin.y - frame.height,
            width: frame.width,
            height: frame.height
        )
    }
}
