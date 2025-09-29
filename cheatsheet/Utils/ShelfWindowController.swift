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

@MainActor
final class ShelfWindowController {
    static let shared = ShelfWindowController()

    private var panel: NSPanel?
    private var hosting: NSHostingController<ShelfView>?

    private init() {}

    func toggle() {
        if let panel = panel, panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        ensurePanel()
        guard let screen = ShelfWindowController.activeScreen(), let panel = panel else { return }
        // 初始折叠到 0 高度（使用屏幕 frame 以贴底，不留 Dock 间隙）
        let f = screen.frame
        let targetHeight: CGFloat = 300
        let startFrame = NSRect(x: f.minX, y: f.minY, width: f.width, height: 0.1)
        let overshoot: CGFloat = 18
        panel.setFrame(startFrame, display: false)
        panel.orderFrontRegardless()

        // 第一段：弹出至稍大（overshoot）
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            let midFrame = NSRect(x: f.minX, y: f.minY, width: f.width, height: targetHeight + overshoot)
            panel.animator().setFrame(midFrame, display: true)
        } completionHandler: {
            // 第二段：回弹至目标高度
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.12
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                let finalFrame = NSRect(x: f.minX, y: f.minY, width: f.width, height: targetHeight)
                panel.animator().setFrame(finalFrame, display: true)
            }
        }
    }

    func hide() {
        guard let panel = panel, let screen = Self.activeScreen() else { panel?.orderOut(nil); return }
        let f = screen.frame

        // 无回弹的单段隐藏动画：一次性收至最终高度
        let finalH: CGFloat = 0.1
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            // 如需更“干净”的加速，可改用自定义控制点：
            // ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 1.0, 1.0)
            let final = NSRect(x: f.minX, y: f.minY, width: f.width, height: finalH)
            panel.animator().setFrame(final, display: true)
        } completionHandler: {
            panel.orderOut(nil)
        }
    }

    // MARK: - Private

    private func ensurePanel() {
        guard panel == nil else { return }

        let context = PersistenceController.shared.container.viewContext
        let vm = ShelfViewModel(context: context)
        let contentView = ShelfView(viewModel: vm)
        let hosting = NSHostingController(rootView: contentView)
        self.hosting = hosting

        // 默认高度 300，初次创建时用主屏宽度，后续 show() 会重新定位
        let initialRect = NSRect(x: 0, y: 0, width: NSScreen.main?.frame.width ?? 1280, height: 300)
        let panel = NSPanel(
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
        let height: CGFloat = 300 // 默认高度 300
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
