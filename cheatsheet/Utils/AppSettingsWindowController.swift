//
//  AppSettingsWindowController.swift
//  cheatsheet
//
//  Created by Codex on 2026/6/21.
//

import AppKit
import CoreData
import SwiftUI

final class AppSettingsWindowController {
    static let shared = AppSettingsWindowController()

    private var window: NSWindow?

    private init() {}

    func present(context: NSManagedObjectContext, clipboardViewModel: PagedClipboardViewModel) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = AppSettingsView(
            context: context,
            clipboardViewModel: clipboardViewModel,
            onDone: { [weak self] in
                self?.window?.close()
            }
        )
        let hosting = NSHostingController(rootView: view)
        let size = NSSize(width: 760, height: 560)

        let window = NSWindow(contentViewController: hosting)
        window.setContentSize(size)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.title = "设置"
        window.isReleasedWhenClosed = false
        window.level = .popUpMenu
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        center(window)

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.window = nil
        }

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func center(_ window: NSWindow) {
        if let screen = activeScreen() {
            let frame = screen.visibleFrame
            let size = window.frame.size
            let x = frame.midX - size.width / 2
            let y = frame.midY - size.height / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            window.center()
        }
    }

    private func activeScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        for screen in NSScreen.screens {
            if screen.frame.contains(mouse) {
                return screen
            }
        }
        return NSScreen.main
    }
}
