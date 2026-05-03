import SwiftUI
import ServiceManagement
import AppKit
import AVFoundation

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
    @State private var showResetAlert = false
    @StateObject private var soundPreview = SoundPreview()

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
                    HStack {
                        Picker("Style", selection: $settings.soundStyle) {
                            ForEach(SoundStyle.allCases) { style in
                                Text(style.label).tag(style.rawValue)
                            }
                        }
                        Button {
                            soundPreview.playPreview(style: settings.soundStyle, volume: settings.soundVolume)
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .help("Preview sound")
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
            Section {
                Button(role: .destructive) {
                    showResetAlert = true
                } label: {
                    Label("Reset All Settings", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .formStyle(.grouped)
        .onDisappear { recorder.stopRecording() }
        .alert("Reset All Settings?", isPresented: $showResetAlert) {
            Button("Reset", role: .destructive) {
                settings.resetToDefaults()
                launchAtLogin = false
                try? SMAppService.mainApp.unregister()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will restore all settings to their default values. Custom presets will not be deleted.")
        }
    }
}

// MARK: - Appearance

private struct AppearanceTab: View {
    @EnvironmentObject var settings: AppSettings
    @State private var previewAnimating = false
    @State private var previewId = UUID()

    var body: some View {
        Form {
            Section {
                LivePreview(settings: settings, animating: $previewAnimating, previewId: previewId)
                    .frame(maxWidth: .infinity)
                    .frame(height: 70)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.black.opacity(0.85))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } header: {
                HStack {
                    Text("Preview")
                    Spacer()
                    Button {
                        previewId = UUID()
                        previewAnimating = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            previewAnimating = true
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Replay animation")
                }
            }

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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                    ForEach(AnimationStyle.allCases) { style in
                        AnimationPreviewCard(
                            style: style,
                            isSelected: settings.animationStyle == style.rawValue
                        )
                        .onTapGesture { settings.animationStyle = style.rawValue }
                    }
                }
            }

            Section("Display") {
                Toggle("Compact modifier combos", isOn: $settings.compactCombos)
                Toggle("Background bar", isOn: $settings.showBackgroundBar)
                if settings.showBackgroundBar {
                    Picker("Bar style", selection: $settings.backgroundBarStyle) {
                        ForEach(BackgroundBarStyle.allCases) { style in
                            Text(style.label).tag(style.rawValue)
                        }
                    }
                    if settings.resolvedBarStyle == .material {
                        Picker("Blur intensity", selection: $settings.backgroundBarMaterial) {
                            ForEach(BarMaterialIntensity.allCases) { intensity in
                                Text(intensity.label).tag(intensity.rawValue)
                            }
                        }
                    }
                    if settings.resolvedBarStyle == .solid || settings.resolvedBarStyle == .material {
                        ColorPicker("Bar color",
                                    selection: colorBinding(
                                        get: { settings.backgroundBarColorHex },
                                        set: { settings.backgroundBarColorHex = $0 }),
                                    supportsOpacity: false)
                    }
                    SliderRow(label: settings.resolvedBarStyle == .material ? "Tint" : "Opacity",
                              value: $settings.backgroundBarOpacity,
                              range: 0.1...1.0,
                              format: { String(format: "%.0f%%", $0 * 100) })
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Position")
                        .font(.body)
                    PositionMinimap(selection: $settings.position)
                }
                Picker("Screen", selection: $settings.screenDisplayMode) {
                    ForEach(ScreenDisplayMode.allCases) { mode in
                        Text(mode.label).tag(mode.rawValue)
                    }
                }
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
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if theme.isGlass {
                    if #available(macOS 26, *) {
                        Color.clear
                            .frame(width: 44, height: 36)
                            .glassEffect(in: .rect(cornerRadius: 6))
                    } else {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .frame(width: 44, height: 36)
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(theme.keyColor.opacity(0.15))
                            .frame(width: 44, height: 36)
                    }
                } else {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(LinearGradient(
                            colors: theme.gradientColors,
                            startPoint: .top, endPoint: .bottom
                        ))
                        .frame(width: 44, height: 36)
                }
            }
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
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.accentColor : (isHovered ? Color.accentColor.opacity(0.5) : .clear),
                        lineWidth: 2
                    )
            }
            .shadow(color: .black.opacity(isHovered ? 0.35 : 0.2), radius: isHovered ? 4 : 2, y: isHovered ? 2 : 1)

            Text(theme.name)
                .font(.caption2)
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .padding(6)
        .scaleEffect(isHovered ? 1.1 : 1.0)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.1))
            }
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
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

