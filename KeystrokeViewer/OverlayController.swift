import AppKit
import SwiftUI
import Combine

final class OverlayController {
    private let panel: NSPanel
    private let store: KeystrokeStore
    private let settings: AppSettings
    private var cancellable: AnyCancellable?

    init(settings: AppSettings) {
        self.settings = settings
        self.store = KeystrokeStore(settings: settings)

        let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let height: CGFloat = 160
        let rect = NSRect(x: screen.minX, y: screen.minY + 80, width: screen.width, height: height)

        panel = NSPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.isFloatingPanel = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.contentView = NSHostingView(rootView: KeystrokeOverlay(store: store))
        if settings.overlayEnabled {
            panel.orderFrontRegardless()
        }

        cancellable = settings.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.reposition()
                self?.updateVisibility()
            }
        }
        reposition()
    }

    func push(_ event: KeyEvent) {
        store.append(event)
    }

    private func updateVisibility() {
        if settings.overlayEnabled {
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }

    private func reposition() {
        guard let screen = NSScreen.main?.frame else { return }
        let h: CGFloat = 160
        let margin: CGFloat = 20
        let cornerW: CGFloat = 500

        let rect: NSRect
        switch settings.position {
        case .bottom:
            rect = NSRect(x: screen.minX, y: screen.minY + margin, width: screen.width, height: h)
        case .top:
            rect = NSRect(x: screen.minX, y: screen.maxY - h - margin, width: screen.width, height: h)
        case .center:
            rect = NSRect(x: screen.minX, y: screen.midY - h / 2, width: screen.width, height: h)
        case .topLeft:
            rect = NSRect(x: screen.minX + margin, y: screen.maxY - h - margin, width: cornerW, height: h)
        case .topRight:
            rect = NSRect(x: screen.maxX - cornerW - margin, y: screen.maxY - h - margin, width: cornerW, height: h)
        case .bottomLeft:
            rect = NSRect(x: screen.minX + margin, y: screen.minY + margin, width: cornerW, height: h)
        case .bottomRight:
            rect = NSRect(x: screen.maxX - cornerW - margin, y: screen.minY + margin, width: cornerW, height: h)
        }
        panel.setFrame(rect, display: true)
    }
}
