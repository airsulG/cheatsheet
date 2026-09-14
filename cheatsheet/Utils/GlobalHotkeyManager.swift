//
//  GlobalHotkeyManager.swift
//  cheatsheet
//
//  Created by 周麒 on 2025/8/10.
//

import Foundation
import Carbon
import AppKit
// 引入菜单栏控制器以便快捷键打开/收起顶部面板
// 注意：该引用需要配合在 App 入口处进行初始化配置
// MenuBarController.shared.configure(with:) 在 cheatsheetApp 中调用
 

class GlobalHotkeyManager {

    static let shared = GlobalHotkeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    private init() {}

    func register(isPreview: Bool = false) {
        // 定义快捷键ID
        let hotKeyID = EventHotKeyID(signature: "cht1".fourChar(), id: 1)

        // 定义快捷键组合：Command + Shift + C
        // kVK_ANSI_C is the key code for 'C'
        let keyCode = UInt32(kVK_ANSI_C)
        // cmdKey and shiftKey are modifier flags
        let modifiers = UInt32(cmdKey | shiftKey | (isPreview ? optionKey : 0))

        // 1. 注册全局快捷键
        var gMyHotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &gMyHotKeyRef)
        if status != noErr {
            print("Error: Unable to register hotkey, status: \(status)")
            return
        }
        self.hotKeyRef = gMyHotKeyRef

        // 2. 安装事件处理器以监听快捷键事件
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        let installStatus = InstallEventHandler(GetApplicationEventTarget(), {
            (handlerRef, eventRef, userData) -> OSStatus in
            // 将 self (GlobalHotkeyManager instance) 从 userData 中恢复
            let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData!).takeUnretainedValue()
            return manager.handleHotKeyEvent(eventRef)
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)

        if installStatus != noErr {
            print("Error: Unable to install event handler, status: \(installStatus)")
        }
    }

    private func handleHotKeyEvent(_ eventRef: EventRef?) -> OSStatus {
        guard let eventRef = eventRef else { return OSStatus(eventNotHandledErr) }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            eventRef,
            UInt32(kEventParamDirectObject),
            UInt32(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        if status != noErr {
            return status
        }
        
        // 检查是否是我们注册的快捷键
        if hotKeyID.signature == "cht1".fourChar() && hotKeyID.id == 1 {
            // 在主线程切换底部横条（Shelf）
            DispatchQueue.main.async {
                CabinetWindowController.shared.toggle()
            }
            return noErr
        }
        
        return OSStatus(eventNotHandledErr)
    }

    func unregister() {
        if let hotKeyRef = self.hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler = self.eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
}

// Helper to convert a 4-character string to a FourCharCode (OSType)
extension String {
    func fourChar() -> FourCharCode {
        return self.utf16.reduce(0, {$0 << 8 + FourCharCode($1)})
    }
}
