import SwiftUI
import Combine
import AppKit
import CoreAudio

// MARK: - Color Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self.init(
            red: Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8) & 0xFF) / 255,
            blue: Double(int & 0xFF) / 255
        )
    }
}

// MARK: - Overlay Position

enum OverlayPosition: String, CaseIterable, Identifiable {
    case bottom, top, center
    case topLeft, topRight, bottomLeft, bottomRight
    var id: String { rawValue }
    var label: String {
        switch self {
        case .bottom:      return "Bottom"
        case .top:         return "Top"
        case .center:      return "Center"
        case .topLeft:     return "Top Left"
        case .topRight:    return "Top Right"
        case .bottomLeft:  return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        }
    }
}

// MARK: - Animation Style

enum AnimationStyle: String, CaseIterable, Identifiable {
    case none, fade, slideUp, scale, bounce
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none:    return "None"
        case .fade:    return "Fade"
        case .slideUp: return "Slide Up"
        case .scale:   return "Scale"
        case .bounce:  return "Bounce"
        }
    }

    var transition: AnyTransition {
        switch self {
        case .none:
            return .identity
        case .fade:
            return .opacity
        case .slideUp:
            return .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .opacity)
        case .scale:
            return .asymmetric(
                insertion: .scale(scale: 0.5).combined(with: .opacity),
                removal: .opacity)
        case .bounce:
            return .asymmetric(
                insertion: .scale(scale: 0.3).combined(with: .opacity),
                removal: .opacity)
        }
    }

    var entranceAnimation: Animation? {
        switch self {
        case .none:    return nil
        case .fade:    return .easeOut(duration: 0.15)
        case .slideUp: return .easeOut(duration: 0.2)
        case .scale:   return .spring(response: 0.25, dampingFraction: 0.7)
        case .bounce:  return .spring(response: 0.35, dampingFraction: 0.4)
        }
    }

    var exitAnimation: Animation? {
        switch self {
        case .none: return nil
        default:    return .easeIn(duration: 0.2)
        }
    }
}

// MARK: - Theme

struct KeyTheme: Identifiable {
    let id: String
    let name: String
    let keyR: Double
    let keyG: Double
    let keyB: Double
    let textR: Double
    let textG: Double
    let textB: Double
    let isLight: Bool

    var keyColor: Color { Color(red: keyR, green: keyG, blue: keyB) }
    var textColor: Color { Color(red: textR, green: textG, blue: textB) }

    var gradientColors: [Color] {
        let lr = min(keyR + (1 - keyR) * 0.3, 1)
        let lg = min(keyG + (1 - keyG) * 0.3, 1)
        let lb = min(keyB + (1 - keyB) * 0.3, 1)
        let dr = keyR * 0.8
        let dg = keyG * 0.8
        let db = keyB * 0.8
        return [
            Color(red: lr, green: lg, blue: lb),
            keyColor,
            Color(red: dr, green: dg, blue: db)
        ]
    }

    static func rgb(from hex: String) -> (r: Double, g: Double, b: Double) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        return (
            r: Double((int >> 16) & 0xFF) / 255,
            g: Double((int >> 8) & 0xFF) / 255,
            b: Double(int & 0xFF) / 255
        )
    }

    init(id: String, name: String, keyHex: String, textHex: String, isLight: Bool = false) {
        self.id = id
        self.name = name
        let k = Self.rgb(from: keyHex)
        self.keyR = k.r; self.keyG = k.g; self.keyB = k.b
        let t = Self.rgb(from: textHex)
        self.textR = t.r; self.textG = t.g; self.textB = t.b
        self.isLight = isLight
    }

    init(id: String, name: String, keyR: Double, keyG: Double, keyB: Double,
         textR: Double, textG: Double, textB: Double, isLight: Bool) {
        self.id = id; self.name = name
        self.keyR = keyR; self.keyG = keyG; self.keyB = keyB
        self.textR = textR; self.textG = textG; self.textB = textB
        self.isLight = isLight
    }

    static let presets: [KeyTheme] = [
        KeyTheme(id: "dark", name: "Dark", keyHex: "#1D1D1F", textHex: "#E8E8ED"),
        KeyTheme(id: "light", name: "Light", keyHex: "#E0E0E6", textHex: "#26262E", isLight: true),
        KeyTheme(id: "midnight", name: "Midnight", keyHex: "#1A1A3D", textHex: "#A6BFFF"),
        KeyTheme(id: "ocean", name: "Ocean", keyHex: "#0F2933", textHex: "#99EBE0"),
        KeyTheme(id: "rose", name: "Rosé", keyHex: "#381A24", textHex: "#FFC7D6"),
        KeyTheme(id: "forest", name: "Forest", keyHex: "#142E1A", textHex: "#B3F0B8"),
    ]

    static func preset(for id: String) -> KeyTheme? {
        presets.first { $0.id == id }
    }
}