// MARK: - Live Preview

private struct LivePreview: View {
    @ObservedObject var settings: AppSettings
    @Binding var animating: Bool
    let previewId: UUID

    private var theme: KeyTheme { settings.activeTheme }
    private var fontStyle: FontStyle { settings.resolvedFontStyle }
    private var animStyle: AnimationStyle {
        AnimationStyle(rawValue: settings.animationStyle) ?? .fade
    }

    private let sampleKeys: [(symbol: String, label: String?)] = [
        ("⌘", "cmd"), ("⇧", "shift")
    ]
    private let sampleChar = "S"

    var body: some View {
        HStack(spacing: 14 * settings.keyScale) {
            if animating {
                if settings.compactCombos {
                    ComboPreviewKey(
                        modifiers: "⌘⇧",
                        char: sampleChar,
                        settings: settings
                    )
                    .transition(animStyle.transition)
                } else {
                    ForEach(sampleKeys.indices, id: \.self) { i in
                        SingleKey(
                            symbol: sampleKeys[i].symbol,
                            label: sampleKeys[i].label,
                            fontSize: settings.fontSize,
                            keyOpacity: settings.opacity,
                            keyScale: settings.keyScale,
                            theme: theme,
                            fontStyle: fontStyle
                        )
                        .transition(animStyle.transition)
                    }
                    SingleKey(
                        symbol: sampleChar,
                        fontSize: settings.fontSize,
                        keyOpacity: settings.opacity,
                        keyScale: settings.keyScale,
                        theme: theme,
                        fontStyle: fontStyle
                    )
                    .transition(animStyle.transition)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .id(previewId)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(animStyle.entranceAnimation) {
                    animating = true
                }
            }
        }
        .onChange(of: settings.animationStyle) { _ in replay() }
        .onChange(of: settings.selectedThemeId) { _ in replay() }
        .onChange(of: settings.fontStyle) { _ in replay() }
        .onChange(of: settings.compactCombos) { _ in replay() }
        .onChange(of: settings.customKeyColorHex) { _ in replay() }
        .onChange(of: settings.customTextColorHex) { _ in replay() }
    }

    private func replay() {
        withAnimation(animStyle.exitAnimation) {
            animating = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(animStyle.entranceAnimation) {
                animating = true
            }
        }
    }
}

private struct ComboPreviewKey: View {
    let modifiers: String
    let char: String
    let settings: AppSettings

    private var theme: KeyTheme { settings.activeTheme }
    private var scaledFontSize: CGFloat { settings.fontSize * settings.keyScale }
    private var keyUnit: CGFloat { 36 * settings.keyScale }
    private var cr: CGFloat { 6 * settings.keyScale }

    @ViewBuilder
    var body: some View {
        if theme.isGlass {
            glassPreview
        } else {
            classicPreview
        }
    }

    private var previewContent: some View {
        HStack(spacing: 2 * settings.keyScale) {
            Text(modifiers)
                .font(settings.resolvedFontStyle.font(size: scaledFontSize * 0.42))
                .foregroundStyle(theme.textColor.opacity(0.7))
            Text(char)
                .font(settings.resolvedFontStyle.font(size: scaledFontSize * 0.5, weight: .medium))
                .foregroundStyle(theme.textColor)
        }
        .padding(.horizontal, 10 * settings.keyScale)
        .frame(height: keyUnit)
    }

