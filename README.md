# KeystrokeViewer

Keystroke Pro tarzi macOS klavye tuslarini ekranda gosteren uygulama.

## Calistirma

1. `KeystrokeViewer.xcodeproj` dosyasini Xcode ile ac
2. Top-left'te **Run** (Cmd+R)
3. Ilk calistirmada Accessibility izni isteyecek:
   - System Settings -> Privacy & Security -> Accessibility
   - KeystrokeViewer'i bul ve aktiflestir
   - Uygulamayi yeniden calistir
4. Menubar'da klavye iconu gorunur. Menuden **Preferences** acabilirsin.
5. Test icin baska bir uygulamada (Notes, Safari) yazmaya basla; tuslar ekranin altinda belirir.

## Gereksinimler

- macOS 13 (Ventura) veya ustu
- Xcode 15+
- Apple Developer hesabi gerekmez (lokal calistirmak icin)

## Yapi

- `KeystrokeApp.swift` - Entry point, SwiftUI App
- `AppDelegate.swift` - Lifecycle, Accessibility izni, menubar
- `AppSettings.swift` - @AppStorage tabanli kullanici ayarlari
- `KeyMonitor.swift` - CGEventTap ile global tus dinleme
- `OverlayController.swift` - NSPanel floating window yonetimi
- `KeystrokeOverlay.swift` - SwiftUI tus capleri
- `SettingsView.swift` - Preferences penceresi

## Bilinen kisitlar

- Sandbox kapali (CGEventTap icin gerekli) -> Mac App Store dagitimi icin Apple ozel entitlement'i lazim
- Kod imzalama yok; ilk acilista "Cannot be opened" gelirse System Settings -> Privacy & Security'den "Open Anyway" tikla
- Mouse tiklama gosterimi henuz yok (TODO)
