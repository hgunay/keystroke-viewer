# KeystrokeViewer

A macOS menu bar app that displays your keystrokes as a real-time overlay on screen, designed with MacBook Pro keyboard-style key caps.

![macOS](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Real-time keystroke overlay** with MacBook Pro keyboard proportions
- **Compact combo display** — ⌘C, ⌃⌥⌘K shown as a single key cap instead of separate keys (toggleable)
- **Caps Lock indicator** with green LED, shows on/off state
- **Key repeat filtering** — holding a key only shows it once
- **Function key support** — F1 through F15
- **Case-aware display** — uppercase when Caps Lock is on, lowercase when off
- **6 built-in themes** — Dark, Light, Midnight, Ocean, Rosé, Forest — plus custom color picker
- **5 animation styles** — None, Fade, Slide Up, Scale, Bounce
- **Global toggle shortcut** — show/hide overlay from any app (default: ⌃⌥⌘K)
- **Mouse click visualization** — ripple animation on left, right, and middle clicks with distinct colors
- **8 keyboard sound profiles** — Cherry MX Blue/Brown/Red, Topre, Buckling Spring, Typewriter, Bubble Pop, Minimal Tap with output device selection
- **6 quick presets** — Presentation, Coding, Streaming, Minimal, Typewriter, Mechanical — one-click profiles
- **Custom presets** — Save, load, and delete your own named setting configurations
- **Password field detection** — automatically hides keystrokes when typing in secure fields
- **Configurable key groups** — toggle visibility for alphanumeric, modifiers, function keys, navigation, special keys, and Caps Lock independently
- **Multi-monitor support** — main screen only, all screens, or follow active screen automatically
- **7 overlay positions** — top, bottom, center, and all four corners
- **4 font styles** — System, Mono, Rounded, Serif
- **Adjustable appearance** — font size, key scale, opacity, and display duration
- **Launch at login** — optional auto-start via macOS Login Items
- **Menu bar app** — runs as a lightweight tray icon, no Dock clutter

## Requirements

- macOS 13 (Ventura) or later

## Installation

1. Download `KeystrokeViewer.zip` from the [latest release](https://github.com/hgunay/keystroke-viewer/releases/latest)
2. Unzip and drag `KeystrokeViewer.app` to your Applications folder
3. On first launch, macOS will show a security warning because the app is not notarized. To open it:
   - Right-click the app → **Open** → click **Open** again in the dialog
   - Or go to **System Settings → Privacy & Security**, scroll down and click **Open Anyway**
4. Grant Accessibility permission when prompted:
   - **System Settings → Privacy & Security → Accessibility**
   - Find **KeystrokeViewer** and enable it
   - Restart the app
5. A keyboard icon appears in the menu bar. Start typing in any app to see the overlay.

## Build from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/hgunay/keystroke-viewer.git
   ```

2. Open `KeystrokeViewer.xcodeproj` in Xcode (15+)

3. Build and run (Cmd+R)

4. Grant Accessibility permission as described above

## Usage

### Menu Bar

Click the keyboard icon in the menu bar:
- **Show Overlay** — toggle keystroke display on/off
- **Preferences** — open the settings window
- **Quit** — exit the app

### Global Shortcut

Press **⌃⌥⌘K** (Control+Option+Command+K) to toggle the overlay from any app. You can customize or clear this shortcut in Preferences > General.

### Settings

Settings are organized in four tabs:

#### General

| Setting | Description |
|---|---|
| **Show overlay** | Toggle keystroke display on/off |
| **Toggle shortcut** | Record a custom global hotkey to show/hide the overlay |
| **Launch at login** | Auto-start when you log in |
| **Mouse clicks** | Show expanding ripple animation at click location (left=white, right=blue, middle=orange) |
| **Keystroke sound** | Toggle sound on/off, pick from 8 profiles, select output device, adjust volume (10–100%) |
| **Hide in password fields** | Automatically suppress keystrokes when a secure input field is active |

#### Appearance

| Setting | Description |
|---|---|
| **Theme** | Choose from 6 preset themes or create a custom color scheme |
| **Custom colors** | Pick key background and text colors (when Custom theme is selected) |
| **Compact combos** | Show modifier shortcuts (⌘C, ⌃⌥⌘K) as a single key cap instead of separate keys |
| **Animation** | Keystroke appear/disappear style: None, Fade, Slide Up, Scale, Bounce |
| **Position** | Overlay location: Bottom, Top, Center, or any corner |
| **Screen** | Main Screen, All Screens, or Follow Active Screen (overlay moves to whichever screen you're typing on) |
| **Font** | System (SF Pro), Mono (SF Mono), Rounded (SF Rounded), Serif (New York) |
| **Font size** | Key cap text size (16–48pt) |
| **Key size** | Key cap scale (50–200%) |
| **Opacity** | Key cap transparency (30–100%) |

#### Keys

| Setting | Description |
|---|---|
| **Duration** | How long keystrokes stay visible (0.5–5.0s) |
| **Key Groups** | Toggle each group on/off independently |

#### Presets

6 built-in presets for common use cases, plus custom presets to save and restore your own configurations.

| Preset | Description |
|---|---|
| **Presentation** | Large keys, dark theme, bounce animation for live demos |
| **Coding** | Mono font, midnight theme, compact corner overlay |
| **Streaming** | Ocean theme, scale animation, top position for streams |
| **Minimal** | Small, subtle keys that stay out of your way |
| **Typewriter** | Retro serif font with typewriter click sounds |
| **Mechanical** | Full mechanical keyboard experience with MX Blue clicks |

**Custom Presets:** Click "Save Current Settings" to capture your current configuration as a named preset. Custom presets store theme, animation, font, size, scale, opacity, position, display time, and sound settings. Right-click a custom preset to delete it.

### Key Groups

- **Alphanumeric** — A–Z, 0–9, symbols
- **Modifiers** — Command, Shift, Option, Control
- **Function keys** — F1–F15
- **Navigation** — Arrow keys, Home, End, Page Up/Down
- **Special keys** — Return, Tab, Delete, Space, Escape
- **Caps Lock** — Caps Lock toggle events

## Architecture

| File | Purpose |
|---|---|
| `KeystrokeApp.swift` | SwiftUI App entry point |
| `AppDelegate.swift` | App lifecycle, Accessibility permission, menu bar, global hotkey |
| `AppSettings.swift` | User preferences, theme system, animation styles |
| `KeyMonitor.swift` | CGEventTap + NSEvent global monitor for key capture, secure input detection |
| `OverlayController.swift` | NSPanel floating window management, visibility control |
| `KeystrokeOverlay.swift` | SwiftUI key cap views, keystroke store, animated transitions |
| `SettingsView.swift` | Tabbed preferences window (General, Appearance, Keys) |

## Known Limitations

- **Sandbox is disabled** — required for CGEventTap. Mac App Store distribution would need a special entitlement from Apple.
- **Not notarized** — the app is ad-hoc signed but not notarized with Apple. On first launch, right-click → Open or allow it in System Settings > Privacy & Security.
- **Function keys** — on MacBook keyboards, F1–F12 may require holding the `fn` key (depending on your system settings).

## License

MIT
