import AppKit
import SwiftUI
import ApplicationServices
import AVFoundation
import CoreAudio
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
    private var soundManager: SoundManager?
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        overlay = OverlayController(settings: settings)
        startMonitorIfPermitted()
        setupHotkeyMonitor()
        soundManager = SoundManager()
        soundManager?.settings = settings

        if !UserDefaults.standard.bool(forKey: "onboardingCompleted") {
            showOnboarding()
        }
    }

    private func showOnboarding() {
        let view = OnboardingView {
            UserDefaults.standard.set(true, forKey: "onboardingCompleted")
            self.onboardingWindow?.close()
            self.onboardingWindow = nil
            DispatchQueue.main.async {
                NSApp.setActivationPolicy(.accessory)
            }
        }
        let host = NSHostingController(rootView: view)
        let win = NSWindow(contentViewController: host)
        win.title = "Welcome to Keystroke Viewer"
        win.styleMask = [.titled, .closable]
        win.isReleasedWhenClosed = false
        win.setContentSize(NSSize(width: 480, height: 400))
        win.center()
        onboardingWindow = win

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
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

        let themeMenu = NSMenu()
        for theme in KeyTheme.presets {
            let item = NSMenuItem(title: theme.name, action: #selector(selectTheme(_:)), keyEquivalent: "")
            item.representedObject = theme.id
            themeMenu.addItem(item)
        }
        let themeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        themeItem.submenu = themeMenu
        themeItem.tag = 10
        menu.addItem(themeItem)

        let presetMenu = NSMenu()
        for preset in QuickPreset.all {
            let item = NSMenuItem(title: preset.name, action: #selector(selectPreset(_:)), keyEquivalent: "")
            item.representedObject = preset.id
            presetMenu.addItem(item)
        }
        let presetItem = NSMenuItem(title: "Preset", action: nil, keyEquivalent: "")
        presetItem.submenu = presetMenu
        presetItem.tag = 11
        menu.addItem(presetItem)

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

    @objc private func selectTheme(_ sender: NSMenuItem) {
        guard let themeId = sender.representedObject as? String else { return }
        settings.selectedThemeId = themeId
    }

    @objc private func selectPreset(_ sender: NSMenuItem) {
        guard let presetId = sender.representedObject as? String,
              let preset = QuickPreset.all.first(where: { $0.id == presetId }) else { return }
        preset.apply(to: settings)
    }

    private func startMonitorIfPermitted() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        if trusted {
            if !startMonitor() {
                Self.logger.warning("Tap creation failed despite trusted status, polling…")
                startRetryTimer()
            }
        } else {
            Self.logger.warning("Accessibility permission not granted yet, polling…")
            startRetryTimer()
        }
    }

    private func startRetryTimer() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            if self.startMonitor() {
                timer.invalidate()
                self.permissionTimer = nil
            }
        }
    }

    @discardableResult
    private func startMonitor() -> Bool {
        monitor?.stop()
        monitor = KeyMonitor { [weak self] event in
            DispatchQueue.main.async {
                self?.overlay?.push(event)
                self?.soundManager?.playClick()
            }
        }
        monitor?.settings = settings
        let success = monitor?.start() ?? false
        if success {
            Self.logger.info("Key monitor started")
        }
        return success
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
        if let themeMenu = menu.item(withTag: 10)?.submenu {
            for item in themeMenu.items {
                item.state = (item.representedObject as? String) == settings.selectedThemeId ? .on : .off
            }
        }
        if let presetMenu = menu.item(withTag: 11)?.submenu {
            for item in presetMenu.items {
                guard let presetId = item.representedObject as? String,
                      let preset = QuickPreset.all.first(where: { $0.id == presetId }) else { continue }
                let active = settings.selectedThemeId == preset.themeId &&
                             settings.animationStyle == preset.animationStyle &&
                             settings.fontStyle == preset.fontStyle &&
                             settings.position == preset.position
                item.state = active ? .on : .off
            }
        }
    }
}

// MARK: - Sound Manager

final class SoundManager {
    weak var settings: AppSettings?
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    private var buffers: [SoundStyle: AVAudioPCMBuffer] = [:]
    private var currentDeviceUID = ""

