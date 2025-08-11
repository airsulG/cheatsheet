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
        GlobalHotkeyManager.shared.register()

        // 使用后台上下文进行监控
        let backgroundContext = persistenceController.container.newBackgroundContext()
        clipboardMonitor = ClipboardMonitor(context: backgroundContext, pasteboard: SystemPasteboard())
        clipboardMonitor.startMonitoring()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    clipboardMonitor.stopMonitoring()
                }
        }
    }
}
