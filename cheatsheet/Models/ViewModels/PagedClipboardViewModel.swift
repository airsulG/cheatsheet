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
        isLoading = true
        errorMessage = nil

        let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItem.createdAt, ascending: false)]
        request.fetchOffset = offset
        request.fetchLimit = pageSize

        do {
            let page = try viewContext.fetch(request)
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
            ok = pb.setString(item.content ?? "", forType: .html)
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
}