    @ViewBuilder
    private var glassPreview: some View {
        if #available(macOS 26, *) {
            previewContent
                .glassEffect(in: .rect(cornerRadius: cr))
                .opacity(settings.opacity)
        } else {
            previewContent
                .background {
                    ZStack {
                        Rectangle().fill(.ultraThinMaterial)
                        Rectangle().fill(theme.keyColor.opacity(0.15))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
                .opacity(settings.opacity)
        }
    }

    private var classicPreview: some View {
        previewContent
            .background(LinearGradient(colors: theme.gradientColors, startPoint: .top, endPoint: .bottom))
            .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))
            .shadow(color: .black.opacity(theme.isLight ? 0.15 : 0.50), radius: 1.5, x: 0, y: 2)
            .shadow(color: .black.opacity(theme.isLight ? 0.10 : 0.35), radius: 7, x: 0, y: 6)
            .opacity(settings.opacity)
    }
}

// MARK: - Position Minimap

private struct PositionMinimap: View {
    @Binding var selection: OverlayPosition

    private let screenW: CGFloat = 200
    private let screenH: CGFloat = 125
    private let barW: CGFloat = 70
    private let barH: CGFloat = 14
    private let cornerW: CGFloat = 55
    private let margin: CGFloat = 6

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.75))
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)

            ForEach(OverlayPosition.allCases) { pos in
                positionBar(for: pos)
            }
        }
        .frame(width: screenW, height: screenH)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func positionBar(for pos: OverlayPosition) -> some View {
        let isActive = selection == pos
        let w = isCorner(pos) ? cornerW : barW
        let color = isActive ? Color.accentColor : Color.white.opacity(0.15)

        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(color.opacity(isActive ? 0.9 : 1))
            .frame(width: w, height: barH)
            .overlay {
                if isActive {
                    Text(pos.label)
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            .position(x: xPos(for: pos), y: yPos(for: pos))
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selection = pos
                }
            }
    }

    private func isCorner(_ pos: OverlayPosition) -> Bool {
        switch pos {
        case .topLeft, .topRight, .bottomLeft, .bottomRight: return true
        default: return false
        }
    }

    private func xPos(for pos: OverlayPosition) -> CGFloat {
        switch pos {
        case .topLeft, .bottomLeft:     return margin + cornerW / 2
        case .topRight, .bottomRight:   return screenW - margin - cornerW / 2
        case .top, .bottom, .center:    return screenW / 2
        }
    }

    private func yPos(for pos: OverlayPosition) -> CGFloat {
        switch pos {
        case .top, .topLeft, .topRight:          return margin + barH / 2
        case .bottom, .bottomLeft, .bottomRight: return screenH - margin - barH / 2
        case .center:                             return screenH / 2
        }
    }
}

// MARK: - Animation Preview Card

