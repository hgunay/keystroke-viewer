import SwiftUI
import Combine

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
    }
}
