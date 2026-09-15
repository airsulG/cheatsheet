import AppKit
import SwiftUI

final class CabinetPanel: NSPanel {
    var onCancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}

@MainActor
final class CabinetWindowController: NSObject, NSWindowDelegate {
    static let shared = CabinetWindowController()
    private var panel: CabinetPanel?
    private var model: CabinetViewModel?
    private var previousApp: NSRunningApplication?
    private var keyMonitor: Any?
    private var cardMouseMonitor: Any?

    func toggle() {
        if panel?.isKeyWindow == true && NSApp.isActive && panel?.isMiniaturized == false { model?.requestClose() }
        else { show() }
    }
    func show() {
        if NSWorkspace.shared.frontmostApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp = NSWorkspace.shared.frontmostApplication
        }
        ensurePanel()
        guard let panel else { return }
        if panel.isMiniaturized { panel.deminiaturize(nil) }
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }),
           !screen.visibleFrame.intersects(panel.frame) {
            panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.midX - panel.frame.width / 2,
                                         y: screen.visibleFrame.midY - panel.frame.height / 2))
        }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        model?.reload()
        model?.focusSearch?()
    }
    func hide() {
        panel?.orderOut(nil)
        previousApp?.activate(options: [.activateIgnoringOtherApps])
    }
    func canTerminate() -> Bool { model?.allowLeaving() ?? true }
    private func ensurePanel() {
        guard panel == nil else { return }
        let context = PersistenceController.shared.container.viewContext
        let pasteboard = CabinetRuntime.isPreview ? NSPasteboard(name: .init("cheatsheet-cabinet-preview")) : .general
        let model = CabinetViewModel(context: context, pasteboard: pasteboard)
        model.successFeedback = { CabinetSoundPlayer.shared.request($0) }
        model.cancelPendingFeedback = { CabinetSoundPlayer.shared.cancelPending() }
        self.model = model
        let panel = CabinetPanel(contentRect: NSRect(x: 0, y: 0, width: 1140, height: 740),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        panel.title = CabinetRuntime.isPreview ? "cheatsheet · 隔离验收" : "cheatsheet"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.titlebarSeparatorStyle = .none
        panel.appearance = NSAppearance(named: UserDefaults.standard.string(forKey: "cabinetAppearance") == "light" ? .aqua : .darkAqua)
        panel.isFloatingPanel = false
        panel.level = .normal
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.minSize = NSSize(width: 760, height: 560)
        let cardInteraction = CabinetCardInteraction(model: model)
        let hosting = NSHostingController(rootView: CabinetView(model: model, onCardClick: { id in
            cardInteraction.activate(id, event: NSApp.currentEvent)
        }))
        hosting.safeAreaRegions = []
        hosting.sizingOptions = [.minSize]
        panel.contentViewController = hosting
        let available = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1280, height: 900)
        panel.setContentSize(NSSize(width: min(1140, available.width - 60), height: min(740, available.height - 80)))
        panel.setFrameAutosaveName(CabinetRuntime.isPreview ? "CabinetPreview" : "Cabinet")
        if panel.frame.width > (NSScreen.main?.visibleFrame.width ?? 1200) {
            panel.setContentSize(NSSize(width: 1000, height: 650))
        }
        panel.center()
        panel.delegate = self
        model.closeWindow = { [weak self] in self?.hide() }
        panel.onCancel = { [weak model] in model?.escape() }
        self.panel = panel
        cardMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak panel] event in
            guard event.window === panel, NSApp.modalWindow == nil else { return event }
            return cardInteraction.handle(event) ? nil : event
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak panel] event in
            guard panel?.isKeyWindow == true, NSApp.modalWindow == nil,
                  RunLoop.current.currentMode != .eventTracking else { return event }
            if let text = panel?.firstResponder as? NSTextView, text.hasMarkedText() { return event }
            let command = event.modifierFlags.contains(.command)
            if command {
                switch event.keyCode {
                case 1: if model.draft != nil { _ = model.save(); return nil }
                case 40: model.focusSearch?(); return nil
                case 45: model.newSnippet(); return nil
                case 36: model.copy(close: true); return nil
                case 13: model.requestClose(); return nil
                default: break
                }
            } else if event.keyCode == 53 {
                model.escape()
                return nil
            } else if model.searchHasFocus || !(panel?.firstResponder is NSTextView) {
                switch event.keyCode {
                case 125: model.moveSelection(model.gridColumnCount); return nil
                case 126: model.moveSelection(-model.gridColumnCount); return nil
                case 123: if !model.searchHasFocus { model.moveSelection(-1); return nil }
                case 124: if !model.searchHasFocus { model.moveSelection(1); return nil }
                case 36: model.copy(close: true); return nil
                default: break
                }
            }
            return event
        }
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        model?.requestClose()
        return false
    }
    func windowDidResignKey(_ notification: Notification) {
        guard let text = panel?.firstResponder as? NSTextView, text.hasMarkedText() else {
            model?.autosave()
            return
        }
    }
}

enum CabinetRuntime {
    /// 独立验收构建：不监控/修改系统剪贴板，不读写真实 store，使用独立验收快捷键。
    static var isPreview: Bool {
        #if DEBUG
        return CommandLine.arguments.contains("--cabinet-preview") ||
            (Bundle.main.bundleIdentifier?.hasPrefix("zhouqiaaha.top.cheatsheet.cabinet-preview") ?? false)
        #else
        return false
        #endif
    }
}