private struct AnimationPreviewCard: View {
    let style: AnimationStyle
    let isSelected: Bool
    @State private var showing = false
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 36, height: 28)

                if showing {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.accentColor.opacity(0.8))
                        .frame(width: 36, height: 28)
                        .transition(style.transition)
                }
            }
            .frame(height: 32)

            Text(style.label)
                .font(.caption2)
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : (isHovered ? Color.secondary.opacity(0.06) : .clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
        )
        .onHover { hovering in
            isHovered = hovering
            if hovering { playDemo() }
        }
        .onAppear { playDemo() }
    }

    private func playDemo() {
        showing = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(style.entranceAnimation ?? .easeOut(duration: 0.2)) {
                showing = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(style.exitAnimation ?? .easeIn(duration: 0.2)) {
                showing = false
            }
        }
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

// MARK: - Sound Preview

private final class SoundPreview: ObservableObject {
    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!

    func playPreview(style: String, volume: Double) {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try? engine.start()

        let s = SoundStyle(rawValue: style) ?? .mxBlue
        guard let buffer = generateBuffer(for: s) else { return }
        player.volume = Float(volume)
        player.scheduleBuffer(buffer) { [weak self] in
            DispatchQueue.main.async {
                engine.stop()
                self?.engine = nil
                self?.player = nil
            }
        }
        player.play()
        self.engine = engine
        self.player = player
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
            return ClickParams(duration: 0.025, tones: [(2800, 0.6, 180), (5500, 0.3, 500)], noiseAmp: 0.20, noiseDecay: 350)
        case .mxBrown:
            return ClickParams(duration: 0.022, tones: [(2200, 0.5, 220), (4000, 0.15, 600)], noiseAmp: 0.12, noiseDecay: 400)
        case .mxRed:
            return ClickParams(duration: 0.018, tones: [(1800, 0.35, 280), (3200, 0.08, 700)], noiseAmp: 0.06, noiseDecay: 500)
        case .topre:
            return ClickParams(duration: 0.035, tones: [(800, 0.5, 100), (1500, 0.3, 180), (3000, 0.1, 400)], noiseAmp: 0.06, noiseDecay: 200)
        case .bucklingSpring:
            return ClickParams(duration: 0.038, tones: [(3500, 0.5, 130), (7000, 0.25, 350), (1200, 0.3, 90)], noiseAmp: 0.25, noiseDecay: 280)
        case .typewriter:
            return ClickParams(duration: 0.032, tones: [(1000, 0.5, 160), (4500, 0.2, 500), (500, 0.3, 120)], noiseAmp: 0.18, noiseDecay: 250)
        case .bubble:
            return ClickParams(duration: 0.030, tones: [(600, 0.5, 100), (1200, 0.3, 150)], noiseAmp: 0.03, noiseDecay: 500)
        case .minimal:
            return ClickParams(duration: 0.012, tones: [(3000, 0.3, 400)], noiseAmp: 0.04, noiseDecay: 600)
        }
    }

    private func generateBuffer(for style: SoundStyle) -> AVAudioPCMBuffer? {
        let p = params(for: style)
        let sampleRate: Double = 44100
        let frameCount = AVAudioFrameCount(sampleRate * p.duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
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

// MARK: - Onboarding

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var step = 0

    private let steps: [(icon: String, title: String, body: String)] = [
        ("keyboard.fill",
         "Keystroke Viewer",
         "Your keystrokes displayed as a beautiful real-time overlay. Perfect for presentations, tutorials, and screen recordings."),
        ("lock.shield.fill",
         "Accessibility Permission",
         "Keystroke Viewer needs Accessibility access to read keystrokes.\n\nGo to System Settings > Privacy & Security > Accessibility and enable Keystroke Viewer, then restart the app."),
        ("paintbrush.fill",
         "Make It Yours",
         "Choose from 15 themes (including glassmorphism), 5 animations, and 8 sound profiles. Save your favorite combinations as custom presets."),
        ("sparkles",
         "You're All Set!",
         "Look for the keyboard icon in your menu bar. Press ⌃⌥⌘K to toggle the overlay from any app."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: steps[step].icon)
                .font(.system(size: 48))
                .foregroundStyle(.tint)
                .frame(height: 60)
                .id(step)
                .transition(.opacity)

            Text(steps[step].title)
                .font(.title.bold())
                .padding(.top, 16)
                .id("title-\(step)")
                .transition(.opacity)

            Text(steps[step].body)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
                .padding(.top, 8)
                .id("body-\(step)")
                .transition(.opacity)

            Spacer()

            HStack {
                if step > 0 {
                    Button("Back") {
                        withAnimation(.easeInOut(duration: 0.25)) { step -= 1 }
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
                HStack(spacing: 6) {
                    ForEach(0..<steps.count, id: \.self) { i in
                        Circle()
                            .fill(i == step ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 7, height: 7)
                    }
                }
                Spacer()
                if step < steps.count - 1 {
                    Button("Next") {
                        withAnimation(.easeInOut(duration: 0.25)) { step += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") { onComplete() }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(.bottom, 8)
        }
        .padding(32)
        .frame(width: 480, height: 400)
    }
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
