//
//  EditorWindowController.swift
//  cheatsheet
//
//  Created by Codex on 2025/8/28.
//

import Foundation
import AppKit
import SwiftUI

final class EditorWindowController {
    static let shared = EditorWindowController()

    private var windows: [NSWindow] = []

    private init() {}

    func presentCommandEdit(command: Command, commandViewModel: CommandViewModel) {
        let view = CommandFormView(command: command, commandViewModel: commandViewModel)
        present(view: AnyView(view), title: "编辑命令")
    }

    func presentNewCommand(category: Category, commandViewModel: CommandViewModel) {
        let view = CommandFormView(category: category, commandViewModel: commandViewModel)
        present(view: AnyView(view), title: "新建命令")
    }

    private func present(view: AnyView, title: String) {
        let hosting = NSHostingController(rootView: view)
        let size = NSSize(width: 720, height: 520)

        let win = NSWindow(contentViewController: hosting)
        win.setContentSize(size)
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        win.title = title
        win.isReleasedWhenClosed = false
        win.level = .popUpMenu // 确保出现在底部横条之上
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        center(win)

        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: win, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.windows.removeAll { $0 == win }
        }

        windows.append(win)
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func center(_ window: NSWindow) {
        if let screen = activeScreen() {
            let f = screen.visibleFrame
            let w = window.frame.size.width
            let h = window.frame.size.height
            let x = f.midX - w / 2
            let y = f.midY - h / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            window.center()
        }
    }

    private func activeScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        for s in NSScreen.screens { if s.frame.contains(mouse) { return s } }
        return NSScreen.main
    }
}

