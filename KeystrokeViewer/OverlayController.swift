import AppKit
import SwiftUI
import Combine

final class OverlayController {
    private var panels: [NSPanel] = []
    private var clickPanels: [NSPanel] = []
    private let store: KeystrokeStore
    private let clickStore = ClickStore()
    private let cursorStore = CursorStore()
    private let settings: AppSettings
    private var cancellable: AnyCancellable?
    private var mouseMonitor: Any?
    private var scrollMonitor: Any?
    private var cursorTrackMonitor: Any?

    init(settings: AppSettings) {
        self.settings = settings
        self.store = KeystrokeStore(settings: settings)

        rebuildPanels()
        rebuildClickPanels()
        updateMouseMonitor()
        updateScrollMonitor()
        updateCursorTracker()

        cancellable = settings.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.rebuildPanels()
                self?.rebuildClickPanels()
                self?.updateMouseMonitor()
                self?.updateScrollMonitor()
                self?.updateCursorTracker()
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.rebuildPanels()
            self?.rebuildClickPanels()
        }
    }

    func push(_ event: KeyEvent) {
        store.append(event)
        if settings.resolvedScreenMode == .followActive {
            moveToActiveScreen()
        }
    }

    private func moveToActiveScreen() {
        guard let screen = NSScreen.main, let panel = panels.first else { return }
        position(panel, on: screen)
    }

    private func rebuildPanels() {
        let screens: [NSScreen]
        switch settings.resolvedScreenMode {
        case .allScreens:
            screens = NSScreen.screens
        case .mainOnly, .followActive:
            screens = [NSScreen.main].compactMap { $0 }
        }

        while panels.count > screens.count {
            panels.removeLast().orderOut(nil)
        }
        while panels.count < screens.count {
            panels.append(makePanel())
        }

        for (panel, screen) in zip(panels, screens) {
            position(panel, on: screen)
            if settings.overlayEnabled {
                panel.orderFrontRegardless()
            } else {
                panel.orderOut(nil)
            }
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
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
        return panel
    }

    private func position(_ panel: NSPanel, on screen: NSScreen) {
        let h: CGFloat = 160
        let margin: CGFloat = 20
        let cornerW: CGFloat = 500
        let sf = screen.frame

        let rect: NSRect
        switch settings.position {
        case .bottom:
            rect = NSRect(x: sf.minX, y: sf.minY + margin, width: sf.width, height: h)
        case .top:
            rect = NSRect(x: sf.minX, y: sf.maxY - h - margin, width: sf.width, height: h)
        case .center:
            rect = NSRect(x: sf.minX, y: sf.midY - h / 2, width: sf.width, height: h)
        case .topLeft:
            rect = NSRect(x: sf.minX + margin, y: sf.maxY - h - margin, width: cornerW, height: h)
        case .topRight:
            rect = NSRect(x: sf.maxX - cornerW - margin, y: sf.maxY - h - margin, width: cornerW, height: h)
        case .bottomLeft:
            rect = NSRect(x: sf.minX + margin, y: sf.minY + margin, width: cornerW, height: h)
        case .bottomRight:
            rect = NSRect(x: sf.maxX - cornerW - margin, y: sf.minY + margin, width: cornerW, height: h)
        case .custom:
            let cx = sf.minX + sf.width * settings.customPositionX - cornerW / 2
            let cy = sf.minY + sf.height * settings.customPositionY
            rect = NSRect(x: cx, y: cy, width: cornerW, height: h)
        }
        panel.setFrame(rect, display: true)
    }

    // MARK: - Click Visualization

    private func rebuildClickPanels() {
        let shouldShow = settings.overlayEnabled && (settings.showMouseClicks || settings.showCursorHighlight || settings.showScrollIndicator)

        let screens: [NSScreen]
        switch settings.resolvedScreenMode {
        case .allScreens, .followActive:
            screens = NSScreen.screens
        case .mainOnly:
            screens = [NSScreen.main].compactMap { $0 }
        }

        while clickPanels.count > screens.count {
            clickPanels.removeLast().orderOut(nil)
        }
        while clickPanels.count < screens.count {
            clickPanels.append(makeClickPanel(for: screens[clickPanels.count]))
        }

        for (panel, screen) in zip(clickPanels, screens) {
            if panel.frame != screen.frame {
                panel.setFrame(screen.frame, display: true)
                panel.contentView = NSHostingView(
                    rootView: ClickOverlayView(store: clickStore, cursorStore: cursorStore, settings: settings, screenFrame: screen.frame)
                )
            }
            if shouldShow {
                panel.orderFrontRegardless()
            } else {
                panel.orderOut(nil)
            }
        }
    }

    private func makeClickPanel(for screen: NSScreen) -> NSPanel {
        let panel = NSPanel(
            contentRect: screen.frame,
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
        panel.contentView = NSHostingView(
            rootView: ClickOverlayView(store: clickStore, cursorStore: cursorStore, settings: settings, screenFrame: screen.frame)
        )
        return panel
    }

    private func updateMouseMonitor() {
        if settings.overlayEnabled && settings.showMouseClicks {
            guard mouseMonitor == nil else { return }
            mouseMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
            ) { [weak self] event in
                guard let self else { return }
                let button: ClickButton
                switch event.type {
                case .leftMouseDown:  button = .left
                case .rightMouseDown: button = .right
                default:              button = .other
                }
                let click = ClickEvent(
                    location: NSEvent.mouseLocation,
                    button: button,
                    timestamp: Date()
                )
                DispatchQueue.main.async {
                    self.clickStore.append(click)
                }
            }
        } else {
            if let monitor = mouseMonitor {
                NSEvent.removeMonitor(monitor)
                mouseMonitor = nil
            }
        }
    }

    private func updateScrollMonitor() {
        if settings.overlayEnabled && settings.showScrollIndicator {
            guard scrollMonitor == nil else { return }
            scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self else { return }
                let deltaY = event.scrollingDeltaY
                guard abs(deltaY) > 2 else { return }
                let direction: ScrollDirection = deltaY > 0 ? .up : .down
                let scroll = ScrollEvent(
                    location: NSEvent.mouseLocation,
                    direction: direction,
                    timestamp: Date()
                )
                DispatchQueue.main.async {
                    self.clickStore.appendScroll(scroll)
                }
            }
        } else {
            if let monitor = scrollMonitor {
                NSEvent.removeMonitor(monitor)
                scrollMonitor = nil
            }
        }
    }

    private func updateCursorTracker() {
        if settings.overlayEnabled && settings.showCursorHighlight {
            guard cursorTrackMonitor == nil else { return }
            cursorStore.position = NSEvent.mouseLocation
            cursorTrackMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
            ) { [weak self] _ in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.cursorStore.position = NSEvent.mouseLocation
                }
            }
        } else {
            if let monitor = cursorTrackMonitor {
                NSEvent.removeMonitor(monitor)
                cursorTrackMonitor = nil
            }
        }
    }
}
