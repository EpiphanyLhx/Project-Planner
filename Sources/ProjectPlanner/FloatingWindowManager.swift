import AppKit
import Combine
import SwiftUI

@MainActor
final class FloatingWindowManager: NSObject, ObservableObject, NSWindowDelegate {
    @Published private(set) var isVisible = false

    private var panel: FloatingTaskPanel?

    func toggle(store: StudyStore) {
        if isVisible {
            hide()
        } else {
            show(store: store)
        }
    }

    func show(store: StudyStore) {
        let panel = panel ?? makePanel(store: store)
        setPinned(UserDefaults.standard.object(forKey: "isWidgetPinned") as? Bool ?? true)
        panel.orderFrontRegardless()
        isVisible = true
    }

    func hide() {
        panel?.orderOut(nil)
        isVisible = false
    }

    func setPinned(_ isPinned: Bool) {
        panel?.level = isPinned ? .floating : .normal
    }

    func windowWillClose(_ notification: Notification) {
        isVisible = false
    }

    private func makePanel(store: StudyStore) -> FloatingTaskPanel {
        let screen = NSScreen.main
        let maximumHeight = (screen?.visibleFrame.height ?? 800) * 0.8
        let taskHeight = CGFloat(max(store.todayTasks.count, 1)) * 54
        let preferredHeight = min(max(126 + taskHeight, 180), maximumHeight)
        let size = NSSize(width: 250, height: preferredHeight)

        let panel = FloatingTaskPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "今日任务"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.animationBehavior = .utilityWindow
        panel.delegate = self

        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        let widget = FloatingTaskWidgetView(
            store: store,
            onPinChange: { [weak self] isPinned in
                self?.setPinned(isPinned)
            },
            onClose: { [weak self] in
                self?.hide()
            }
        )
        let hostingController = NSHostingController(rootView: widget)
        hostingController.sizingOptions = []
        panel.contentViewController = hostingController
        panel.minSize = NSSize(width: 220, height: 180)
        panel.maxSize = NSSize(width: 10_000, height: 10_000)

        if !panel.setFrameUsingName("FloatingTaskWidgetFrame"), let visibleFrame = screen?.visibleFrame {
            let origin = NSPoint(
                x: visibleFrame.maxX - size.width - 18,
                y: visibleFrame.midY - size.height / 2
            )
            panel.setFrame(NSRect(origin: origin, size: size), display: false)
        }
        panel.setFrameAutosaveName("FloatingTaskWidgetFrame")

        self.panel = panel
        return panel
    }
}

private final class FloatingTaskPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

struct PanelAccessor: NSViewRepresentable {
    let onResolve: (NSPanel) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        resolvePanel(from: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        resolvePanel(from: nsView)
    }

    private func resolvePanel(from view: NSView) {
        DispatchQueue.main.async {
            if let panel = view.window as? NSPanel {
                onResolve(panel)
            }
        }
    }
}

struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        DraggableNSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class DraggableNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