// MARK: - Font Style

enum FontStyle: String, CaseIterable, Identifiable {
    case system, mono, rounded, serif
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system:  return "System"
        case .mono:    return "Mono"
        case .rounded: return "Rounded"
        case .serif:   return "Serif"
        }
    }

    func font(size: CGFloat, weight: Font.Weight = .light) -> Font {
        switch self {
        case .system:  return .system(size: size, weight: weight, design: .default)
        case .mono:    return .system(size: size, weight: weight, design: .monospaced)
        case .rounded: return .system(size: size, weight: weight, design: .rounded)
        case .serif:   return .system(size: size, weight: weight, design: .serif)
        }
    }
}

// MARK: - Sound Style

enum SoundStyle: String, CaseIterable, Identifiable {
    case mxBlue, mxBrown, mxRed, topre, bucklingSpring, typewriter, bubble, minimal
    var id: String { rawValue }
    var label: String {
        switch self {
        case .mxBlue:         return "Cherry MX Blue"
        case .mxBrown:        return "Cherry MX Brown"
        case .mxRed:          return "Cherry MX Red"
        case .topre:          return "Topre"
        case .bucklingSpring: return "Buckling Spring"
        case .typewriter:     return "Typewriter"
        case .bubble:         return "Bubble Pop"
        case .minimal:        return "Minimal Tap"
        }
    }
}

// MARK: - Quick Preset

struct QuickPreset: Identifiable {
    let id: String
    let name: String
    let icon: String
    let description: String
    let themeId: String
    let animationStyle: String
    let fontStyle: String
    let fontSize: Double
    let keyScale: Double
    let opacity: Double
    let position: OverlayPosition
    let displayTime: Double
    let soundEnabled: Bool
    let soundStyle: String
    let soundVolume: Double

    func apply(to s: AppSettings) {
        s.selectedThemeId = themeId
        s.animationStyle = animationStyle
        s.fontStyle = fontStyle
        s.fontSize = fontSize
        s.keyScale = keyScale
        s.opacity = opacity
        s.position = position
        s.displayTime = displayTime
        s.soundEnabled = soundEnabled
        s.soundStyle = soundStyle
        s.soundVolume = soundVolume
    }

    static let all: [QuickPreset] = [
        QuickPreset(
            id: "presentation", name: "Presentation", icon: "person.2.fill",
            description: "Large keys, dark theme, bounce animation for live demos",
            themeId: "dark", animationStyle: "bounce", fontStyle: "system",
            fontSize: 42, keyScale: 1.5, opacity: 0.95, position: .bottom,
            displayTime: 2.0, soundEnabled: false, soundStyle: "mxBlue", soundVolume: 0.5
        ),
        QuickPreset(
            id: "coding", name: "Coding", icon: "chevron.left.forwardslash.chevron.right",
            description: "Mono font, midnight theme, compact corner overlay",
            themeId: "midnight", animationStyle: "fade", fontStyle: "mono",
            fontSize: 28, keyScale: 1.0, opacity: 0.8, position: .bottomRight,
            displayTime: 1.5, soundEnabled: false, soundStyle: "mxBlue", soundVolume: 0.5
        ),
        QuickPreset(
            id: "streaming", name: "Streaming", icon: "video.fill",
            description: "Ocean theme, scale animation, top position for streams",
            themeId: "ocean", animationStyle: "scale", fontStyle: "rounded",
            fontSize: 36, keyScale: 1.2, opacity: 0.9, position: .top,
            displayTime: 1.5, soundEnabled: false, soundStyle: "mxBlue", soundVolume: 0.5
        ),
        QuickPreset(
            id: "minimal", name: "Minimal", icon: "minus.circle",
            description: "Small, subtle keys that stay out of your way",
            themeId: "light", animationStyle: "fade", fontStyle: "system",
            fontSize: 20, keyScale: 0.7, opacity: 0.6, position: .bottomRight,
            displayTime: 1.0, soundEnabled: false, soundStyle: "minimal", soundVolume: 0.3
        ),
        QuickPreset(
            id: "typewriter", name: "Typewriter", icon: "textformat",
            description: "Retro serif font with typewriter click sounds",
            themeId: "dark", animationStyle: "slideUp", fontStyle: "serif",
            fontSize: 32, keyScale: 1.0, opacity: 0.85, position: .bottom,
            displayTime: 1.5, soundEnabled: true, soundStyle: "typewriter", soundVolume: 0.5
        ),
        QuickPreset(
            id: "mechanical", name: "Mechanical", icon: "keyboard.fill",
            description: "Full mechanical keyboard experience with MX Blue clicks",
            themeId: "forest", animationStyle: "bounce", fontStyle: "system",
            fontSize: 36, keyScale: 1.2, opacity: 0.9, position: .bottom,
            displayTime: 1.5, soundEnabled: true, soundStyle: "mxBlue", soundVolume: 0.7
        ),
    ]
}

