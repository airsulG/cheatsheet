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

struct ClipboardPreviewItem: Identifiable, Equatable {
    let id: NSManagedObjectID
    let uuid: UUID?
    let type: String
    let contentPreview: String
    let sourceAppName: String?
    let sourceAppIconData: Data?
    let sourceAppIconCacheKey: String?
    /// 仅当 type == "image" 且字节 ≤ maxImagePreviewBytes 时携带 PNG 字节，
    /// 用于 ShelfCard 渲染缩略；否则为 nil 由视图回退到占位文本。
    let imageData: Data?
    let createdAt: Date?

    var isTextLike: Bool {
        switch type {
        case "image", "file":
            return false
        default:
            return true
        }
    }

    /// 把异步加载到的二进制字节合并回当前 preview。文本字段不变。
    func withBlobs(sourceAppIconData: Data?,
                   sourceAppIconCacheKey: String?,
                   imageData: Data?) -> ClipboardPreviewItem {
        ClipboardPreviewItem(
            id: id,
            uuid: uuid,
            type: type,
            contentPreview: contentPreview,
            sourceAppName: sourceAppName,
            sourceAppIconData: sourceAppIconData,
            sourceAppIconCacheKey: sourceAppIconCacheKey,
            imageData: imageData,
            createdAt: createdAt
        )
    }
}

final class PagedClipboardViewModel: ObservableObject {
    private let viewContext: NSManagedObjectContext
    private let previewContext: NSManagedObjectContext

    @Published var items: [ClipboardItem] = []
    @Published var previewItems: [ClipboardPreviewItem] = []
    @Published var isLoading: Bool = false
    @Published var isPreviewLoading: Bool = false
    @Published var hasMore: Bool = true
    @Published var hasMorePreview: Bool = true
    @Published var errorMessage: String?

    var pageSize: Int = 30
    var previewPageSize: Int = 16
    private var offset: Int = 0
    private var previewOffset: Int = 0
    private var previewGeneration: Int = 0
    private let maxPreviewCharacters = 2_000
    /// 写入端 NSWorkspace 序列化的 macOS App 图标 PNG 普遍 130KB ~ 200KB（多分辨率位图），
    /// 旧值 64KB 会把全部图标裁断成 nil。512KB 提供 2.5× 余量，能挡住极端异常值。
    private let maxSourceAppIconBytes = 512 * 1024
    /// image 类型条目缩略的字节上限。当前预览面板一次最多 16 条，
    /// 16 × 2MB = 32MB 量级可控；超过时回退到 <image> 文本占位。
    private let maxImagePreviewBytes = 2 * 1024 * 1024