    init() {
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: audioFormat)
        try? engine.start()
        for style in SoundStyle.allCases {
            buffers[style] = generateBuffer(for: style)
        }
    }

    func playClick() {
        guard let settings, settings.soundEnabled else { return }

        if settings.soundOutputDeviceUID != currentDeviceUID {
            applyOutputDevice(uid: settings.soundOutputDeviceUID)
        }

        let style = SoundStyle(rawValue: settings.soundStyle) ?? .mxBlue
        guard let buffer = buffers[style] else { return }
        if !engine.isRunning { try? engine.start() }
        playerNode.volume = Float(settings.soundVolume)
        playerNode.scheduleBuffer(buffer, completionHandler: nil)
        playerNode.play()
    }

    private func applyOutputDevice(uid: String) {
        currentDeviceUID = uid

        let deviceID: AudioDeviceID
        if uid.isEmpty {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var defaultID: AudioDeviceID = 0
            var size = UInt32(MemoryLayout<AudioDeviceID>.size)
            guard AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address, 0, nil, &size, &defaultID
            ) == noErr else { return }
            deviceID = defaultID
        } else {
            guard let resolved = deviceIDForUID(uid) else { return }
            deviceID = resolved
        }

        engine.stop()
        var mutableID = deviceID
        if let au = engine.outputNode.audioUnit {
            AudioUnitSetProperty(
                au,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &mutableID,
                UInt32(MemoryLayout<AudioDeviceID>.size)
            )
        }
        try? engine.start()
    }

    private func deviceIDForUID(_ uid: String) -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &dataSize
        ) == noErr else { return nil }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &dataSize, &ids
        ) == noErr else { return nil }

        for id in ids {
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var deviceUID: CFString = "" as CFString
            var uidSize = UInt32(MemoryLayout<CFString>.size)
            guard AudioObjectGetPropertyData(
                id, &uidAddress, 0, nil, &uidSize, &deviceUID
            ) == noErr else { continue }
            if (deviceUID as String) == uid { return id }
        }
        return nil
    }

    private struct ClickParams {
        let duration: Double
        let tones: [(freq: Double, amp: Double, decay: Double)]
        let noiseAmp: Double
        let noiseDecay: Double
    }

    private func params(for style: SoundStyle) -> ClickParams {
        switch style {
        case .mxBlue:
            return ClickParams(duration: 0.025,
                tones: [(2800, 0.6, 180), (5500, 0.3, 500)],
                noiseAmp: 0.20, noiseDecay: 350)
        case .mxBrown:
            return ClickParams(duration: 0.022,
                tones: [(2200, 0.5, 220), (4000, 0.15, 600)],
                noiseAmp: 0.12, noiseDecay: 400)
        case .mxRed:
            return ClickParams(duration: 0.018,
                tones: [(1800, 0.35, 280), (3200, 0.08, 700)],
                noiseAmp: 0.06, noiseDecay: 500)
        case .topre:
            return ClickParams(duration: 0.035,
                tones: [(800, 0.5, 100), (1500, 0.3, 180), (3000, 0.1, 400)],
                noiseAmp: 0.06, noiseDecay: 200)
        case .bucklingSpring:
            return ClickParams(duration: 0.038,
                tones: [(3500, 0.5, 130), (7000, 0.25, 350), (1200, 0.3, 90)],
                noiseAmp: 0.25, noiseDecay: 280)
        case .typewriter:
            return ClickParams(duration: 0.032,
                tones: [(1000, 0.5, 160), (4500, 0.2, 500), (500, 0.3, 120)],
                noiseAmp: 0.18, noiseDecay: 250)
        case .bubble:
            return ClickParams(duration: 0.030,
                tones: [(600, 0.5, 100), (1200, 0.3, 150)],
                noiseAmp: 0.03, noiseDecay: 500)
        case .minimal:
            return ClickParams(duration: 0.012,
                tones: [(3000, 0.3, 400)],
                noiseAmp: 0.04, noiseDecay: 600)
        }
    }

    private func generateBuffer(for style: SoundStyle) -> AVAudioPCMBuffer? {
        let p = params(for: style)
        let sampleRate: Double = 44100
        let frameCount = AVAudioFrameCount(sampleRate * p.duration)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else { return nil }

        buffer.frameLength = frameCount
        guard let data = buffer.floatChannelData?[0] else { return nil }

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            var sample = 0.0
            for tone in p.tones {
                sample += sin(2.0 * .pi * tone.freq * t) * tone.amp * exp(-t * tone.decay)
            }
            if p.noiseAmp > 0 {
                sample += Double.random(in: -1...1) * p.noiseAmp * exp(-t * p.noiseDecay)
            }
            data[i] = Float(sample)
        }

        return buffer
    }
}
