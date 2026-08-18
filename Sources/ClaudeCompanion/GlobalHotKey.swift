import AppKit
import Carbon.HIToolbox

/// A key + modifier combination, with a human-readable label for the UI.
struct KeyCombo {
    let keyCode: UInt32
    let modifiers: UInt32
    let label: String

    static let optionSpace = KeyCombo(
        keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey), label: "⌥Space")
    static let commandOptionSpace = KeyCombo(
        keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey | optionKey), label: "⌘⌥Space")
    static let controlOptionSpace = KeyCombo(
        keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey | optionKey), label: "⌃⌥Space")
    static let optionC = KeyCombo(
        keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(optionKey), label: "⌥C")
    static let commandOptionC = KeyCombo(
        keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(cmdKey | optionKey), label: "⌘⌥C")
}

/// Registers a system-wide hot key using the Carbon Hot Key API.
///
/// Carbon (`RegisterEventHotKey`) is used rather than an NSEvent global monitor or
/// a CGEventTap because Carbon hot keys do NOT require the Accessibility
/// permission - they work the moment the app launches, with no TCC prompt.
///
/// Important: a combo can only be owned by ONE process at a time. If another app
/// already holds it (e.g. the ChatGPT desktop app holds ⌥Space), registration
/// fails with `eventHotKeyExistsErr` - which is why `register` reports status
/// instead of failing silently.
final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    /// Called on the main thread whenever the hot key is pressed.
    var onPress: (() -> Void)?

    /// The combo that is currently registered, if any.
    private(set) var activeCombo: KeyCombo?

    init() {
        installHandler()
    }

    private func installHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userData) -> OSStatus in
                guard let userData else { return noErr }
                let this = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { this.onPress?() }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
    }

    /// Attempts to register a single combo.
    /// - Returns: `noErr` on success, or the Carbon error (e.g.
    ///   `eventHotKeyExistsErr` = -9878 when another app owns the combo).
    @discardableResult
    func register(_ combo: KeyCombo) -> OSStatus {
        unregister()

        // Four-char signature 'CLAU' as a stable ID for our single hot key.
        let hotKeyID = EventHotKeyID(signature: OSType(0x434C_4155), id: 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            combo.keyCode,
            combo.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        if status == noErr, let ref {
            hotKeyRef = ref
            activeCombo = combo
        } else {
            Log.warn("hot key \(combo.label) unavailable (OSStatus \(status)"
                + (status == -9878 ? ", already owned by another app" : "") + ")")
        }
        return status
    }

    /// Tries each candidate in order and keeps the first one macOS grants us.
    /// - Returns: the combo that was successfully registered, or `nil` if all were taken.
    @discardableResult
    func registerFirstAvailable(_ candidates: [KeyCombo]) -> KeyCombo? {
        for combo in candidates where register(combo) == noErr {
            Log.info("hot key registered: \(combo.label)")
            return combo
        }
        Log.error("no hot key could be registered - use the menu bar icon instead")
        return nil
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        activeCombo = nil
    }

    deinit {
        unregister()
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
}
