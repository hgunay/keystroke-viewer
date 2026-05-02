import AppKit
import SwiftUI
import ApplicationServices
import os

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let logger = Logger(subsystem: "com.example.KeystrokeViewer", category: "App")

    let settings = AppSettings()
    private var overlay: OverlayController?
    private var monitor: KeyMonitor?
    private var statusItem: NSStatusItem?
    private var permissionTimer: Timer?
    private var prefsWindow: NSWindow?
    private var hotkeyGlobalMonitor: Any?
    private var hotkeyLocalMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        overlay = OverlayController(settings: settings)
        startMonitorIfPermitted()
        setupHotkeyMonitor()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Keystroke Viewer")
        }

        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: "Show Overlay", action: #selector(toggleOverlay), keyEquivalent: "")
        toggleItem.tag = 1
        toggleItem.state = settings.overlayEnabled ? .on : .off
        menu.addItem(toggleItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(openPrefs), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Keystroke Viewer", action: #selector(quitApp), keyEquivalent: "q"))

        menu.delegate = self
        statusItem?.menu = menu
    }

    private func setupHotkeyMonitor() {
        hotkeyGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleHotkey(event)
        }
        hotkeyLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if self.prefsWindow?.isKeyWindow == true { return event }
            if self.handleHotkey(event) { return nil }
            return event
        }
    }

    @discardableResult
    private func handleHotkey(_ event: NSEvent) -> Bool {
        guard settings.toggleKeyCode >= 0 else { return false }
        let mods = event.modifierFlags.intersection([.control, .option, .shift, .command])
        guard Int(event.keyCode) == settings.toggleKeyCode,
              Int(mods.rawValue) == settings.toggleModifiers else { return false }
        settings.overlayEnabled.toggle()
        return true
    }

    @objc private func toggleOverlay() {
        settings.overlayEnabled.toggle()
    }

    private func startMonitorIfPermitted() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        if trusted {
            startMonitor()
        } else {
            Self.logger.warning("Accessibility permission not granted yet, polling…")
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                if AXIsProcessTrusted() {
                    timer.invalidate()
                    self?.permissionTimer = nil
                    DispatchQueue.main.async { self?.startMonitor() }
                }
            }
        }
    }

    private func startMonitor() {
        monitor = KeyMonitor { [weak self] event in
            DispatchQueue.main.async {
                self?.overlay?.push(event)
            }
        }
        monitor?.start()
        Self.logger.info("Key monitor started")
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func openPrefs() {
        if let win = prefsWindow {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            win.makeKeyAndOrderFront(nil)
            return
        }

        let view = SettingsView().environmentObject(settings)
        let host = NSHostingController(rootView: view)

        let win = NSWindow(contentViewController: host)
        win.title = "Keystroke Viewer Preferences"
        win.styleMask = [.titled, .closable, .miniaturizable]
        win.isReleasedWhenClosed = false
        win.center()
        win.delegate = self
        prefsWindow = win

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        if let item = menu.item(withTag: 1) {
            item.state = settings.overlayEnabled ? .on : .off
        }
    }
}