// MARK: - Saved Preset

struct SavedPreset: Codable, Identifiable {
    let id: String
    var name: String
    let themeId: String
    let animationStyle: String
    let fontStyle: String
    let fontSize: Double
    let keyScale: Double
    let opacity: Double
    let position: String
    let displayTime: Double
    let soundEnabled: Bool
    let soundStyle: String
    let soundVolume: Double

    var summary: String {
        let theme = KeyTheme.preset(for: themeId)?.name ?? themeId
        let pos = OverlayPosition(rawValue: position)?.label ?? position
        return "\(theme) · \(pos)"
    }

    func apply(to s: AppSettings) {
        s.selectedThemeId = themeId
        s.animationStyle = animationStyle
        s.fontStyle = fontStyle
        s.fontSize = fontSize
        s.keyScale = keyScale
        s.opacity = opacity
        s.position = OverlayPosition(rawValue: position) ?? .bottom
        s.displayTime = displayTime
        s.soundEnabled = soundEnabled
        s.soundStyle = soundStyle
        s.soundVolume = soundVolume
    }
}

// MARK: - Audio Output Device

struct AudioOutputDevice: Identifiable, Hashable {
    let id: String
    let name: String

    static func availableDevices() -> [AudioOutputDevice] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &dataSize
        ) == noErr else { return [] }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &dataSize, &ids
        ) == noErr else { return [] }

        var devices: [AudioOutputDevice] = []
        for deviceID in ids {
            var streamAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(
                deviceID, &streamAddress, 0, nil, &streamSize
            ) == noErr, streamSize > 0 else { continue }

            let raw = UnsafeMutableRawPointer.allocate(
                byteCount: Int(streamSize),
                alignment: MemoryLayout<AudioBufferList>.alignment
            )
            defer { raw.deallocate() }
            guard AudioObjectGetPropertyData(
                deviceID, &streamAddress, 0, nil, &streamSize, raw
            ) == noErr else { continue }

            let buffers = UnsafeMutableAudioBufferListPointer(
                raw.assumingMemoryBound(to: AudioBufferList.self)
            )
            let channels = buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
            guard channels > 0 else { continue }

            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioObjectPropertyName,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var name: CFString = "" as CFString
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &name)

            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var uid: CFString = "" as CFString
            var uidSize = UInt32(MemoryLayout<CFString>.size)
            AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, &uid)

            devices.append(AudioOutputDevice(id: uid as String, name: name as String))
        }
        return devices
    }
}

// MARK: - App Settings

