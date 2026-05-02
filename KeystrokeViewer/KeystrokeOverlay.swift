import SwiftUI
import AppKit

private enum KeyGroup {
    case alphanumeric, modifier, functionKey, navigation, special, capsLock
}

final class KeystrokeStore: ObservableObject {
    @Published var visible: [KeyEvent] = []
    private var hideWork: DispatchWorkItem?
    private var pendingModifier: KeyEvent?
    private var modifierWork: DispatchWorkItem?
    let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    private var resolvedStyle: AnimationStyle {
        AnimationStyle(rawValue: settings.animationStyle) ?? .fade
    }

    var activeTransition: AnyTransition {
        resolvedStyle.transition
    }

    private static let fKeyCodes: Set<UInt16> = [
        0x7A, 0x78, 0x63, 0x76, 0x60, 0x61, 0x62, 0x64,
        0x65, 0x6D, 0x67, 0x6F, 0x69, 0x6B, 0x71
    ]
    private static let navScalars: Set<UInt32> = [
        0xF700, 0xF701, 0xF702, 0xF703, 0xF729, 0xF72B, 0xF72C, 0xF72D
    ]
    private static let specialScalars: Set<UInt32> = [
        0x0D, 0x09, 0x7F, 0x1B, 0x20, 0xF746
    ]

    private func keyGroup(for event: KeyEvent) -> KeyGroup {
        let isCapsLock = event.isModifierOnly && event.keyCode == KeyEvent.kVK_CapsLock
        if isCapsLock { return .capsLock }
        if event.isModifierOnly { return .modifier }
        if Self.fKeyCodes.contains(event.keyCode) { return .functionKey }
        if let scalar = event.chars.unicodeScalars.first?.value {
            if Self.navScalars.contains(scalar) { return .navigation }
            if Self.specialScalars.contains(scalar) { return .special }
        }
        return .alphanumeric
    }

    private func isAllowed(_ event: KeyEvent) -> Bool {
        switch keyGroup(for: event) {
        case .alphanumeric: return settings.showAlphanumeric
        case .modifier:     return settings.showModifiers
        case .functionKey:  return settings.showFunctionKeys
        case .navigation:   return settings.showNavigation
        case .special:      return settings.showSpecialKeys
        case .capsLock:     return settings.showCapsLock
        }
    }

    func append(_ event: KeyEvent) {
        guard isAllowed(event) else { return }
        let isCapsLock = event.isModifierOnly && event.keyCode == KeyEvent.kVK_CapsLock

        if event.isModifierOnly && !isCapsLock {
            modifierWork?.cancel()
            pendingModifier = event

            if let lastIdx = visible.indices.last, visible[lastIdx].isModifierOnly {
                withAnimation(resolvedStyle.entranceAnimation) {
                    visible.remove(at: lastIdx)
                }
            }

            let work = DispatchWorkItem { [weak self] in
                guard let self, let pending = self.pendingModifier else { return }
                self.pendingModifier = nil
                self.push(pending)
            }
            modifierWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
            return
        }

        modifierWork?.cancel()
        pendingModifier = nil
        push(event)
    }

    private func push(_ event: KeyEvent) {
        withAnimation(resolvedStyle.entranceAnimation) {
            visible.append(event)
            if visible.count > 3 {
                visible.removeFirst(visible.count - 3)
            }
        }
        scheduleHide()
    }

    private func scheduleHide() {
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            withAnimation(self.resolvedStyle.exitAnimation) {
                self.visible.removeAll()
            }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + settings.displayTime,
            execute: work
        )
    }
}

struct KeystrokeOverlay: View {
    @ObservedObject var store: KeystrokeStore

