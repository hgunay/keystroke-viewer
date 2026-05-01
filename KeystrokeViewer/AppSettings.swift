import SwiftUI
import Combine

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
    }
}
