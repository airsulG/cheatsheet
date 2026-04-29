//
//  PagedClipboardViewModel.swift
//  cheatsheet
//
//  Created by Codex on 2025/8/28.
//

import Foundation
import CoreData
#if os(macOS)
import AppKit
#endif

final class PagedClipboardViewModel: ObservableObject {
    private let viewContext: NSManagedObjectContext

    @Published var items: [ClipboardItem] = []
    @Published var isLoading: Bool = false
    @Published var hasMore: Bool = true
    @Published var errorMessage: String?

    var pageSize: Int = 30
    private var offset: Int = 0

    init(context: NSManagedObjectContext) {
        self.viewContext = context

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contextDidSave(_:)),
            name: .NSManagedObjectContextDidSave,
            object: nil
        )
    }

    @objc private func contextDidSave(_ notification: Notification) {
        // 新数据写入时，仅重置第一页，避免一次性加载全部
        resetAndLoadFirstPage()
    }

    func resetAndLoadFirstPage() {
        items.removeAll()
        offset = 0
        hasMore = true
        loadNextPage()
    }

    func ensureFirstPageLoaded() {
        if items.isEmpty { resetAndLoadFirstPage() }
    }

    func loadNextPage() {
        guard !isLoading, hasMore else { return }
        
        // 🟢 优化1：在主线程标记加载状态
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }

        // 🟢 优化1：异步执行，避免阻塞主线程
        viewContext.perform {
            let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItem.createdAt, ascending: false)]
            request.fetchOffset = self.offset
            request.fetchLimit = self.pageSize
            
            // 🟢 优化2：只加载必要字段，排除大数据字段（data 和 sourceAppIcon）
            // 这些字段会在显示时通过 fault 机制按需加载
            request.propertiesToFetch = ["id", "content", "type", "createdAt", "sourceBundleId", "sourceAppName"]
            request.returnsObjectsAsFaults = false  // 避免后续访问时触发额外的 fault

            do {
                let page = try self.viewContext.fetch(request)
                
                // 🟢 结果回到主线程更新 UI
                DispatchQueue.main.async {
                    self.items.append(contentsOf: page)
                    self.offset += page.count
                    self.hasMore = page.count == self.pageSize
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "加载剪贴板失败: \(error.localizedDescription)"
                    self.isLoading = false
                    self.hasMore = false
                }
            }
        }
    }

    // MARK: - Operations

    @discardableResult
    func copyItem(_ item: ClipboardItem) -> Bool {
        #if os(macOS)
        let pb = NSPasteboard.general
        pb.clearContents()
        let type = item.type ?? "text"
        var ok = false
        switch type {
        case "image":
            if let data = item.data {
                ok = pb.setData(data, forType: .png) || pb.setData(data, forType: .tiff)
            }
        case "file":
            if let s = item.content, let url = URL(string: s) {
                ok = pb.setString(url.absoluteString, forType: .fileURL)
            }
        case "html":
            // 为提升兼容性：写回 HTML 同时提供纯文本回退
            let html = item.content ?? ""
            pb.declareTypes([.html, .string], owner: nil)
            _ = pb.setString(html, forType: .html)
            let plain = htmlToPlainText(html)
            _ = pb.setString(plain, forType: .string)
            ok = true
        case "rtf":
            if let data = item.data {
                ok = pb.setData(data, forType: .rtf)
            } else {
                ok = pb.setString(item.content ?? "", forType: .string)
            }
        case "url":
            ok = pb.setString(item.content ?? "", forType: .URL)
        default:
            ok = pb.setString(item.content ?? "", forType: .string)
        }
        return ok
        #else
        return false
        #endif
    }

    func deleteItem(_ item: ClipboardItem) {
        viewContext.perform {
            self.viewContext.delete(item)
            do {
                try self.viewContext.save()
                DispatchQueue.main.async {
                    self.items.removeAll { $0.objectID == item.objectID }
                }
            } catch {
                DispatchQueue.main.async { self.errorMessage = "删除失败: \(error.localizedDescription)" }
            }
        }
    }
    
    // MARK: - Cleanup
    
    /// 清理所有剪贴板历史
    func clearAll(completion: ((Int) -> Void)? = nil) {
        viewContext.perform {
            let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
            do {
                let all = try self.viewContext.fetch(request)
                let count = all.count
                for item in all {
                    self.viewContext.delete(item)
                }
                try self.viewContext.save()
                DispatchQueue.main.async {
                    self.items.removeAll()
                    self.offset = 0
                    self.hasMore = false
                    completion?(count)
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "清理失败: \(error.localizedDescription)"
                    completion?(0)
                }
            }
        }
    }
    
    /// 清理指定天数之前的记录
    func clearOlderThan(days: Int, completion: ((Int) -> Void)? = nil) {
        guard days > 0 else {
            completion?(0)
            return
        }
        
        viewContext.perform {
            guard let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else {
                DispatchQueue.main.async { completion?(0) }
                return
            }
            
            let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
            request.predicate = NSPredicate(format: "createdAt < %@", cutoffDate as NSDate)
            
            do {
                let oldItems = try self.viewContext.fetch(request)
                let count = oldItems.count
                for item in oldItems {
                    self.viewContext.delete(item)
                }
                try self.viewContext.save()
                DispatchQueue.main.async {
                    // 重新加载以更新列表
                    self.resetAndLoadFirstPage()
                    completion?(count)
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "清理失败: \(error.localizedDescription)"
                    completion?(0)
                }
            }
        }
    }
    
    // MARK: - Statistics
    
    /// 获取剪贴板记录总数
    func getTotalCount(completion: @escaping (Int) -> Void) {
        viewContext.perform {
            let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
            do {
                let count = try self.viewContext.count(for: request)
                DispatchQueue.main.async { completion(count) }
            } catch {
                DispatchQueue.main.async { completion(0) }
            }
        }
    }
    
    /// 获取数据占用大小（估算）
    func getStorageSize(completion: @escaping (Int64) -> Void) {
        viewContext.perform {
            let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
            do {
                let all = try self.viewContext.fetch(request)
                var totalSize: Int64 = 0
                for item in all {
                    // 估算：content 字符数 * 2 + data 大小
                    if let content = item.content {
                        totalSize += Int64(content.utf8.count)
                    }
                    if let data = item.data {
                        totalSize += Int64(data.count)
                    }
                    if let iconData = item.sourceAppIcon {
                        totalSize += Int64(iconData.count)
                    }
                }
                DispatchQueue.main.async { completion(totalSize) }
            } catch {
                DispatchQueue.main.async { completion(0) }
            }
        }
    }
}
