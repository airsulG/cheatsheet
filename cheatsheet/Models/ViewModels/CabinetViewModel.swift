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
        case .history(let c): return CabinetContent.title(c.content ?? "", image: c.type == "image")
        }
    }
    var body: String {
        switch self { case .snippet(let c): return c.content ?? ""; case .history(let c): return c.content ?? "" }
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
    @Published var tagQuery = ""
    @Published var items: [CabinetItem] = []
    @Published var tags: [Category] = []
    @Published var groups: [TagGroup] = []
    @Published var deleted: [NSManagedObject] = []
    @Published var selection: NSManagedObjectID?
    @Published var draft: CabinetDraft?
    @Published var error: String?
    @Published var feedback = ""
    @Published var clipboardCount = 0
    @Published var snippetCount = 0
    @Published var favoriteCount = 0
    @Published var tagCounts: [NSManagedObjectID: Int] = [:]
    @Published var sort = "最近修改"
    var closeWindow: (() -> Void)?
    var focusSearch: (() -> Void)?
    private var originalDraft: CabinetDraft?
    private var contexts: [CabinetLocation: (String, NSManagedObjectID?)] = [:]
    private var observer: NSObjectProtocol?
    private var refreshScheduled = false
    private let pasteboard: NSPasteboard

    init(context: NSManagedObjectContext, pasteboard: NSPasteboard = .general) {
        self.context = context
        self.store = CabinetStore(context: context)
        self.pasteboard = pasteboard
        perform { try store.migrateLegacyTags() }
        reload()
        observer = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextObjectsDidChange,
            object: context, queue: .main) { [weak self] _ in
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
            cr.fetchBatchSize = 80
            let commands = try context.fetch(cr)
            let active = commands.filter { $0.deletedAt == nil }
            snippetCount = active.count
            favoriteCount = active.filter(\.isFavorite).count
            tagCounts = [:]
            for command in active {
                for tag in command.activeTags { tagCounts[tag.objectID, default: 0] += 1 }
            }
            let hr: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
            clipboardCount = try context.count(for: hr)
            deleted = (allTags.filter { $0.deletedAt != nil } as [NSManagedObject]) +
                (allGroups.filter { $0.deletedAt != nil } as [NSManagedObject]) +
                (commands.filter { $0.deletedAt != nil } as [NSManagedObject])
            if case .tag(let id) = location, !tags.contains(where: { $0.objectID == id }) { location = .all }
            if location == .clipboard {
                hr.fetchBatchSize = 80
                hr.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
                let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
                if !q.isEmpty { hr.predicate = NSPredicate(format: "content CONTAINS[cd] %@ OR sourceAppName CONTAINS[cd] %@", q, q) }
                items = try context.fetch(hr).map(CabinetItem.history)
            } else {
                let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
                var result = active.filter { c in
                    switch location {
                    case .favorites: return c.isFavorite
                    case .tag(let id): return c.activeTags.contains { $0.objectID == id }
                    case .trash: return false
                    default: return true
                    }
                }
                if !q.isEmpty { result = result.filter {
                    ($0.name ?? "").localizedStandardContains(q) || ($0.content ?? "").localizedStandardContains(q) ||
                    $0.activeTags.contains { ($0.name ?? "").localizedStandardContains(q) }
                } }
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
        }
    }

    @discardableResult
    func allowLeaving() -> Bool {
        guard dirty else { return true }
        let alert = NSAlert()
        alert.messageText = "保留正在编辑的内容？"
        alert.informativeText = "保存后继续，或留在这里编辑。"
        alert.addButton(withTitle: "继续编辑")
        alert.addButton(withTitle: "保存并继续")
        alert.addButton(withTitle: "放弃修改")
        switch alert.runModal() {
        case .alertSecondButtonReturn: return save()
        case .alertThirdButtonReturn: draft = nil; originalDraft = nil; return true
        default: return false
        }
    }

    func navigate(_ target: CabinetLocation) {
        guard allowLeaving() else { return }
        contexts[location] = (query, selection)
        draft = nil; originalDraft = nil
        location = target
        query = contexts[target]?.0 ?? ""
        selection = contexts[target]?.1
        reload()
    }
    func search(_ text: String) {
        guard !dirty || allowLeaving() else { return }
        draft = nil; originalDraft = nil; query = text; reload()
    }
    func select(_ id: NSManagedObjectID) {
        guard id != selection, allowLeaving() else { return }
        draft = nil; originalDraft = nil; selection = id
    }
    func moveSelection(_ offset: Int) {
        guard !items.isEmpty else { return }
        let index = items.firstIndex { $0.id == selection } ?? 0
        select(items[min(max(0, index + offset), items.count - 1)].id)
    }
    func newSnippet() {
        guard allowLeaving() else { return }
        var value = CabinetDraft()
        if case .tag(let id) = location { value.tags = [id] }
        if location == .clipboard || location == .trash { navigate(.all) }
        draft = value; originalDraft = value
    }
    func edit() {
        guard case .snippet(let command) = selected, allowLeaving() else { return }
        let value = CabinetDraft(title: command.name ?? "", body: command.content ?? "",
            tags: Set(command.activeTags.map(\.objectID)), image: command.imageData, commandID: command.objectID)
        draft = value; originalDraft = value
    }
    @discardableResult
    func save() -> Bool {
        guard let value = draft else { return true }
        do {
            let command = try value.commandID.map { try context.existingObject(with: $0) as! Command }
            let selectedTags = Set(value.tags.compactMap { try? context.existingObject(with: $0) as? Category })
            let saved = try store.save(command, title: value.title, body: value.body, tags: selectedTags, image: value.image)
            draft = nil; originalDraft = nil
            query = ""
            if case .tag(let id) = location, !selectedTags.contains(where: { $0.objectID == id }) { location = .all }
            if location == .favorites && !saved.isFavorite { location = .all }
            selection = saved.objectID; reload()
            feedback = "已保存"
            return true
        } catch { self.error = error.localizedDescription; return false }
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
        if let data = item.image, let image = NSImage(data: data) {
            success = pasteboard.writeObjects([image])
            if !item.body.isEmpty { _ = pasteboard.setString(item.body, forType: .string) }
        } else { success = pasteboard.setString(item.body, forType: .string) }
        guard success else { error = "复制失败，请重试"; return }
        feedback = "已复制"
        if close { closeWindow?() }
    }
    func collect() {
        guard case .history(let source) = selected else { return }
        perform {
            let item = try store.collect(source)
            navigate(.all)
            query = ""; selection = item.objectID; reload(); edit()
        }
    }
    func requestClose() { if allowLeaving() { closeWindow?() } }
    func perform(_ action: () throws -> Void) {
        do { try action() } catch { self.error = error.localizedDescription }
    }
}
