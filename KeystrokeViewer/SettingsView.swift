import SwiftUI
import ServiceManagement
import AppKit

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        TabView {
            GeneralTab()
                .environmentObject(settings)
                .tabItem { Label("General", systemImage: "gear") }
            AppearanceTab()
                .environmentObject(settings)
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            KeysTab()
                .environmentObject(settings)
                .tabItem { Label("Keys", systemImage: "keyboard") }
            PresetsTab()
                .environmentObject(settings)
                .tabItem { Label("Presets", systemImage: "star") }
        }
        .frame(width: 480, height: 520)
        .padding()
    }
}

// MARK: - General

private struct GeneralTab: View {
    @EnvironmentObject var settings: AppSettings
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @StateObject private var recorder = ShortcutRecorderState()
    @State private var audioDevices = AudioOutputDevice.availableDevices()

    var body: some View {
        Form {
            Section("Overlay") {
                Toggle("Show overlay", isOn: $settings.overlayEnabled)
            }
            Section("Toggle Shortcut") {
                HStack {
                    Text(recorder.isRecording ? "Press shortcut…" : settings.toggleShortcutLabel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(recorder.isRecording
                                      ? Color.accentColor.opacity(0.15)
                                      : Color.secondary.opacity(0.08))
                        )
                    Button(recorder.isRecording ? "Cancel" : "Record") {
                        if recorder.isRecording {
                            recorder.stopRecording()
                        } else {
                            recorder.startRecording { keyCode, mods, display in
                                settings.toggleKeyCode = keyCode
                                settings.toggleModifiers = mods
                                settings.toggleKeyDisplay = display
                            }
                        }
                    }
                    .frame(width: 60)
                    if settings.toggleKeyCode >= 0 && !recorder.isRecording {
                        Button("Clear") {
                            settings.toggleKeyCode = -1
                            settings.toggleModifiers = 0
                            settings.toggleKeyDisplay = ""
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                Text("Press Delete while recording to clear. At least one modifier key (⌃⌥⇧⌘) is required.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }
            Section("Mouse") {
                Toggle("Show mouse click animation", isOn: $settings.showMouseClicks)
            }
            Section("Sound") {
                Toggle("Keystroke sound", isOn: $settings.soundEnabled)
                if settings.soundEnabled {
                    Picker("Style", selection: $settings.soundStyle) {
                        ForEach(SoundStyle.allCases) { style in
                            Text(style.label).tag(style.rawValue)
                        }
                    }
                    Picker("Output", selection: $settings.soundOutputDeviceUID) {
                        Text("System Default").tag("")
                        ForEach(audioDevices) { device in
                            Text(device.name).tag(device.id)
                        }
                    }
                    SliderRow(label: "Volume", value: $settings.soundVolume,
                              range: 0.1...1.0, format: { String(format: "%.0f%%", $0 * 100) })
                }
            }
            Section("Privacy") {
                Toggle("Hide keystrokes in password fields", isOn: $settings.hideInSecureFields)
            }
            Section {
                Text("Eger tuslar gozukmuyorsa: System Settings -> Privacy & Security -> Accessibility menusunden Keystroke Viewer'a izin ver, sonra uygulamayi yeniden baslat.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onDisappear { recorder.stopRecording() }
    }
}

// MARK: - Appearance

private struct AppearanceTab: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Theme") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72))], spacing: 8) {
                    ForEach(KeyTheme.presets) { theme in
                        ThemePreview(theme: theme, isSelected: settings.selectedThemeId == theme.id)
                            .onTapGesture { settings.selectedThemeId = theme.id }
                    }
                    ThemePreview(
                        theme: KeyTheme(id: "custom", name: "Custom",
                                        keyHex: settings.customKeyColorHex,
                                        textHex: settings.customTextColorHex),
                        isSelected: settings.selectedThemeId == "custom",
                        isCustom: true
                    )
                    .onTapGesture { settings.selectedThemeId = "custom" }
                }
            }

            if settings.selectedThemeId == "custom" {
                Section("Custom Colors") {
                    ColorPicker("Key background",
                                selection: colorBinding(
                                    get: { settings.customKeyColorHex },
                                    set: { settings.customKeyColorHex = $0 }),
                                supportsOpacity: false)
                    ColorPicker("Key text",
                                selection: colorBinding(
                                    get: { settings.customTextColorHex },
                                    set: { settings.customTextColorHex = $0 }),
                                supportsOpacity: false)
                }
            }

            Section("Animation") {
                Picker("Style", selection: $settings.animationStyle) {
                    ForEach(AnimationStyle.allCases) { style in
                        Text(style.label).tag(style.rawValue)
                    }
                }
            }

            Section("Display") {
                Picker("Position", selection: $settings.position) {
                    ForEach(OverlayPosition.allCases) { p in
                        Text(p.label).tag(p)
                    }
                }
                Toggle("Show on all screens", isOn: $settings.displayOnAllScreens)
                Picker("Font", selection: $settings.fontStyle) {
                    ForEach(FontStyle.allCases) { style in
                        Text(style.label).tag(style.rawValue)
                    }
                }
                SliderRow(label: "Font size", value: $settings.fontSize,
                          range: 16...48, step: 1, format: { "\(Int($0))" })
                SliderRow(label: "Key size", value: $settings.keyScale,
                          range: 0.5...2.0, step: 0.1, format: { String(format: "%.0f%%", $0 * 100) })
                SliderRow(label: "Opacity", value: $settings.opacity,
                          range: 0.3...1.0, format: { String(format: "%.0f%%", $0 * 100) })
            }
        }
        .formStyle(.grouped)
    }

    private func colorBinding(get: @escaping () -> String,
                              set: @escaping (String) -> Void) -> Binding<CGColor> {
        Binding(
            get: {
                let (r, g, b) = KeyTheme.rgb(from: get())
                return CGColor(srgbRed: r, green: g, blue: b, alpha: 1)
            },
            set: { cgColor in
                guard let srgb = cgColor.converted(
                    to: CGColorSpace(name: CGColorSpace.sRGB)!,
                    intent: .defaultIntent, options: nil
                ), let c = srgb.components, c.count >= 3 else { return }
                set(String(format: "#%02X%02X%02X",
                           Int(c[0] * 255), Int(c[1] * 255), Int(c[2] * 255)))
            }
        )
    }
}

// MARK: - Theme Preview

private struct ThemePreview: View {
    let theme: KeyTheme
    let isSelected: Bool
    var isCustom: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(LinearGradient(
                    colors: theme.gradientColors,
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: 44, height: 36)
                .overlay {
                    if isCustom {
                        Image(systemName: "paintpalette")
                            .font(.system(size: 14))
                            .foregroundStyle(theme.textColor)
                    } else {
                        Text("A")
                            .font(.system(size: 16, weight: .light))
                            .foregroundStyle(theme.textColor)
                    }
                }
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.accentColor, lineWidth: 2)
                    }
                }
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)

