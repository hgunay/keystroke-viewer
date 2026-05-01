import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("General") {
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
            Section("Display") {
                Picker("Position", selection: $settings.position) {
                    ForEach(OverlayPosition.allCases) { p in
                        Text(p.label).tag(p)
                    }
                }
                HStack {
                    Text("Font size")
                        .frame(width: 80, alignment: .leading)
                    Slider(value: $settings.fontSize, in: 16...48, step: 1)
                    Text("\(Int(settings.fontSize))")
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
                HStack {
                    Text("Opacity")
                        .frame(width: 80, alignment: .leading)
                    Slider(value: $settings.opacity, in: 0.3...1.0)
                    Text(String(format: "%.0f%%", settings.opacity * 100))
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
                HStack {
                    Text("Display time")
                        .frame(width: 80, alignment: .leading)
                    Slider(value: $settings.displayTime, in: 0.5...5.0, step: 0.1)
                    Text(String(format: "%.1fs", settings.displayTime))
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
            }
            Section("Key Groups") {
                Toggle("Alphanumeric (A-Z, 0-9, symbols)", isOn: $settings.showAlphanumeric)
                Toggle("Modifiers (⌘ ⇧ ⌥ ⌃)", isOn: $settings.showModifiers)
                Toggle("Function keys (F1–F15)", isOn: $settings.showFunctionKeys)
                Toggle("Navigation (arrows, Home, End, PgUp/Dn)", isOn: $settings.showNavigation)
                Toggle("Special keys (Return, Tab, Delete, Space, Esc)", isOn: $settings.showSpecialKeys)
                Toggle("Caps Lock", isOn: $settings.showCapsLock)
            }
            Section {
                Text("Eger tuslar gozukmuyorsa: System Settings -> Privacy & Security -> Accessibility menusunden Keystroke Viewer'a izin ver, sonra uygulamayi yeniden baslat.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 520)
        .padding()
    }
}
