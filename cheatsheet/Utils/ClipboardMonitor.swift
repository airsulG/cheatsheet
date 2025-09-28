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
        context.perform {
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            let fetchRequest: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "createdAt < %@", sevenDaysAgo as NSDate)
            
            do {
                let itemsToDelete = try self.context.fetch(fetchRequest)
                if !itemsToDelete.isEmpty {
                    for item in itemsToDelete {
                        self.context.delete(item)
                    }
                    try self.context.save()
                    print("✅ ClipboardMonitor: Cleaned up \(itemsToDelete.count) items older than 7 days.")
                }
            } catch {
                print("❌ Error cleaning up old clipboard items: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Capture Helpers

extension ClipboardMonitor {
    /// 统一提取剪贴板内容，识别多类型
    /// 优先级：fileURL > image > html > rtf > url > string
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
        // 尝试 HTML
        if let html = pasteboard.string(forType: .html), !html.isEmpty {
            return (type: "html", content: html, data: nil)
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
        // 兜底：纯文本
        if let newText = pasteboard.string(forType: .string), !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (type: "text", content: newText, data: nil)
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
