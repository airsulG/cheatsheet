//
//  ClipboardManager.swift
//  cheatsheet
//
//  Created by 周麒 on 2025/6/9.
//

import Foundation
#if os(macOS)
import AppKit
#endif

class ClipboardManager {
    
    static let shared = ClipboardManager()
    
    private init() {}
    
    /// 复制文本到剪贴板
    /// - Parameter text: 要复制的文本
    /// - Returns: 是否复制成功
    @discardableResult
    func copy(_ text: String) -> Bool {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
        #else
        return false
        #endif
    }
    
    /// 从剪贴板获取文本
    /// - Returns: 剪贴板中的文本，如果没有则返回 nil
    func paste() -> String? {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        return pasteboard.string(forType: .string)
        #else
        return nil
        #endif
    }
    
    /// 检查剪贴板是否包含文本
    /// - Returns: 是否包含文本
    func hasText() -> Bool {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        return pasteboard.string(forType: .string) != nil
        #else
        return false
        #endif
    }
}
