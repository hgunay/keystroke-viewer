import Cocoa
import Carbon.HIToolbox

private func isSecureInputActive() -> Bool {
    IsSecureEventInputEnabled()
}

struct KeyEvent: Identifiable {
    var id = UUID()
    let chars: String
    let keyCode: UInt16
    let modifiers: NSEvent.ModifierFlags
    let isModifierOnly: Bool
    let timestamp: Date
    var repeatCount: Int = 1

    static let kVK_CapsLock: UInt16 = 0x39
}

final class KeyMonitor {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var flagsMonitor: Any?
    private var lastCapsState = false
    private var lastCapsFireTime: Date = .distantPast
    private let onKey: (KeyEvent) -> Void
    weak var settings: AppSettings?

    init(onKey: @escaping (KeyEvent) -> Void) {
        self.onKey = onKey
    }

    @discardableResult
    func start() -> Bool {
        lastCapsState = NSEvent.modifierFlags.contains(.capsLock)

        let mask = (1 << CGEventType.keyDown.rawValue) |
                   (1 << CGEventType.flagsChanged.rawValue)

        let callback: CGEventTapCallBack = { _, type, cgEvent, ctx in
            guard let ctx else { return Unmanaged.passUnretained(cgEvent) }
            let me = Unmanaged<KeyMonitor>.fromOpaque(ctx).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = me.tap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passUnretained(cgEvent)
            }

            guard type == .keyDown || type == .flagsChanged else {
                return Unmanaged.passUnretained(cgEvent)
            }

            if type == .keyDown,
               let s = me.settings,
               s.hideInSecureFields,
               isSecureInputActive() {
                return Unmanaged.passUnretained(cgEvent)
            }

            guard let nsEvent = NSEvent(cgEvent: cgEvent) else {
                return Unmanaged.passUnretained(cgEvent)
            }

            let modifierOnly = (type == .flagsChanged)
            if type == .keyDown && nsEvent.isARepeat { return Unmanaged.passUnretained(cgEvent) }
            let chars = modifierOnly ? "" : (nsEvent.charactersIgnoringModifiers ?? "")
            let isCaps = modifierOnly && nsEvent.keyCode == KeyEvent.kVK_CapsLock
            if isCaps {
                me.lastCapsFireTime = Date()
                me.lastCapsState = nsEvent.modifierFlags.contains(.capsLock)
            }
            let event = KeyEvent(
                chars: chars,
                keyCode: nsEvent.keyCode,
                modifiers: nsEvent.modifierFlags,
                isModifierOnly: modifierOnly,
                timestamp: Date()
            )
            me.onKey(event)
            return Unmanaged.passUnretained(cgEvent)
        }

        let ctx = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: ctx
        ) else {
            NSLog("Keystroke Viewer: CGEventTap kurulamadi (Accessibility izni?)")
            return false
        }

        self.tap = tap
        self.source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] nsEvent in
            guard let self else { return }
            let newCaps = nsEvent.modifierFlags.contains(.capsLock)
            guard newCaps != self.lastCapsState else { return }
            self.lastCapsState = newCaps

            if Date().timeIntervalSince(self.lastCapsFireTime) < 0.15 { return }

            let event = KeyEvent(
                chars: "",
                keyCode: KeyEvent.kVK_CapsLock,
                modifiers: nsEvent.modifierFlags,
                isModifierOnly: true,
                timestamp: Date()
            )
            self.onKey(event)
        }
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes) }
        if let flagsMonitor { NSEvent.removeMonitor(flagsMonitor) }
        tap = nil
        source = nil
        flagsMonitor = nil
    }
}
