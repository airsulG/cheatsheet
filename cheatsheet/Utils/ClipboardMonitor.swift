//
//  ClipboardMonitor.swift
//  cheatsheet
//
//  Created by 周麒 on 2025/8/11.
//

import AppKit
import CoreData
import CryptoKit

class ClipboardMonitor {
    private let context: NSManagedObjectContext
    private let pasteboard: PasteboardReading
    private var timer: Timer?
    private var lastSignature: String?
    private var lastChangeCount: Int
    
    init(context: NSManagedObjectContext, pasteboard: PasteboardReading) {
        self.context = context
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount
        
        // 先执行历史数据清理（将 XML 风格的 HTML 降级为文本）
        sanitizeExistingXMLLikeItems()

        // Run cleanup on initialization in the background
        cleanupOldItems()
        fetchLastItemSignature()
    }

    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func fetchLastItemSignature() {
        context.perform {
            let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItem.createdAt, ascending: false)]
            request.fetchLimit = 1
            
            do {
                let lastItem = try self.context.fetch(request).first
                if let item = lastItem {
                    self.lastSignature = self.computeSignature(type: item.type ?? "text", content: item.content, data: item.data)
                }
            } catch {
                print("❌ Error fetching last clipboard item: \(error)")
            }
        }
    }

    private func checkClipboard() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        // 抽取剪贴板内容（支持多类型）
        guard let captured = captureFromPasteboard() else { return }

        let signature = computeSignature(type: captured.type, content: captured.content, data: captured.data)
        guard signature != lastSignature else { return }
        lastSignature = signature

        context.perform {
            // 来源 App 元数据
            let app = NSWorkspace.shared.frontmostApplication
            let bundleId = app?.bundleIdentifier
            let appName = app?.localizedName
            var appIconData: Data? = nil
            if let url = app?.bundleURL {
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                icon.size = NSSize(width: 32, height: 32)
                appIconData = self.pngData(from: icon)
            }

            let item = ClipboardItem(
                context: self.context,
                content: captured.content ?? "",
                type: captured.type,
                sourceBundleId: bundleId,
                sourceAppName: appName,
                sourceAppIcon: appIconData
            )
            item.data = captured.data
            print("✅ ClipboardMonitor: Saved new item [\(captured.type)] - \(captured.content?.prefix(30) ?? "<binary>")")
            
            do {
                try self.context.save()
            } catch {
                print("❌ Error saving clipboard item: \(error)")
            }
        }
    }
    
    private func cleanupOldItems() {
        let retentionDays = ClipboardSettings.shared.retentionDays
        // 0 表示永久保留，不清理
        guard retentionDays > 0 else { return }
        
        context.perform {
            guard let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) else { return }
            let fetchRequest: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "createdAt < %@", cutoffDate as NSDate)
            
            do {
                let itemsToDelete = try self.context.fetch(fetchRequest)
                if !itemsToDelete.isEmpty {
                    for item in itemsToDelete {
                        self.context.delete(item)
                    }
                    try self.context.save()
                    print("✅ ClipboardMonitor: Cleaned up \(itemsToDelete.count) items older than \(retentionDays) days.")
                }
            } catch {
                print("❌ Error cleaning up old clipboard items: \(error.localizedDescription)")
            }
        }
    }
    
    /// 启动时对已有剪贴板记录做一次清理，将 XML 风格的 HTML 降级为纯文本
    private func sanitizeExistingXMLLikeItems() {
        context.perform {
            let req: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
            req.predicate = NSPredicate(format: "type == %@", "html")
            do {
                let items = try self.context.fetch(req)
                var changed = 0
                for item in items {
                    let s = item.content ?? ""
                    if isXMLLikeHTML(s) {
                        item.type = "text"
                        item.content = htmlToPlainText(s)
                        item.data = nil
                        changed += 1
                    }
                }
                if changed > 0 {
                    try self.context.save()
                    print("✅ Sanitized \(changed) XML-like HTML items to plain text.")
                }
            } catch {
                print("❌ Error sanitizing existing items: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Capture Helpers

extension ClipboardMonitor {
    /// 统一提取剪贴板内容，识别多类型
    /// 优先级：fileURL > image > string(纯文本) > html > rtf > url
    /// 注意：将纯文本优先级提高，避免显示富文本的样式标签
    fileprivate func captureFromPasteboard() -> (type: String, content: String?, data: Data?)? {
        // 尝试文件 URL
        if pasteboard.types.contains(.fileURL), let urlStr = pasteboard.string(forType: .fileURL), !urlStr.isEmpty {
            let previewIcon = iconPNG(forFileURLString: urlStr)
            return (type: "file", content: urlStr, data: previewIcon)
        }
        // 尝试图片（tiff/png）
        if let imageData = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png),
           let pngData = ensurePNG(fromImageData: imageData) {
            return (type: "image", content: "<image>", data: pngData)
        }
        // 优先尝试纯文本（避免显示富文本的样式标签）
        if let plainText = pasteboard.string(forType: .string), !plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // 如果纯文本以 XML/HTML 标签开头（真正的 HTML/XML 代码），则做一次清理
            if isXMLLikeHTML(plainText) {
                let cleaned = stripTagsAndDecodeEntities(plainText)
                return (type: "text", content: cleaned, data: nil)
            }
            return (type: "text", content: plainText, data: nil)
        }
        // 尝试 HTML（仅当没有纯文本时，说明这是真正的 HTML 代码）
        if let html = pasteboard.string(forType: .html), !html.isEmpty {
            // 若为 XML 风格的 HTML，降级为纯文本
            if isXMLLikeHTML(html) {
                let cleaned = htmlToPlainText(html)
                return (type: "text", content: cleaned, data: nil)
            } else {
                return (type: "html", content: html, data: nil)
            }
        }
        // 尝试 RTF（转为纯文本预览）
        if let rtfData = pasteboard.data(forType: .rtf) {
            let plain = rtfToPlainText(rtfData) ?? ""
            return (type: "rtf", content: plain, data: rtfData)
        }
        // 尝试 URL（非文件）
        if let url = pasteboard.string(forType: .URL), !url.isEmpty {
            return (type: "url", content: url, data: nil)
        }
        return nil
    }

    fileprivate func computeSignature(type: String, content: String?, data: Data?) -> String {
        var input = "type=\(type)|"
        if let data = data {
            let hash = SHA256.hash(data: data)
            input += hash.compactMap { String(format: "%02x", $0) }.joined()
        } else {
            input += content ?? ""
        }
        // 最终再做一次 hash，得到固定长度签名
        let digest = SHA256.hash(data: input.data(using: .utf8) ?? Data())
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    fileprivate func ensurePNG(fromImageData data: Data) -> Data? {
        if let rep = NSBitmapImageRep(data: data),
           let png = rep.representation(using: .png, properties: [:]) {
            return png
        }
        if let img = NSImage(data: data) {
            return pngData(from: img)
        }
        return nil
    }

    fileprivate func pngData(from image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    fileprivate func rtfToPlainText(_ data: Data) -> String? {
        let options: [NSAttributedString.DocumentReadingOptionKey : Any] = [.documentType: NSAttributedString.DocumentType.rtf]
        if let attr = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return attr.string
        }
        return nil
    }

    fileprivate func iconPNG(forFileURLString urlStr: String) -> Data? {
        guard let url = URL(string: urlStr) else { return nil }
        let path = url.path
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: 64, height: 64)
        return pngData(from: icon)
    }
}

// MARK: - XML/HTML 清理工具（模块级函数，便于在其他文件调用）

/// 判断是否为“XML 风格”的 HTML/文本：
/// - 以 XML 声明开头：<?xml ...?>
/// - 常见 XML 根元素：<svg|<plist|<rss|<feed|<xml|<math
/// - 前 200 字符内出现 xmlns(:|=)
func isXMLLikeHTML(_ s: String) -> Bool {
    let prolog = #"^\s*<\?xml\b[^>]*\?>"#
    let roots  = #"^\s*<(svg|plist|rss|feed|xml|math)\b"#
    if s.range(of: prolog, options: .regularExpression) != nil { return true }
    if s.range(of: roots,  options: [.regularExpression, .caseInsensitive]) != nil { return true }
    if s.prefix(200).range(of: #"\bxmlns(:|=)"#, options: [.regularExpression, .caseInsensitive]) != nil { return true }
    return false
}

/// 将 HTML 文本转为可见纯文本；优先用 HTML 解析，失败回退到正则去标签 + 实体解码
func htmlToPlainText(_ s: String) -> String {
    if let data = s.data(using: .utf8),
       let attr = try? NSAttributedString(data: data,
                                          options: [.documentType: NSAttributedString.DocumentType.html],
                                          documentAttributes: nil) {
        return attr.string
    }
    return stripTagsAndDecodeEntities(s)
}

/// 正则去标签并解码常见实体
func stripTagsAndDecodeEntities(_ s: String) -> String {
    let noTags = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    return noTags
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
        .replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: "&quot;", with: "\"")
        .replacingOccurrences(of: "&#39;", with: "'")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}