    init(context: NSManagedObjectContext) {
        self.viewContext = context
        let previewContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        previewContext.persistentStoreCoordinator = context.persistentStoreCoordinator
        previewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        previewContext.automaticallyMergesChangesFromParent = true
        self.previewContext = previewContext

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contextDidSave(_:)),
            name: .NSManagedObjectContextDidSave,
            object: nil
        )
    }

    @objc private func contextDidSave(_ notification: Notification) {
        // Selector 在「发布 save 的那个线程」上同步派发；这里很可能在后台私有队列。
        // 跨线程仅允许读 NSManagedObject 的类指针和 objectID。
        let userInfo = notification.userInfo
        let inserted = (userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject>) ?? []
        let updated  = (userInfo?[NSUpdatedObjectsKey]  as? Set<NSManagedObject>) ?? []
        let deleted  = (userInfo?[NSDeletedObjectsKey]  as? Set<NSManagedObject>) ?? []

        let insertedIDs = Set(inserted.compactMap { $0 is ClipboardItem ? $0.objectID : nil })
        let updatedIDs  = Set(updated.compactMap  { $0 is ClipboardItem ? $0.objectID : nil })
        let deletedIDs  = Set(deleted.compactMap  { $0 is ClipboardItem ? $0.objectID : nil })

        guard !(insertedIDs.isEmpty && updatedIDs.isEmpty && deletedIDs.isEmpty) else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // 仅当列表已经被加载过才做增量；空列表交给 ensurePreviewFirstPageLoaded
            // 在用户进入剪贴板 tab 时统一触发。
            guard !self.previewItems.isEmpty else { return }
            self.applyChanges(insertedIDs: insertedIDs,
                              updatedIDs: updatedIDs,
                              deletedIDs: deletedIDs)
        }
    }

    /// 把 NSManagedObjectContextDidSave 的 inserted/updated/deleted 增量地反映到 previewItems。
    /// 不再像旧实现那样整页 reset，避免每次复制都重抓 16 条 + 全量 enrichBlobs，
    /// 也避免列表滚动位置和图片缩略图闪烁。
    private func applyChanges(insertedIDs: Set<NSManagedObjectID>,
                              updatedIDs: Set<NSManagedObjectID>,
                              deletedIDs: Set<NSManagedObjectID>) {
        // 1) 删除：直接从 previewItems 移除并修正 offset
        if !deletedIDs.isEmpty {
            let removedCount = previewItems.filter { deletedIDs.contains($0.id) }.count
            if removedCount > 0 {
                previewItems.removeAll { deletedIDs.contains($0.id) }
                previewOffset = max(0, previewOffset - removedCount)
            }
        }

        // 2) 插入 + 更新：把这些 ID 的文本字段抓回来
        let allIDs = insertedIDs.union(updatedIDs)
        guard !allIDs.isEmpty else { return }

        let generation = previewGeneration
        let maxPreviewCharacters = maxPreviewCharacters

        previewContext.perform { [weak self] in
            guard let self else { return }

            let req: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
            req.predicate = NSPredicate(format: "SELF IN %@", allIDs)
            // 文本两阶段策略：第一阶段只取文本字段，第二阶段交给 enrichBlobs。
            req.propertiesToFetch = ["id", "content", "type", "createdAt", "sourceBundleId", "sourceAppName"]
            req.returnsObjectsAsFaults = true
            req.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItem.createdAt, ascending: false)]

            let fetched: [ClipboardItem]
            do {
                fetched = try self.previewContext.fetch(req)
            } catch {
                return
            }

            let textualPreviews: [ClipboardPreviewItem] = fetched.map { item in
                let type = item.type ?? "text"
                return ClipboardPreviewItem(
                    id: item.objectID,
                    uuid: item.id,
                    type: type,
                    contentPreview: Self.previewText(
                        item.content,
                        type: type,
                        maxCharacters: maxPreviewCharacters
                    ),
                    sourceAppName: item.sourceAppName,
                    sourceAppIconData: nil,
                    sourceAppIconCacheKey: nil,
                    imageData: nil,
                    createdAt: item.createdAt
                )
            }

            DispatchQueue.main.async {
                guard generation == self.previewGeneration else { return }
                guard !textualPreviews.isEmpty else { return }

                for preview in textualPreviews {
                    if let idx = self.previewItems.firstIndex(where: { $0.id == preview.id }) {
                        // updated：原地替换文本字段。blob 字段会在下面 enrichBlobs 重新填回。
                        self.previewItems[idx] = preview
                    } else {
                        // inserted：按 createdAt 倒序找到合适插入位置；
                        // ClipboardItem 默认排序就是 createdAt 倒序，新增条目通常顶端插入。
                        let insertAt = self.previewItems.firstIndex(where: {
                            ($0.createdAt ?? .distantPast) < (preview.createdAt ?? .distantPast)
                        }) ?? self.previewItems.count
                        self.previewItems.insert(preview, at: insertAt)
                        self.previewOffset += 1
                    }
                }

                // 第二阶段：异步补 blob，复用 task 12 的 enrichBlobs 路径。
                self.enrichBlobs(forItemsWithIDs: textualPreviews.map { $0.id },
                                 generation: generation)
            }
        }
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

    func refreshLoadedClipboardData() {
        if !items.isEmpty {
            resetAndLoadFirstPage()
        }

        if !previewItems.isEmpty {
            resetPreviewAndLoadFirstPage()
        }
    }

    func resetPreviewAndLoadFirstPage() {
        previewGeneration += 1
        previewItems.removeAll()
        previewOffset = 0
        hasMorePreview = true
        isPreviewLoading = false
        loadNextPreviewPage()
    }

    func ensurePreviewFirstPageLoaded() {
        if previewItems.isEmpty {
            resetPreviewAndLoadFirstPage()
        }
    }

    func loadNextPreviewPageIfNeeded(currentItem: ClipboardPreviewItem) {
        guard let index = previewItems.firstIndex(where: { $0.id == currentItem.id }) else { return }
        let threshold = max(previewItems.count - 4, 0)
        if index >= threshold {
            loadNextPreviewPage()
        }
    }

    func filteredPreviewItems(matching query: String) -> [ClipboardPreviewItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return previewItems }
        return previewItems.filter { item in
            item.type.localizedCaseInsensitiveContains(q) ||
            item.contentPreview.localizedCaseInsensitiveContains(q) ||
            (item.sourceAppName ?? "").localizedCaseInsensitiveContains(q)
        }
    }

    func loadNextPreviewPage() {
        guard !isPreviewLoading, hasMorePreview else { return }

        isPreviewLoading = true
        errorMessage = nil

        let generation = previewGeneration
        let offset = previewOffset
        let limit = previewPageSize
        let maxPreviewCharacters = maxPreviewCharacters

        previewContext.perform { [weak self] in
            guard let self else { return }

            let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItem.createdAt, ascending: false)]
            request.fetchOffset = offset
            request.fetchLimit = limit
            request.fetchBatchSize = limit
            request.relationshipKeyPathsForPrefetching = []
            // 第一阶段只取文本字段，避免 external blob IO 阻塞首屏。
            // sourceAppIcon / data 在 enrichBlobs 阶段异步补回。
            request.propertiesToFetch = ["id", "content", "type", "createdAt", "sourceBundleId", "sourceAppName"]
            request.returnsObjectsAsFaults = true

            do {
                let page = try self.previewContext.fetch(request)
                let previews = page.map { item in
                    let type = item.type ?? "text"
                    return ClipboardPreviewItem(
                        id: item.objectID,
                        uuid: item.id,
                        type: type,
                        contentPreview: Self.previewText(
                            item.content,
                            type: type,
                            maxCharacters: maxPreviewCharacters
                        ),
                        sourceAppName: item.sourceAppName,
                        sourceAppIconData: nil,
                        sourceAppIconCacheKey: nil,
                        imageData: nil,
                        createdAt: item.createdAt
                    )
                }
                let pageIDs = previews.map { $0.id }

                DispatchQueue.main.async {
                    guard generation == self.previewGeneration else { return }
                    self.previewItems.append(contentsOf: previews)
                    self.previewOffset += previews.count
                    self.hasMorePreview = previews.count == limit
                    self.isPreviewLoading = false

                    // 第二阶段：异步补 blob，避免阻塞首屏。
                    self.enrichBlobs(forItemsWithIDs: pageIDs, generation: generation)
                }
            } catch {
                DispatchQueue.main.async {
                    guard generation == self.previewGeneration else { return }
                    self.errorMessage = "加载剪贴板失败: \(error.localizedDescription)"
                    self.isPreviewLoading = false
                    self.hasMorePreview = false
                }
            }
        }
    }

    /// 第二阶段加载：拉取 sourceAppIcon / data 这两个 external blob 字段，
    /// 在主队列把对应 previewItems 合并回去。这一步如果用户切走 generation 会被丢弃。
    private func enrichBlobs(forItemsWithIDs ids: [NSManagedObjectID], generation: Int) {
        guard !ids.isEmpty else { return }

        let maxSourceAppIconBytes = maxSourceAppIconBytes
        let maxImagePreviewBytes = maxImagePreviewBytes

        previewContext.perform { [weak self] in
            guard let self else { return }
            // 用 SELF IN ids 一次性把这一页的 blob 字段拉回来，比逐条 existingObject 高效。
            let req: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
            req.predicate = NSPredicate(format: "SELF IN %@", ids)
            req.returnsObjectsAsFaults = false
            // 不限制 propertiesToFetch：让 CoreData 一次性 materialize 包括 external blob 在内的全部属性。

            let fetched: [ClipboardItem]
            do {
                fetched = try self.previewContext.fetch(req)
            } catch {
                return
            }

            // 在 BG 队列就把字节裁好，避免到主队列再做 cap 判断 + Data 拷贝
            struct Blobs {
                let iconData: Data?
                let iconCacheKey: String?
                let imageData: Data?
            }
            var blobs: [NSManagedObjectID: Blobs] = [:]
            blobs.reserveCapacity(fetched.count)
            for item in fetched {
                let iconData = Self.cappedSourceAppIconData(item.sourceAppIcon, maxBytes: maxSourceAppIconBytes)
                let imageData: Data? = ((item.type ?? "text") == "image")
                    ? Self.cappedImageData(item.data, maxBytes: maxImagePreviewBytes)
                    : nil
                blobs[item.objectID] = Blobs(
                    iconData: iconData,
                    iconCacheKey: Self.sourceAppIconCacheKey(for: iconData),
                    imageData: imageData
                )
            }

            DispatchQueue.main.async {
                guard generation == self.previewGeneration else { return }
                guard !blobs.isEmpty else { return }
                for (idx, preview) in self.previewItems.enumerated() {
                    if let b = blobs[preview.id] {
                        self.previewItems[idx] = preview.withBlobs(
                            sourceAppIconData: b.iconData,
                            sourceAppIconCacheKey: b.iconCacheKey,
                            imageData: b.imageData
                        )
                    }
                }
            }
        }
    }

    private static func cappedSourceAppIconData(_ data: Data?, maxBytes: Int) -> Data? {
        guard let data, data.count <= maxBytes else { return nil }
        return data
    }

    private static func cappedImageData(_ data: Data?, maxBytes: Int) -> Data? {
        guard let data, data.count <= maxBytes else { return nil }
        return data
    }

    private static func sourceAppIconCacheKey(for data: Data?) -> String? {
        guard let data else { return nil }

        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in data {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return "\(data.count)-\(hash)"
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

    @discardableResult
    func copyPreviewItem(_ item: ClipboardPreviewItem) -> Bool {
        var result = false
        viewContext.performAndWait {
            guard let clipboardItem = try? viewContext.existingObject(with: item.id) as? ClipboardItem else {
                result = false
                return
            }
            result = copyItem(clipboardItem)
        }
        return result
    }

    func deleteItem(_ item: ClipboardItem) {
        viewContext.perform {
            self.viewContext.delete(item)
            do {
                try self.viewContext.save()
                DispatchQueue.main.async {
                    self.items.removeAll { $0.objectID == item.objectID }
                    self.previewItems.removeAll { $0.id == item.objectID }
                }
            } catch {
                DispatchQueue.main.async { self.errorMessage = "删除失败: \(error.localizedDescription)" }
            }
        }
    }

    func deletePreviewItem(_ item: ClipboardPreviewItem) {
        viewContext.perform {
            guard let clipboardItem = try? self.viewContext.existingObject(with: item.id) as? ClipboardItem else {
                DispatchQueue.main.async { self.previewItems.removeAll { $0.id == item.id } }
                return
            }

            self.viewContext.delete(clipboardItem)
            do {
                try self.viewContext.save()
                DispatchQueue.main.async {
                    self.previewItems.removeAll { $0.id == item.id }
                    self.items.removeAll { $0.objectID == item.id }
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

    private static func previewText(_ content: String?, type: String, maxCharacters: Int) -> String {
        switch type {
        case "image":
            return "<image>"
        case "file":
            return fileName(from: content)
        default:
            let normalized = (content ?? "")
                .replacingOccurrences(of: "\r\n", with: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard normalized.count > maxCharacters else { return normalized }
            return String(normalized.prefix(maxCharacters)) + "…"
        }
    }

    private static func fileName(from content: String?) -> String {
        guard let content, let url = URL(string: content) else { return content ?? "<file>" }
        return url.lastPathComponent
    }
}
