import AppKit
import CoreData
import Combine

enum CabinetLocation: Hashable {
    case clipboard, all, favorites, tag(NSManagedObjectID), trash
}

enum CabinetItem: Identifiable {
    case snippet(Command), history(ClipboardItem)
    var object: NSManagedObject {
        switch self { case .snippet(let c): return c; case .history(let c): return c }
    }
    var id: NSManagedObjectID { object.objectID }
    var title: String {
        switch self {
        case .snippet(let c): return c.displayTitle
        case .history(let c): return c.type == "image" ? "图片" : CabinetContent.title(c.content ?? "")
        }
    }
    var body: String {
        switch self { case .snippet(let c): return c.content ?? ""; case .history(let c): return c.type == "image" ? "" : c.content ?? "" }
    }
    var image: Data? {
        switch self { case .snippet(let c): return c.imageData; case .history(let c): return c.type == "image" ? c.data : nil }
    }
    var tags: [Category] { if case .snippet(let c) = self { return c.activeTags }; return [] }
    var source: String { if case .history(let c) = self { return c.sourceAppName ?? "剪贴板" }; return "" }
}

struct CabinetDraft: Equatable {
    var title = ""
    var body = ""
    var tags: Set<NSManagedObjectID> = []
    var image: Data?
    var commandID: NSManagedObjectID?
}

@MainActor
final class CabinetViewModel: ObservableObject {
    let context: NSManagedObjectContext
    let store: CabinetStore
    @Published var location: CabinetLocation = .all
    @Published var query = ""
    @Published var items: [CabinetItem] = []
    @Published var tags: [Category] = []
    @Published var groups: [TagGroup] = []
    @Published var deleted: [NSManagedObject] = []
    @Published var selection: NSManagedObjectID?
    @Published var selectionScrollRequest = 0
    @Published private(set) var isDetailPresented = false
    var detailUsesMotion = false
    var gridColumnCount = 1
    @Published var draft: CabinetDraft?
    @Published private(set) var editorSession = UUID()
    @Published private(set) var editorFocusRequest = 0
    @Published private(set) var saveStatus = ""
    @Published var error: String?
    @Published var feedback = ""
    @Published var copiedItemID: NSManagedObjectID?
    @Published private(set) var toastMessage: String?
    private var toastTask: Task<Void, Never>?
    @Published var clipboardCount = 0
    @Published var snippetCount = 0
    @Published var favoriteCount = 0
    @Published var tagCounts: [NSManagedObjectID: Int] = [:]
    @Published var sort = UserDefaults.standard.string(forKey: "cabinetSort") ?? "最近修改"
    var closeWindow: (() -> Void)?
    var focusSearch: (() -> Void)?
    var searchHasFocus = false
    private var originalDraft: CabinetDraft?
    private var pinnedDraftID: NSManagedObjectID?
    private var contexts: [CabinetLocation: (String, NSManagedObjectID?)] = [:]
    private var observer: NSObjectProtocol?
    private var refreshScheduled = false
    private let pasteboard: NSPasteboard
    private var rowPreviews: [NSManagedObjectID: (query: String, preview: CabinetRowPreview)] = [:]
    private var activeCommands: [Command] = []
    private var commandsByTag: [NSManagedObjectID: [Command]] = [:]

