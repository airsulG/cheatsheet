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

    func toggle() {
        if panel?.isVisible == true { model?.requestClose() }
        else { show() }
    }
    func show() {
        if NSWorkspace.shared.frontmostApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp = NSWorkspace.shared.frontmostApplication
        }
        ensurePanel()
        guard let panel else { return }
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
    private func ensurePanel() {
        guard panel == nil else { return }
        let context = PersistenceController.shared.container.viewContext
        let pasteboard = CabinetRuntime.isPreview ? NSPasteboard(name: .init("cheatsheet-cabinet-preview")) : .general
        let model = CabinetViewModel(context: context, pasteboard: pasteboard)
        self.model = model
        let panel = CabinetPanel(contentRect: NSRect(x: 0, y: 0, width: 1140, height: 740),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.title = CabinetRuntime.isPreview ? "cheatsheet · 隔离验收" : "cheatsheet"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.appearance = NSAppearance(named: UserDefaults.standard.string(forKey: "cabinetAppearance") == "light" ? .aqua : .darkAqua)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.minSize = NSSize(width: 760, height: 560)
        panel.contentViewController = NSHostingController(rootView: CabinetView(model: model))
        panel.setFrameAutosaveName(CabinetRuntime.isPreview ? "CabinetPreview" : "Cabinet")
        if panel.frame.width > (NSScreen.main?.visibleFrame.width ?? 1200) {
            panel.setContentSize(NSSize(width: 1000, height: 650))
        }
        panel.center()
        panel.delegate = self
        model.closeWindow = { [weak self] in self?.hide() }
        panel.onCancel = { [weak model] in model?.requestClose() }
        self.panel = panel
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        model?.requestClose()
        return false
    }
}

enum CabinetRuntime {
    /// 独立验收构建可使用：不监控/修改系统剪贴板，不读写真实 store，不注册用户快捷键。
    static var isPreview: Bool {
        #if DEBUG
        return CommandLine.arguments.contains("--cabinet-preview") ||
            Bundle.main.bundleIdentifier == "zhouqiaaha.top.cheatsheet.cabinet-preview"
        #else
        return false
        #endif
    }
}
