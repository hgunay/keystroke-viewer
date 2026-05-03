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
        let hasMods = !event.modifiers.intersection([.control, .option, .command]).isEmpty
        if hasMods {
            withAnimation(resolvedStyle.entranceAnimation) {
                visible.removeAll { $0.isModifierOnly }
            }
        }
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
                .padding(.horizontal, store.settings.showBackgroundBar ? 20 : 0)
                .padding(.vertical, store.settings.showBackgroundBar ? 12 : 0)
                .background {
                    if store.settings.showBackgroundBar {
                        BackgroundBarView(settings: store.settings)
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
        if event.modifiers.contains(.command)  { result.append(("\u{2318}", "cmd")) }
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

    private static let keyCodeToChar: [UInt16: String] = [
        0x00: "a", 0x01: "s", 0x02: "d", 0x03: "f", 0x04: "h",
        0x05: "g", 0x06: "z", 0x07: "x", 0x08: "c", 0x09: "v",
        0x0B: "b", 0x0C: "q", 0x0D: "w", 0x0E: "e", 0x0F: "r",
        0x10: "y", 0x11: "t", 0x20: "u", 0x22: "i", 0x1F: "o",
        0x23: "p", 0x25: "l", 0x26: "j", 0x28: "k", 0x2D: "n",
        0x2E: "m",
        0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4", 0x17: "5",
        0x16: "6", 0x1A: "7", 0x1C: "8", 0x19: "9", 0x1D: "0",
        0x18: "=", 0x1B: "-", 0x1E: "]", 0x21: "[", 0x27: "'",
        0x29: ";", 0x2A: "\\", 0x2B: ",", 0x2C: "/", 0x2F: ".",
        0x32: "`",
        0x24: "\r", 0x30: "\t", 0x31: " ", 0x33: "\u{7F}", 0x35: "\u{1B}",
        0x7B: "\u{F702}", 0x7C: "\u{F703}", 0x7D: "\u{F701}", 0x7E: "\u{F700}",
        0x73: "\u{F729}", 0x77: "\u{F72B}", 0x74: "\u{F72C}", 0x79: "\u{F72D}",
        0x75: "\u{F746}",
    ]

    private var charKey: (symbol: String, name: String?)? {
        if let fKey = Self.keyCodeMap[event.keyCode] {
            return (fKey, nil)
        }
        var raw = event.chars
        if raw.isEmpty, let fallback = Self.keyCodeToChar[event.keyCode] {
            raw = fallback
        }
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

    private var shouldShowAsCombo: Bool {
        guard settings.compactCombos else { return false }
        guard !event.isModifierOnly else { return false }
        guard charKey != nil else { return false }
        return !event.modifiers.intersection([.control, .option, .command]).isEmpty
    }

    var body: some View {
        if shouldShowAsCombo, let ch = charKey {
            let modSymbols = modifierKeys.map(\.symbol).joined()
            let charDisplay = ch.symbol.count == 1 && ch.symbol.first?.isLetter == true
                ? ch.symbol.uppercased() : ch.symbol
            ComboKeyCap(
                modifierSymbols: modSymbols,
                charSymbol: charDisplay,
                fontSize: settings.fontSize,
                keyOpacity: settings.opacity,
                keyScale: settings.keyScale,
                theme: settings.activeTheme,
                fontStyle: settings.resolvedFontStyle
            )
        } else {
            HStack(spacing: 8 * settings.keyScale) {
                ForEach(Array(modifierKeys.enumerated()), id: \.offset) { _, mod in
                    SingleKey(
                        symbol: mod.symbol,
                        label: mod.name,
                        fontSize: settings.fontSize,
                        showIndicator: mod.name == "caps" ? capsLockOn : false,
                        keyOpacity: settings.opacity,
                        keyScale: settings.keyScale,
                        theme: settings.activeTheme,
                        fontStyle: settings.resolvedFontStyle
                    )
                }
                if !event.isModifierOnly, let ch = charKey {
                    SingleKey(
                        symbol: ch.symbol,
                        label: nil,
                        fontSize: settings.fontSize,
                        keyOpacity: settings.opacity,
                        keyScale: settings.keyScale,
                        theme: settings.activeTheme,
                        fontStyle: settings.resolvedFontStyle
                    )
                }
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
    var fontStyle: FontStyle = .system

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

    @ViewBuilder
    var body: some View {
        if theme.isGlass {
            glassKeyView
        } else {
            classicKeyView
        }
    }

    private var keyContent: some View {
        Group {
            if hasLabel { modifierCap } else { charCap }
        }
        .frame(width: keyUnit * widthRatio, height: keyUnit)
    }

    @ViewBuilder
    private var glassKeyView: some View {
        if #available(macOS 26, *) {
            keyContent
                .glassEffect(in: .rect(cornerRadius: scaledCornerRadius))
                .opacity(keyOpacity)
        } else {
            keyContent
                .background(keyBackground)
                .overlay(keyEdges)
                .clipShape(RoundedRectangle(cornerRadius: scaledCornerRadius, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
                .opacity(keyOpacity)
        }
    }

    private var classicKeyView: some View {
        keyContent
            .background(keyBackground)
            .overlay(keyEdges)
            .clipShape(RoundedRectangle(cornerRadius: scaledCornerRadius, style: .continuous))
            .shadow(color: .black.opacity(theme.isLight ? 0.15 : 0.50), radius: 1.5, x: 0, y: 2)
            .shadow(color: .black.opacity(theme.isLight ? 0.10 : 0.35), radius: 7, x: 0, y: 6)
            .opacity(keyOpacity)
    }

    // MARK: – Variants

    private var charCap: some View {
        Text(symbol)
            .font(fontStyle.font(size: glyphSize))
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
                    .font(fontStyle.font(size: glyphSize))
                    .foregroundStyle(theme.textColor)
            }
            .frame(minHeight: 12)

            Spacer(minLength: 0)

            Text(label ?? "")
                .font(fontStyle.font(size: labelSize))
                .foregroundStyle(theme.textColor)
                .lineLimit(1)
        }
        .padding(EdgeInsets(top: 3, leading: 3, bottom: 4, trailing: 3))
    }

    // MARK: – Visual recipe

    private var scaledCornerRadius: CGFloat { 6 * keyScale }

    @ViewBuilder
    private var keyBackground: some View {
        if theme.isGlass {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(theme.keyColor.opacity(0.15))
            }
        } else {
            LinearGradient(
                colors: theme.gradientColors,
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    @ViewBuilder
    private var keyEdges: some View {
        if theme.isGlass {
            RoundedRectangle(cornerRadius: scaledCornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.5), Color.white.opacity(0.1)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
        } else {
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

// MARK: - Combo Key Cap

private struct ComboKeyCap: View {
    let modifierSymbols: String
    let charSymbol: String
    let fontSize: CGFloat
    var keyOpacity: Double = 1.0
    var keyScale: Double = 1.0
    var theme: KeyTheme = KeyTheme.presets[0]
    var fontStyle: FontStyle = .system

    private var scaledFontSize: CGFloat { fontSize * keyScale }
    private var keyUnit: CGFloat { 36 * keyScale }
    private var scaledCornerRadius: CGFloat { 6 * keyScale }

    @ViewBuilder
    var body: some View {
        if theme.isGlass {
            glassComboView
        } else {
            classicComboView
        }
    }

    private var comboContent: some View {
        HStack(spacing: 2 * keyScale) {
            Text(modifierSymbols)
                .font(fontStyle.font(size: scaledFontSize * 0.42))
                .foregroundStyle(theme.textColor.opacity(0.7))
            Text(charSymbol)
                .font(fontStyle.font(size: scaledFontSize * 0.5, weight: .medium))
                .foregroundStyle(theme.textColor)
        }
        .padding(.horizontal, 10 * keyScale)
        .frame(height: keyUnit)
    }

    @ViewBuilder
    private var glassComboView: some View {
        if #available(macOS 26, *) {
            comboContent
                .glassEffect(in: .rect(cornerRadius: scaledCornerRadius))
                .opacity(keyOpacity)
        } else {
            comboContent
                .background(comboBackground)
                .overlay(keyEdges)
                .clipShape(RoundedRectangle(cornerRadius: scaledCornerRadius, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
                .opacity(keyOpacity)
        }
    }

    private var classicComboView: some View {
        comboContent
            .background(comboBackground)
            .overlay(keyEdges)
            .clipShape(RoundedRectangle(cornerRadius: scaledCornerRadius, style: .continuous))
            .shadow(color: .black.opacity(theme.isLight ? 0.15 : 0.50), radius: 1.5, x: 0, y: 2)
            .shadow(color: .black.opacity(theme.isLight ? 0.10 : 0.35), radius: 7, x: 0, y: 6)
            .opacity(keyOpacity)
    }

    @ViewBuilder
    private var comboBackground: some View {
        if theme.isGlass {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(theme.keyColor.opacity(0.15))
            }
        } else {
            LinearGradient(colors: theme.gradientColors, startPoint: .top, endPoint: .bottom)
        }
    }

    @ViewBuilder
    private var keyEdges: some View {
        if theme.isGlass {
            RoundedRectangle(cornerRadius: scaledCornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.5), Color.white.opacity(0.1)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
        } else {
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
    }
}

// MARK: - Background Bar

private struct BackgroundBarView: View {
    @ObservedObject var settings: AppSettings

    private var barColor: Color { Color(hex: settings.backgroundBarColorHex) }
    private let cr: CGFloat = 14

    var body: some View {
        Group {
            switch settings.resolvedBarStyle {
            case .material:
                materialBar
            case .solid:
                solidBar
            case .themeMatch:
                themeBar
            }
        }
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
    }

    @ViewBuilder
    private var materialBar: some View {
        ZStack {
            materialShape
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .fill(barColor.opacity(settings.backgroundBarOpacity * 0.5))
        }
    }

    @ViewBuilder
    private var materialShape: some View {
        switch settings.resolvedBarMaterial {
        case .ultraThin:
            RoundedRectangle(cornerRadius: cr, style: .continuous).fill(.ultraThinMaterial)
        case .thin:
            RoundedRectangle(cornerRadius: cr, style: .continuous).fill(.thinMaterial)
        case .regular:
            RoundedRectangle(cornerRadius: cr, style: .continuous).fill(.regularMaterial)
        case .thick:
            RoundedRectangle(cornerRadius: cr, style: .continuous).fill(.thickMaterial)
        case .ultraThick:
            RoundedRectangle(cornerRadius: cr, style: .continuous).fill(.ultraThickMaterial)
        }
    }

    private var solidBar: some View {
        RoundedRectangle(cornerRadius: cr, style: .continuous)
            .fill(barColor.opacity(settings.backgroundBarOpacity))
    }

    private var themeBar: some View {
        RoundedRectangle(cornerRadius: cr, style: .continuous)
            .fill(settings.activeTheme.keyColor.opacity(settings.backgroundBarOpacity))
    }
}

// MARK: - Click Visualization

enum ClickButton {
    case left, right, other
}

struct ClickEvent: Identifiable {
    let id = UUID()
    let location: CGPoint
    let button: ClickButton
    let timestamp: Date
}

final class ClickStore: ObservableObject {
    @Published var clicks: [ClickEvent] = []

    func append(_ click: ClickEvent) {
        clicks.append(click)
        let clickId = click.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.clicks.removeAll { $0.id == clickId }
        }
    }
}

struct ClickOverlayView: View {
    @ObservedObject var store: ClickStore
    let screenFrame: NSRect

    private var visibleClicks: [ClickEvent] {
        store.clicks.filter { screenFrame.contains($0.location) }
    }

    var body: some View {
        ZStack {
            ForEach(visibleClicks) { click in
                ClickRipple(button: click.button)
                    .position(
                        x: click.location.x - screenFrame.origin.x,
                        y: screenFrame.height - (click.location.y - screenFrame.origin.y)
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ClickRipple: View {
    let button: ClickButton
    @State private var animate = false

    private var color: Color {
        switch button {
        case .left:  return .white
        case .right: return Color(red: 0.5, green: 0.7, blue: 1.0)
        case .other: return Color(red: 1.0, green: 0.8, blue: 0.4)
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(animate ? 0 : 0.4), lineWidth: animate ? 0.5 : 2)
                .frame(width: animate ? 50 : 8, height: animate ? 50 : 8)

            Circle()
                .stroke(color.opacity(animate ? 0 : 0.6), lineWidth: animate ? 1 : 2)
                .frame(width: animate ? 30 : 6, height: animate ? 30 : 6)

            Circle()
                .fill(color.opacity(animate ? 0 : 0.8))
                .frame(width: animate ? 2 : 8, height: animate ? 2 : 8)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                animate = true
            }
        }
    }
}