    init(context: NSManagedObjectContext, pasteboard: NSPasteboard = .general) {
        self.context = context
        self.store = CabinetStore(context: context)
        self.pasteboard = pasteboard
        perform { try store.migrateLegacyTags() }
        reload()
        observer = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextObjectsDidChange,
            object: context, queue: .main) { [weak self] note in
            guard [NSInsertedObjectsKey, NSUpdatedObjectsKey, NSDeletedObjectsKey, NSRefreshedObjectsKey, NSInvalidatedAllObjectsKey]
                .contains(where: { note.userInfo?[$0] != nil }) else { return }
            Task { @MainActor [weak self] in
                guard let self, !self.refreshScheduled else { return }
                self.refreshScheduled = true
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.refreshScheduled = false
                    self.perform { try self.store.migrateLegacyTags() }
                    self.reload()
                }
            }
        }
    }

    var selected: CabinetItem? { items.first { $0.id == selection } }
    func rowPreview(for item: CabinetItem) -> CabinetRowPreview {
        if let cached = rowPreviews[item.id], cached.query == query { return cached.preview }
        let preview = CabinetRowPreview(item: item, query: query)
        if rowPreviews.count >= 256 { rowPreviews.removeAll(keepingCapacity: true) }
        rowPreviews[item.id] = (query, preview)
        return preview
    }
    var collectionLabel: String {
        guard case .history(let history) = selected, let id = history.id else { return "保存为片段" }
        let request: NSFetchRequest<Command> = Command.fetchRequest()
        request.predicate = NSPredicate(format: "originID == %@", id as CVarArg)
        return ((try? context.count(for: request)) ?? 0) > 0 ? "查看已存片段" : "保存为片段"
    }
    var dirty: Bool { draft != originalDraft }
    var heading: String {
        switch location {
        case .all: return "全部资料"
        case .clipboard: return "剪贴板"
        case .favorites: return "常用"
        case .trash: return "最近删除"
        case .tag(let id): return (try? context.existingObject(with: id) as? Category)?.name ?? "标签"
        }
    }

    func reload() {
        rowPreviews.removeAll(keepingCapacity: true)
        perform {
            let tr: NSFetchRequest<Category> = Category.fetchRequest()
            tr.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true), NSSortDescriptor(key: "name", ascending: true)]
            let allTags = try context.fetch(tr)
            tags = allTags.filter { $0.deletedAt == nil }
            let gr: NSFetchRequest<TagGroup> = TagGroup.fetchRequest()
            gr.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true), NSSortDescriptor(key: "name", ascending: true)]
            let allGroups = try context.fetch(gr)
            groups = allGroups.filter { $0.deletedAt == nil }
            let cr: NSFetchRequest<Command> = Command.fetchRequest()
            cr.relationshipKeyPathsForPrefetching = ["tags"]
            let commands = try context.fetch(cr)
            let active = commands.filter { $0.deletedAt == nil }
            activeCommands = active
            var byTag: [NSManagedObjectID: [Command]] = [:]
            for command in active {
                for tag in command.tags as? Set<Category> ?? [] where tag.deletedAt == nil {
                    byTag[tag.objectID, default: []].append(command)
                }
            }
            commandsByTag = byTag
            let counts = byTag.mapValues(\.count)
            if tagCounts != counts { tagCounts = counts }
            if snippetCount != active.count { snippetCount = active.count }
            let favorites = active.filter(\.isFavorite).count
            if favoriteCount != favorites { favoriteCount = favorites }
            let hr: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
            let historyCount = try context.count(for: hr)
            if clipboardCount != historyCount { clipboardCount = historyCount }
            deleted = (allTags.filter { $0.deletedAt != nil } as [NSManagedObject]) +
                (allGroups.filter { $0.deletedAt != nil } as [NSManagedObject]) +
                (commands.filter { $0.deletedAt != nil } as [NSManagedObject])
            if case .tag(let id) = location, !tags.contains(where: { $0.objectID == id }) { location = .all }
            refreshItems()
        }
    }

    /// 导航、搜索和排序使用已加载的片段；只有数据变化或重新打开窗口才重建统计。
    private func refreshItems() {
        perform {
            if location == .clipboard {
                let hr: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
                hr.fetchBatchSize = 80
                hr.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
                let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
                if !q.isEmpty { hr.predicate = NSPredicate(format: "content CONTAINS[cd] %@ OR sourceAppName CONTAINS[cd] %@", q, q) }
                items = try context.fetch(hr).map(CabinetItem.history)
            } else {
                let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
                var result: [Command]
                switch location {
                case .favorites: result = activeCommands.filter(\.isFavorite)
                case .tag(let id): result = commandsByTag[id] ?? []
                case .trash: result = []
                default: result = activeCommands
                }
                if !q.isEmpty { result = result.filter {
                    ($0.name ?? "").localizedStandardContains(q) || ($0.content ?? "").localizedStandardContains(q) ||
                    $0.activeTags.contains { ($0.name ?? "").localizedStandardContains(q) }
                } }
                if let id = pinnedDraftID, let pinned = activeCommands.first(where: { $0.objectID == id }),
                   !result.contains(where: { $0.objectID == id }) { result.append(pinned) }
                result.sort {
                    switch sort {
                    case "标题": return $0.displayTitle.localizedStandardCompare($1.displayTitle) == .orderedAscending
                    case "手动顺序": return $0.order == $1.order ? $0.displayTitle < $1.displayTitle : $0.order < $1.order
                    default: return ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast)
                    }
                }
                items = result.map(CabinetItem.snippet)
            }
            if !items.contains(where: { $0.id == selection }) { selection = items.first?.id }
            synchronizeEditor()
        }
    }

    @discardableResult
    func allowLeaving() -> Bool {
        autosave()
    }

    @discardableResult
    func navigate(_ target: CabinetLocation) -> Bool {
        guard target != location else { return true }
        guard allowLeaving() else { return false }
        contexts[location] = (query, selection)
        detailUsesMotion = false; isDetailPresented = false
        draft = nil; originalDraft = nil; pinnedDraftID = nil
        location = target
        query = contexts[target]?.0 ?? ""
        selection = contexts[target]?.1
        refreshItems()
        selectionScrollRequest += 1
        return true
    }
    func search(_ text: String) {
        guard text != query else { return }
        guard !dirty || allowLeaving() else { return }
        detailUsesMotion = false; isDetailPresented = false
        draft = nil; originalDraft = nil; pinnedDraftID = nil; query = text; refreshItems()
    }
    @discardableResult
    func select(_ id: NSManagedObjectID, focusEditor: Bool = false) -> Bool {
        if id == selection {
            if focusEditor { editorFocusRequest += 1 }
            return true
        }
        guard allowLeaving() else { return false }
        draft = nil; originalDraft = nil; pinnedDraftID = nil; selection = id
        synchronizeEditor()
        if focusEditor { editorFocusRequest += 1 }
        return true
    }
    func moveSelection(_ offset: Int) {
        guard !items.isEmpty else { return }
        let index = items.firstIndex { $0.id == selection } ?? 0
        if select(items[min(max(0, index + offset), items.count - 1)].id) {
            selectionScrollRequest += 1
        }
    }
    func newSnippet() {
        guard allowLeaving() else { return }
        var value = CabinetDraft()
        if case .tag(let id) = location { value.tags = [id] }
        if location == .clipboard || location == .trash { navigate(.all) }
        selection = nil; pinnedDraftID = nil
        draft = value; originalDraft = value
        detailUsesMotion = false; isDetailPresented = true
        editorSession = UUID(); saveStatus = ""; editorFocusRequest += 1
    }
    func edit() {
        synchronizeEditor()
        detailUsesMotion = false; isDetailPresented = true
        editorFocusRequest += 1
    }
    @discardableResult
    func toggleDetail(_ id: NSManagedObjectID, animated: Bool = false) -> Bool {
        if isDetailPresented && selection == id { return closeDetail(animated: animated) }
        return openDetail(id, animated: animated)
    }
    @discardableResult
    func openDetail(_ id: NSManagedObjectID, animated: Bool = false) -> Bool {
        guard select(id) else { return false }
        detailUsesMotion = animated; isDetailPresented = true
        editorFocusRequest += 1
        return true
    }
    @discardableResult
    func closeDetail(animated: Bool = false) -> Bool {
        guard allowLeaving() else { return false }
        detailUsesMotion = animated; isDetailPresented = false
        draft = nil; originalDraft = nil; pinnedDraftID = nil
        editorSession = UUID()
        refreshItems()
        focusSearch?()
        return true
    }
    func escape() {
        if isDetailPresented { closeDetail() }
        else { requestClose() }
    }
    private func synchronizeEditor() {
        // 后台刷新不能替换正在输入的内容，也不能给空白新片段填入旧片段。
        if dirty || (draft != nil && draft?.commandID == nil) { return }
        guard case .snippet(let command) = selected else {
            draft = nil; originalDraft = nil; return
        }
        let value = CabinetDraft(title: command.name ?? "", body: command.content ?? "",
            tags: Set(command.activeTags.map(\.objectID)), image: command.imageData, commandID: command.objectID)
        if draft == value { return }
        let changedItem = draft?.commandID != value.commandID
        draft = value; originalDraft = value
        if changedItem { editorSession = UUID(); saveStatus = "" }
    }
    @discardableResult
    func autosave(session: UUID? = nil) -> Bool {
        if let session, session != editorSession { return true }
        guard dirty, let value = draft else { return true }
        // 离开尚未输入内容的新建页，不生成空记录。
        if value.commandID == nil && value.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.image == nil && value.title.isEmpty { return true }
        return save()
    }
    @discardableResult
    func save() -> Bool {
        guard let value = draft else { return true }
        if !dirty && value.commandID != nil { return true }
        do {
            let command = try value.commandID.map { try context.existingObject(with: $0) as! Command }
            if command?.deletedAt != nil { throw CabinetError.invalid("片段已移到最近删除，输入内容仍保留，请先恢复片段。") }
            let selectedTags = Set(value.tags.compactMap { try? context.existingObject(with: $0) as? Category })
            let saved = try store.save(command, title: value.title, body: value.body, tags: selectedTags, image: value.image)
            var persisted = value
            persisted.commandID = saved.objectID; persisted.title = saved.name ?? ""
            draft = persisted; originalDraft = persisted
            selection = saved.objectID; pinnedDraftID = saved.objectID
            saveStatus = "已保存"; error = nil
            reload()
            showToast("已保存")
            // 通知刷新列表；不清空搜索，也不让失焦保存改变当前位置。
            return true
        } catch {
            clearToast()
            saveStatus = "保存失败，内容已保留"; self.error = error.localizedDescription
            return false
        }
    }
    func cancelEdit() {
        guard allowLeaving() else { return }
        draft = nil; originalDraft = nil
    }
    func copy(close: Bool) {
        if draft != nil, !save() { return }
        guard let item = selected else { return }
        pasteboard.clearContents()
        let success: Bool
        if case .history(let history) = item {
            success = ClipboardPayload.write(history, to: pasteboard)
        } else if let data = item.image, let image = NSImage(data: data) {
            success = pasteboard.writeObjects([image])
            if !item.body.isEmpty { _ = pasteboard.setString(item.body, forType: .string) }
        } else { success = pasteboard.setString(item.body, forType: .string) }
        guard success else { clearToast(); error = "复制失败，请重试"; return }
        showToast("已复制到剪贴板", copiedID: item.id)
        if close { closeWindow?() }
    }
    private func showToast(_ message: String, copiedID: NSManagedObjectID? = nil) {
        toastTask?.cancel()
        toastMessage = message
        copiedItemID = copiedID
        feedback = copiedID == nil ? "" : "已复制"
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.clearToast()
        }
    }
    private func clearToast() {
        toastTask?.cancel()
        toastTask = nil
        toastMessage = nil; copiedItemID = nil; feedback = ""
    }
    func collect() {
        guard case .history(let source) = selected else { return }
        perform {
            let item = try store.collect(source)
            navigate(.all)
            query = ""; selection = item.objectID; reload(); edit()
        }
    }
    func requestClose() {
        if allowLeaving() { detailUsesMotion = false; isDetailPresented = false; closeWindow?() }
    }
    func deleteHistory(_ history: ClipboardItem) {
        let alert = NSAlert()
        alert.messageText = "删除这条剪贴板记录？"
        alert.informativeText = "已保存的片段会保留。原始记录删除后无法恢复。"
        alert.addButton(withTitle: "取消")
        alert.addButton(withTitle: "删除记录")
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        perform { context.delete(history); try context.save() }
    }
    func setSort(_ value: String) {
        sort = value
        UserDefaults.standard.set(value, forKey: "cabinetSort")
        refreshItems()
    }
    func move(_ item: CabinetItem, offset: Int) {
        guard allowLeaving(), case .snippet = item, let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let target = index + offset
        guard items.indices.contains(target) else { return }
        var reordered = items
        reordered.swapAt(index, target)
        perform {
            for (order, value) in reordered.enumerated() {
                if case .snippet(let command) = value { command.order = Int32(order) }
            }
            try context.save()
            setSort("手动顺序")
        }
    }
    func perform(_ action: () throws -> Void) {
        do { try action() } catch { self.error = error.localizedDescription }
    }
    @discardableResult
    func toggleFavorite(_ command: Command) -> Bool {
        guard allowLeaving() else { return false }
        let previous = command.isFavorite
        let timestamp = command.updatedAt
        do {
            command.toggleFavorite()
            try context.save()
            return true
        } catch {
            command.isFavorite = previous
            command.updatedAt = timestamp
            self.error = error.localizedDescription
            return false
        }
    }
}
