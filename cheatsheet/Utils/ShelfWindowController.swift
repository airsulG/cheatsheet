//
//  ShelfWindowController.swift
//  cheatsheet
//
//  Created by Codex on 2025/8/28.
//

import Foundation
import AppKit
import SwiftUI
import QuartzCore

/// 无标题栏的悬浮面板仍需接收搜索框的键盘输入。
final class ShelfPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

enum ShelfPanelHeightSettings {
    static let storageKey = "shelfPanelHeight"
    static let defaultHeight: CGFloat = 300
    static let minHeight: CGFloat = 260
    static let maxHeight: CGFloat = 680

    static var storedHeight: CGFloat {
        get {
            let raw = UserDefaults.standard.double(forKey: storageKey)
            guard raw > 0 else { return defaultHeight }
            return clamped(CGFloat(raw))
        }
        set {
            UserDefaults.standard.set(Double(clamped(newValue)), forKey: storageKey)
        }
    }

    static func clamped(_ height: CGFloat, on screen: NSScreen? = nil) -> CGFloat {
        let screenMax = screen.map { max(minHeight, $0.frame.height - 80) } ?? maxHeight
        let upperBound = min(maxHeight, screenMax)
        return min(max(height, minHeight), upperBound)
    }
}

@MainActor
final class ShelfWindowController {
    static let shared = ShelfWindowController()

    private var panel: NSPanel?
    private var hosting: NSHostingController<ShelfView>?
    /// 持有 ViewModel 引用，让 show() 在 panel 显示前能预先触发数据加载，
    /// 让 panel 打开动画与剪贴板首页 fetch 并行，避免"看到 panel 但列表是空的"。
    private var viewModel: ShelfViewModel?

    private init() {}

    func toggle() {
        if let panel = panel, panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func focusSearch() {
        panel?.makeKey()
    }

    func show() {
        ensurePanel()
        // 在面板出现动画之前就触发剪贴板首页预取，让 IO 与动画并行。
        // ensurePreviewFirstPageLoaded 内部用 isEmpty 守门，重复调用是 no-op。
        viewModel?.pagedClipboardVM.ensurePreviewFirstPageLoaded()
        guard let screen = ShelfWindowController.activeScreen(), let panel = panel else { return }
        let f = screen.frame
        let targetHeight = ShelfPanelHeightSettings.clamped(ShelfPanelHeightSettings.storedHeight, on: screen)
        let finalFrame = NSRect(x: f.minX, y: f.minY, width: f.width, height: targetHeight)
        let startFrame = NSRect(x: f.minX, y: f.minY - targetHeight, width: f.width, height: targetHeight)
        panel.setFrame(startFrame, display: false)
        panel.orderFrontRegardless()
        panel.displayIfNeeded()

        // 固定最终高度，只移动位置，避免打开期间反复触发 SwiftUI 高度重排。
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(finalFrame, display: true)
        }
    }

    func hide() {
        guard let panel = panel, let screen = Self.activeScreen() else { panel?.orderOut(nil); return }
        let f = screen.frame
        let currentHeight = ShelfPanelHeightSettings.clamped(panel.frame.height, on: screen)

        // 固定当前高度，只向屏幕底部外侧移动。
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            // 如需更“干净”的加速，可改用自定义控制点：
            // ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 1.0, 1.0)
            let final = NSRect(x: f.minX, y: f.minY - currentHeight, width: f.width, height: currentHeight)
            panel.animator().setFrame(final, display: true)
        } completionHandler: {
            panel.orderOut(nil)
        }
    }

    func currentHeight() -> CGFloat {
        guard let panel else { return ShelfPanelHeightSettings.storedHeight }
        return ShelfPanelHeightSettings.clamped(panel.frame.height, on: panel.screen)
    }

    func resize(to height: CGFloat, persist: Bool) {
        let screen = panel?.screen ?? Self.activeScreen()
        let targetHeight = ShelfPanelHeightSettings.clamped(height, on: screen)

        if persist {
            ShelfPanelHeightSettings.storedHeight = targetHeight
        }

        guard let panel, let screen else { return }
        let f = screen.frame
        let frame = NSRect(x: f.minX, y: f.minY, width: f.width, height: targetHeight)
        panel.setFrame(frame, display: true)
    }

    func resizeFromTopDrag(startHeight: CGFloat, translationY: CGFloat, persist: Bool) {
        resize(to: startHeight - translationY, persist: persist)
    }

    // MARK: - Private

    private func ensurePanel() {
        guard panel == nil else { return }

        let context = PersistenceController.shared.container.viewContext
        let vm = ShelfViewModel(context: context)
        self.viewModel = vm
        let contentView = ShelfView(viewModel: vm)
        let hosting = NSHostingController(rootView: contentView)
        self.hosting = hosting

        // 初次创建时用已保存高度；后续 show() 会按当前屏幕重新定位。
        let initialRect = NSRect(
            x: 0,
            y: 0,
            width: NSScreen.main?.frame.width ?? 1280,
            height: ShelfPanelHeightSettings.storedHeight
        )
        let panel = ShelfPanel(
            contentRect: initialRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        // 使用更高层级覆盖 Dock 区域
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.hasShadow = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.contentView = hosting.view

        self.panel = panel
    }

    private func positionPanel(on screen: NSScreen) {
        guard let panel = panel else { return }
        let height = ShelfPanelHeightSettings.clamped(ShelfPanelHeightSettings.storedHeight, on: screen)
        let f = screen.frame
        let frame = NSRect(x: f.minX, y: f.minY, width: f.width, height: height)
        panel.setFrame(frame, display: true)
    }

    private static func activeScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        // 坐标为全局坐标
        for screen in NSScreen.screens {
            if screen.frame.contains(mouse) { return screen }
        }
        return NSScreen.main
    }
}