    var body: some View {
        HStack(spacing: 0) {
            if !store.visible.isEmpty {
                HStack(spacing: 14) {
                    ForEach(store.visible) { event in
                        KeyCap(event: event, settings: store.settings)
                            .transition(store.activeTransition)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 32)
    }
}

struct KeyCap: View {
    let event: KeyEvent
    @ObservedObject var settings: AppSettings

    private var isCapsLockToggle: Bool {
        event.isModifierOnly && event.keyCode == KeyEvent.kVK_CapsLock
    }

    private var capsLockOn: Bool {
        isCapsLockToggle && event.modifiers.contains(.capsLock)
    }

    private var modifierKeys: [(symbol: String, name: String)] {
        var result: [(String, String)] = []
        if isCapsLockToggle {
            result.append(("\u{21EA}", "caps"))
        }
        if event.modifiers.contains(.control)  { result.append(("\u{2303}", "control")) }
        if event.modifiers.contains(.option)   { result.append(("\u{2325}", "option")) }
        if event.modifiers.contains(.shift)    { result.append(("\u{21E7}", "shift")) }
        if event.modifiers.contains(.command)  { result.append(("\u{2318}", "command")) }
        if event.modifiers.contains(.numericPad) && event.isModifierOnly {
            result.append(("⊞", "num lock"))
        }
        return result
    }

    private static let keyCodeMap: [UInt16: String] = [
        0x7A: "F1",  0x78: "F2",  0x63: "F3",  0x76: "F4",
        0x60: "F5",  0x61: "F6",  0x62: "F7",  0x64: "F8",
        0x65: "F9",  0x6D: "F10", 0x67: "F11", 0x6F: "F12",
        0x69: "F13", 0x6B: "F14", 0x71: "F15",
    ]

    private var charKey: (symbol: String, name: String?)? {
        if let fKey = Self.keyCodeMap[event.keyCode] {
            return (fKey, nil)
        }
        let raw = event.chars
        guard let scalar = raw.unicodeScalars.first else { return nil }
        switch scalar.value {
        case 0x0D: return ("\u{21A9}", "return")
        case 0x09: return ("\u{21E5}", "tab")
        case 0x7F: return ("\u{232B}", "delete")
        case 0x1B: return ("esc", "escape")
        case 0x20: return ("\u{2423}", "space")
        case 0xF700: return ("\u{2191}", "up")
        case 0xF701: return ("\u{2193}", "down")
        case 0xF702: return ("\u{2190}", "left")
        case 0xF703: return ("\u{2192}", "right")
        case 0xF746: return ("\u{2326}", "fwd delete")
        case 0xF729: return ("\u{2196}", "home")
        case 0xF72B: return ("\u{2198}", "end")
        case 0xF72C: return ("\u{21DE}", "page up")
        case 0xF72D: return ("\u{21DF}", "page down")
        case 0xF700...0xF8FF:
            return ("fn", nil)
        default:
            let display = event.modifiers.contains(.capsLock) ? raw.uppercased() : raw.lowercased()
            return (display, nil)
        }
    }

    var body: some View {
        HStack(spacing: 8 * settings.keyScale) {
            ForEach(Array(modifierKeys.enumerated()), id: \.offset) { _, mod in
                SingleKey(
                    symbol: mod.symbol,
                    label: mod.name,
                    fontSize: settings.fontSize,
                    showIndicator: mod.name == "caps" ? capsLockOn : false,
                    keyOpacity: settings.opacity,
                    keyScale: settings.keyScale,
                    theme: settings.activeTheme
                )
            }
            if !event.isModifierOnly, let ch = charKey {
                SingleKey(
                    symbol: ch.symbol,
                    label: nil,
                    fontSize: settings.fontSize,
                    keyOpacity: settings.opacity,
                    keyScale: settings.keyScale,
                    theme: settings.activeTheme
                )
            }
        }
    }
}

struct SingleKey: View {
    let symbol: String
    var label: String? = nil
    let fontSize: CGFloat
    var showIndicator: Bool = false
    var keyOpacity: Double = 1.0
    var keyScale: Double = 1.0
    var theme: KeyTheme = KeyTheme.presets[0]

    private var isCapsLock: Bool { label == "caps" }
    private var hasLabel:  Bool { label != nil }

    private var scaledFontSize: CGFloat { fontSize * keyScale }
    private var glyphSize: CGFloat { hasLabel ? scaledFontSize * 0.32 : scaledFontSize * 0.55 }
    private var labelSize: CGFloat { max(scaledFontSize * 0.28, 8) }

    private var keyUnit: CGFloat { 36 * keyScale }

    private var widthRatio: CGFloat {
        if let label {
            switch label {
            case "caps":               return 1.75
            case "shift":              return 1.75
            case "command", "option", "control": return 1.25
            default:                   return 1.0
            }
        }
        switch symbol {
        case "\u{21A9}", "\u{21E5}", "\u{232B}", "\u{2326}": return 1.5
        case "\u{2423}":              return 2.5
        default:                      return 1.0
        }
    }

    var body: some View {
        Group {
            if hasLabel {
                modifierCap
            } else {
                charCap
            }
        }
        .frame(width: keyUnit * widthRatio, height: keyUnit)
        .background(keyBackground)
        .overlay(keyEdges)
        .clipShape(RoundedRectangle(cornerRadius: 6 * keyScale, style: .continuous))
        .shadow(color: .black.opacity(theme.isLight ? 0.15 : 0.50), radius: 1.5, x: 0, y: 2)
        .shadow(color: .black.opacity(theme.isLight ? 0.10 : 0.35), radius: 7,   x: 0, y: 6)
        .opacity(keyOpacity)
    }

    // MARK: – Variants

    private var charCap: some View {
        Text(symbol)
            .font(.system(size: glyphSize, weight: .light, design: .default))
            .foregroundStyle(theme.textColor)
            .minimumScaleFactor(0.4)
            .lineLimit(1)
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
    }

    private var modifierCap: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                if showIndicator {
                    capsLockLED
                } else {
                    Color.clear.frame(width: 8, height: 8)
                }
                Spacer(minLength: 0)
                Text(symbol)
                    .font(.system(size: glyphSize, weight: .light))
                    .foregroundStyle(theme.textColor)
            }
            .frame(minHeight: 12)

            Spacer(minLength: 0)

            Text(label ?? "")
                .font(.system(size: labelSize, weight: .light))
                .foregroundStyle(theme.textColor)
                .lineLimit(1)
        }
        .padding(EdgeInsets(top: 3, leading: 3, bottom: 4, trailing: 3))
    }

