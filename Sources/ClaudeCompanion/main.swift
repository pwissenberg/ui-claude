import AppKit

// AppKit swallows some exceptions raised inside delegate callbacks, which makes a
// half-initialised app look like a silent hang. Log them instead.
NSSetUncaughtExceptionHandler { exception in
    Log.error("uncaught exception: \(exception.name.rawValue): \(exception.reason ?? "-")")
}

// Entry point. We drive NSApplication manually (rather than @main SwiftUI App)
// so we get full control over an accessory (menu-bar-only) app with a custom
// floating NSPanel.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// .accessory = no Dock icon, no menu bar app menu. Lives in the status bar only.
app.setActivationPolicy(.accessory)
app.run()