final class AppSettings: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var position: OverlayPosition {
        didSet { defaults.set(position.rawValue, forKey: "position") }
    }
    @Published var fontSize: Double {
        didSet { defaults.set(fontSize, forKey: "fontSize") }
    }
    @Published var opacity: Double {
        didSet { defaults.set(opacity, forKey: "opacity") }
    }
    @Published var displayTime: Double {
        didSet { defaults.set(displayTime, forKey: "displayTime") }
    }
    @Published var showAlphanumeric: Bool {
        didSet { defaults.set(showAlphanumeric, forKey: "showAlphanumeric") }
    }
    @Published var showModifiers: Bool {
        didSet { defaults.set(showModifiers, forKey: "showModifiers") }
    }
    @Published var showFunctionKeys: Bool {
        didSet { defaults.set(showFunctionKeys, forKey: "showFunctionKeys") }
    }
    @Published var showNavigation: Bool {
        didSet { defaults.set(showNavigation, forKey: "showNavigation") }
    }
    @Published var showSpecialKeys: Bool {
        didSet { defaults.set(showSpecialKeys, forKey: "showSpecialKeys") }
    }
    @Published var showCapsLock: Bool {
        didSet { defaults.set(showCapsLock, forKey: "showCapsLock") }
    }
    @Published var keyScale: Double {
        didSet { defaults.set(keyScale, forKey: "keyScale") }
    }
    @Published var selectedThemeId: String {
        didSet { defaults.set(selectedThemeId, forKey: "selectedThemeId") }
    }
    @Published var customKeyColorHex: String {
        didSet { defaults.set(customKeyColorHex, forKey: "customKeyColorHex") }
    }
    @Published var customTextColorHex: String {
        didSet { defaults.set(customTextColorHex, forKey: "customTextColorHex") }
    }
    @Published var overlayEnabled: Bool {
        didSet { defaults.set(overlayEnabled, forKey: "overlayEnabled") }
    }
    @Published var toggleKeyCode: Int {
        didSet { defaults.set(toggleKeyCode, forKey: "toggleKeyCode") }
    }
    @Published var toggleModifiers: Int {
        didSet { defaults.set(toggleModifiers, forKey: "toggleModifiers") }
    }
    @Published var toggleKeyDisplay: String {
        didSet { defaults.set(toggleKeyDisplay, forKey: "toggleKeyDisplay") }
    }
    @Published var animationStyle: String {
        didSet { defaults.set(animationStyle, forKey: "animationStyle") }
    }
    @Published var hideInSecureFields: Bool {
        didSet { defaults.set(hideInSecureFields, forKey: "hideInSecureFields") }
    }
    @Published var displayOnAllScreens: Bool {
        didSet { defaults.set(displayOnAllScreens, forKey: "displayOnAllScreens") }
    }
    @Published var showMouseClicks: Bool {
        didSet { defaults.set(showMouseClicks, forKey: "showMouseClicks") }
    }
    @Published var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: "soundEnabled") }
    }
    @Published var soundVolume: Double {
        didSet { defaults.set(soundVolume, forKey: "soundVolume") }
    }
    @Published var soundStyle: String {
        didSet { defaults.set(soundStyle, forKey: "soundStyle") }
    }
    @Published var soundOutputDeviceUID: String {
        didSet { defaults.set(soundOutputDeviceUID, forKey: "soundOutputDeviceUID") }
    }
    @Published var fontStyle: String {
        didSet { defaults.set(fontStyle, forKey: "fontStyle") }
    }

    var resolvedFontStyle: FontStyle {
        FontStyle(rawValue: fontStyle) ?? .system
    }

    var toggleShortcutLabel: String {
        guard toggleKeyCode >= 0 else { return "Not Set" }
        var label = ""
        let flags = NSEvent.ModifierFlags(rawValue: UInt(toggleModifiers))
        if flags.contains(.control) { label += "⌃" }
        if flags.contains(.option)  { label += "⌥" }
        if flags.contains(.shift)   { label += "⇧" }
        if flags.contains(.command) { label += "⌘" }
        label += toggleKeyDisplay.uppercased()
        return label
    }

    func saveCurrentAsPreset(name: String) {
        var presets = loadCustomPresets()
        presets.append(SavedPreset(
            id: UUID().uuidString, name: name,
            themeId: selectedThemeId, animationStyle: animationStyle,
            fontStyle: fontStyle, fontSize: fontSize, keyScale: keyScale,
            opacity: opacity, position: position.rawValue,
            displayTime: displayTime, soundEnabled: soundEnabled,
            soundStyle: soundStyle, soundVolume: soundVolume
        ))
        saveCustomPresets(presets)
    }

    func loadCustomPresets() -> [SavedPreset] {
        guard let data = defaults.data(forKey: "customPresets"),
              let presets = try? JSONDecoder().decode([SavedPreset].self, from: data)
        else { return [] }
        return presets
    }

    func deleteCustomPreset(id: String) {
        var presets = loadCustomPresets()
        presets.removeAll { $0.id == id }
        saveCustomPresets(presets)
    }

    private func saveCustomPresets(_ presets: [SavedPreset]) {
        if let data = try? JSONEncoder().encode(presets) {
            defaults.set(data, forKey: "customPresets")
        }
    }

    var activeTheme: KeyTheme {
        if selectedThemeId == "custom" {
            let k = KeyTheme.rgb(from: customKeyColorHex)
            let t = KeyTheme.rgb(from: customTextColorHex)
            let brightness = k.r * 0.299 + k.g * 0.587 + k.b * 0.114
            return KeyTheme(
                id: "custom", name: "Custom",
                keyR: k.r, keyG: k.g, keyB: k.b,
                textR: t.r, textG: t.g, textB: t.b,
                isLight: brightness > 0.5
            )
        }
        return KeyTheme.preset(for: selectedThemeId) ?? KeyTheme.presets[0]
    }

    init() {
        let raw = defaults.string(forKey: "position") ?? OverlayPosition.bottom.rawValue
        self.position = OverlayPosition(rawValue: raw) ?? .bottom

        let f = defaults.double(forKey: "fontSize")
        self.fontSize = f > 0 ? f : 36

        let o = defaults.double(forKey: "opacity")
        self.opacity = o > 0 ? o : 0.85

        let d = defaults.double(forKey: "displayTime")
        self.displayTime = d > 0 ? d : 1.5

        self.showAlphanumeric  = defaults.object(forKey: "showAlphanumeric")  as? Bool ?? true
        self.showModifiers     = defaults.object(forKey: "showModifiers")     as? Bool ?? true
        self.showFunctionKeys  = defaults.object(forKey: "showFunctionKeys")  as? Bool ?? true
        self.showNavigation    = defaults.object(forKey: "showNavigation")    as? Bool ?? true
        self.showSpecialKeys   = defaults.object(forKey: "showSpecialKeys")   as? Bool ?? true
        self.showCapsLock      = defaults.object(forKey: "showCapsLock")      as? Bool ?? true

        let ks = defaults.double(forKey: "keyScale")
        self.keyScale = ks > 0 ? ks : 1.0

        self.selectedThemeId = defaults.string(forKey: "selectedThemeId") ?? "dark"
        self.customKeyColorHex = defaults.string(forKey: "customKeyColorHex") ?? "#1D1D1F"
        self.customTextColorHex = defaults.string(forKey: "customTextColorHex") ?? "#E8E8ED"

        self.overlayEnabled = defaults.object(forKey: "overlayEnabled") as? Bool ?? true

        if let kc = defaults.object(forKey: "toggleKeyCode") as? Int {
            self.toggleKeyCode = kc
        } else {
            self.toggleKeyCode = 40 // K
        }
        if let mods = defaults.object(forKey: "toggleModifiers") as? Int {
            self.toggleModifiers = mods
        } else {
            self.toggleModifiers = Int(NSEvent.ModifierFlags([.control, .option, .command]).rawValue)
        }
        self.toggleKeyDisplay = defaults.string(forKey: "toggleKeyDisplay") ?? "K"
        self.animationStyle = defaults.string(forKey: "animationStyle") ?? "fade"
        self.hideInSecureFields = defaults.object(forKey: "hideInSecureFields") as? Bool ?? true
        self.displayOnAllScreens = defaults.object(forKey: "displayOnAllScreens") as? Bool ?? false
        self.showMouseClicks = defaults.object(forKey: "showMouseClicks") as? Bool ?? false
        self.soundEnabled = defaults.object(forKey: "soundEnabled") as? Bool ?? false
        let sv = defaults.double(forKey: "soundVolume")
        self.soundVolume = sv > 0 ? sv : 0.5
        self.soundStyle = defaults.string(forKey: "soundStyle") ?? "mxBlue"
        self.soundOutputDeviceUID = defaults.string(forKey: "soundOutputDeviceUID") ?? ""
        self.fontStyle = defaults.string(forKey: "fontStyle") ?? "system"
    }
}
