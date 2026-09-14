//
//  cheatsheetApp.swift
//  cheatsheet
//
//  Created by 周麒 on 2025/6/9.
//

import SwiftUI
import AppKit

@main
struct cheatsheetApp: App {
    let persistenceController = PersistenceController.shared
    private let clipboardMonitor: ClipboardMonitor

    init() {
        if !CabinetRuntime.isPreview { GlobalHotkeyManager.shared.register() }

        // 使用后台上下文进行监控
        let backgroundContext = persistenceController.container.newBackgroundContext()
        clipboardMonitor = ClipboardMonitor(context: backgroundContext, pasteboard: SystemPasteboard())
        if !CabinetRuntime.isPreview {
            clipboardMonitor.startMonitoring()
            BackupService(context: backgroundContext).runAutomaticBackupIfNeeded()
        } else {
            CabinetPreviewData.insert(into: persistenceController.container.viewContext)
        }
        DispatchQueue.main.async { CabinetWindowController.shared.show() }

        // 不再创建状态栏图标（顶部菜单栏图标已移除）

        // 监听退出，停止监控（避免在逃逸闭包中捕获 self）
        let monitor = clipboardMonitor
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { _ in
            monitor.stopMonitoring()
        }
    }

    var body: some Scene {
        // Agent App：不创建主窗口，保留一个空的设置入口
        Settings {
            EmptyView()
        }
    }
}