            Text(theme.name)
                .font(.caption2)
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .padding(6)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.1))
            }
        }
    }
}

// MARK: - Keys

private struct KeysTab: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Display Time") {
                SliderRow(label: "Duration", value: $settings.displayTime,
                          range: 0.5...5.0, step: 0.1, format: { String(format: "%.1fs", $0) })
            }
            Section("Key Groups") {
                Toggle("Alphanumeric (A-Z, 0-9, symbols)", isOn: $settings.showAlphanumeric)
                Toggle("Modifiers (⌘ ⇧ ⌥ ⌃)", isOn: $settings.showModifiers)
                Toggle("Function keys (F1–F15)", isOn: $settings.showFunctionKeys)
                Toggle("Navigation (arrows, Home, End, PgUp/Dn)", isOn: $settings.showNavigation)
                Toggle("Special keys (Return, Tab, Delete, Space, Esc)", isOn: $settings.showSpecialKeys)
                Toggle("Caps Lock", isOn: $settings.showCapsLock)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Presets

private struct PresetsTab: View {
    @EnvironmentObject var settings: AppSettings
    @State private var customPresets: [SavedPreset] = []
    @State private var showSaveAlert = false
    @State private var presetName = ""

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    presetName = ""
                    showSaveAlert = true
                } label: {
                    Label("Save Current Settings", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)

                Text("Built-in")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(QuickPreset.all) { preset in
                        PresetCard(name: preset.name, description: preset.description,
                                   icon: preset.icon, isActive: isBuiltInActive(preset))
                            .onTapGesture { preset.apply(to: settings) }
                    }
                }

                if !customPresets.isEmpty {
                    Text("My Presets")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(customPresets) { saved in
                            PresetCard(name: saved.name, description: saved.summary,
                                       icon: "bookmark.fill", isActive: isCustomActive(saved))
                                .onTapGesture { saved.apply(to: settings) }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        settings.deleteCustomPreset(id: saved.id)
                                        customPresets = settings.loadCustomPresets()
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .padding()
        }
        .onAppear { customPresets = settings.loadCustomPresets() }
        .alert("Save Preset", isPresented: $showSaveAlert) {
            TextField("Preset name", text: $presetName)
            Button("Save") {
                guard !presetName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                settings.saveCurrentAsPreset(name: presetName.trimmingCharacters(in: .whitespaces))
                customPresets = settings.loadCustomPresets()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a name for your preset")
        }
    }

    private func isBuiltInActive(_ preset: QuickPreset) -> Bool {
        settings.selectedThemeId == preset.themeId &&
        settings.animationStyle == preset.animationStyle &&
        settings.fontStyle == preset.fontStyle &&
        settings.position == preset.position
    }

    private func isCustomActive(_ saved: SavedPreset) -> Bool {
        settings.selectedThemeId == saved.themeId &&
        settings.animationStyle == saved.animationStyle &&
        settings.fontStyle == saved.fontStyle &&
        settings.position.rawValue == saved.position
    }
}

private struct PresetCard: View {
    let name: String
    let description: String
    let icon: String
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(isActive ? Color.accentColor : .primary)
                Text(name)
                    .font(.headline)
            }
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isActive ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isActive ? Color.accentColor : Color.secondary.opacity(0.15), lineWidth: isActive ? 2 : 0.5)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Shortcut Recorder

private final class ShortcutRecorderState: ObservableObject {
    @Published var isRecording = false
    private var monitor: Any?
    private var onComplete: ((Int, Int, String) -> Void)?

    func startRecording(onComplete: @escaping (Int, Int, String) -> Void) {
        self.onComplete = onComplete
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 {
                self.stopRecording()
                return nil
            }
            if event.keyCode == 51 {
                self.onComplete?(-1, 0, "")
                self.stopRecording()
                return nil
            }
            let mods = event.modifierFlags.intersection([.control, .option, .shift, .command])
            guard !mods.isEmpty else { return event }
            let display = event.charactersIgnoringModifiers?.uppercased() ?? ""
            self.onComplete?(Int(event.keyCode), Int(mods.rawValue), display)
            self.stopRecording()
            return nil
        }
    }

    func stopRecording() {
        isRecording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        onComplete = nil
    }

    deinit { stopRecording() }
}

// MARK: - Slider Row

private struct SliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double? = nil
    let format: (Double) -> String

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 80, alignment: .leading)
            if let step {
                Slider(value: $value, in: range, step: step)
            } else {
                Slider(value: $value, in: range)
            }
            Text(format(value))
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
        }
    }
}
