import AppKit
import CoreData

/// 所有调用都在所属 context 队列中；不在通知回调线程读取托管对象。
final class CabinetStore {
    let context: NSManagedObjectContext
    init(context: NSManagedObjectContext) { self.context = context }

    func migrateLegacyTags() throws {
        let request: NSFetchRequest<Command> = Command.fetchRequest()
        request.predicate = NSPredicate(format: "tagsMigrated == NO")
        for command in try context.fetch(request) {
            if let category = command.category { command.addToTags(category) }
            command.tagsMigrated = true
        }
        if context.hasChanges { try context.save() }
    }

    func save(_ command: Command?, title: String, body: String, tags: Set<Category>,
              image: Data? = nil, origin: UUID? = nil) throws -> Command {
        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || image != nil else {
            throw CabinetError.invalid("请输入正文或添加图片")
        }
        let item = command ?? Command(context: context, name: "", content: "")
        item.name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        item.content = body
        item.tags = NSSet(set: tags.filter { $0.deletedAt == nil })
        item.tagsMigrated = true
        item.category = nil
        item.imageData = image
        item.originID = origin ?? item.originID
        item.updatedAt = Date()
        try context.save()
        return item
    }

    func collect(_ source: ClipboardItem) throws -> Command {
        if let id = source.id {
            let request: NSFetchRequest<Command> = Command.fetchRequest()
            request.predicate = NSPredicate(format: "originID == %@", id as CVarArg)
            if let existing = try context.fetch(request).first {
                existing.deletedAt = nil
                try context.save()
                return existing
            }
        }
        return try save(nil, title: "", body: source.type == "image" ? "" : source.content ?? "", tags: [],
                        image: source.type == "image" ? source.data : nil, origin: source.id)
    }

    func createTag(_ name: String, group: TagGroup? = nil) throws -> Category {
        let value = try validName(name, entity: "Category")
        let tag = Category(context: context, name: value)
        tag.group = group
        try context.save()
        return tag
    }

    func createGroup(_ name: String) throws -> TagGroup {
        let value = try validName(name, entity: "TagGroup")
        let group = TagGroup(context: context)
        group.id = UUID()
        group.name = value
        try context.save()
        return group
    }

    func rename(_ object: NSManagedObject, to name: String) throws {
        let value = try validName(name, entity: object.entity.name!, excluding: object)
        object.setValue(value, forKey: "name")
        try context.save()
    }

    private func validName(_ name: String, entity: String, excluding: NSManagedObject? = nil) throws -> String {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw CabinetError.invalid("名称不能为空") }
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.predicate = NSPredicate(format: "name ==[cd] %@ AND deletedAt == nil", value)
        guard try context.fetch(request).allSatisfy({ $0 == excluding }) else {
            throw CabinetError.invalid("这个名称已经存在")
        }
        return value
    }

    func move(_ tag: Category, to group: TagGroup?) throws {
        tag.group = group
        tag.previousGroupID = nil
        try context.save()
    }

    func trash(_ object: NSManagedObject) throws {
        object.setValue(Date(), forKey: "deletedAt")
        if let group = object as? TagGroup {
            for tag in group.tags as? Set<Category> ?? [] {
                tag.previousGroupID = group.id
                tag.group = nil
            }
        }
        try context.save()
    }

    func restore(_ object: NSManagedObject) throws {
        if let tag = object as? Category { _ = try validName(tag.name ?? "", entity: "Category", excluding: tag) }
        if let group = object as? TagGroup {
            _ = try validName(group.name ?? "", entity: "TagGroup", excluding: group)
            let request: NSFetchRequest<Category> = Category.fetchRequest()
            if let id = group.id {
                request.predicate = NSPredicate(format: "previousGroupID == %@ AND group == nil", id as CVarArg)
                for tag in try context.fetch(request) {
                    tag.group = group
                    tag.previousGroupID = nil
                }
            }
        }
        object.setValue(nil, forKey: "deletedAt")
        try context.save()
    }
}

enum CabinetError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let text) = self { return text }; return nil }
}

extension Command {
    var activeTags: [Category] {
        (tags as? Set<Category> ?? []).filter { $0.deletedAt == nil }
            .sorted { ($0.name ?? "").localizedStandardCompare($1.name ?? "") == .orderedAscending }
    }
    var displayTitle: String {
        let custom = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return custom.isEmpty ? CabinetContent.title(content ?? "", image: imageData != nil) : custom
    }
}

enum CabinetContent {
    static func title(_ text: String, image: Bool = false) -> String {
        var start = text.startIndex
        while start < text.endIndex {
            let end = text[start...].firstIndex(where: \.isNewline) ?? text.endIndex
            let line = text[start..<end].trimmingCharacters(in: .whitespaces)
            if !line.isEmpty { return line }
            guard end < text.endIndex else { break }
            start = text.index(after: end)
        }
        return image ? "图片" : "未命名片段"
    }
    static func isMonospaced(_ text: String) -> Bool {
        text.hasPrefix("/") || text.hasPrefix("~/") || text.hasPrefix("git ") ||
        text.contains("\n    ") || text.hasPrefix("func ") ||
        text.hasPrefix("npm ") || text.hasPrefix("docker ")
    }
}