    // MARK: – Visual recipe

    private var keyBackground: some View {
        LinearGradient(
            colors: theme.gradientColors,
            startPoint: .top, endPoint: .bottom
        )
    }

    private var scaledCornerRadius: CGFloat { 6 * keyScale }

    private var keyEdges: some View {
        ZStack {
            RoundedRectangle(cornerRadius: scaledCornerRadius, style: .continuous)
                .strokeBorder(
                    theme.isLight ? Color.black.opacity(0.12) : Color.white.opacity(0.09),
                    lineWidth: 0.5
                )

            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white.opacity(theme.isLight ? 0.4 : 0.10))
                    .frame(height: 1)
                Spacer(minLength: 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: scaledCornerRadius, style: .continuous))
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(Color.black.opacity(theme.isLight ? 0.15 : 0.55))
                    .frame(height: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: scaledCornerRadius, style: .continuous))
            .allowsHitTesting(false)
        }
    }

    private var capsLockLED: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 0.72, green: 1.00, blue: 0.81),
                        Color(red: 0.29, green: 0.89, blue: 0.45),
                        Color(red: 0.12, green: 0.65, blue: 0.29),
                        Color(red: 0.05, green: 0.42, blue: 0.18),
                    ],
                    center: UnitPoint(x: 0.35, y: 0.35),
                    startRadius: 0, endRadius: 6
                )
            )
            .frame(width: 8, height: 8)
            .shadow(color: Color(red: 0.29, green: 0.89, blue: 0.45).opacity(0.7), radius: 4)
            .shadow(color: Color(red: 0.29, green: 0.89, blue: 0.45).opacity(0.45), radius: 9)
    }
}
