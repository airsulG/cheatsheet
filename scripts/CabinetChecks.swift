import AppKit
import CoreData
@testable import cheatsheet

@main
struct CabinetChecks {
    @MainActor static func main() async throws {
        let modelURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let model = NSManagedObjectModel(contentsOf: modelURL)!
        let legacy = NSManagedObjectModel(contentsOf: modelURL.appendingPathComponent("cheatsheet.mom"))!
        // 旧模型夹具只写基础字段，避免同一进程内两版模型争用生成的 Swift 子类。
        legacy.entities.forEach { $0.managedObjectClassName = "NSManagedObject" }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("cabinet-check-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("migration.sqlite")
        func container(_ model: NSManagedObjectModel, url: URL? = nil) -> NSPersistentContainer {
            let c = NSPersistentContainer(name: "cheatsheet", managedObjectModel: model)
            let d = NSPersistentStoreDescription()
            if let url { d.url = url } else { d.type = NSInMemoryStoreType }
            d.shouldMigrateStoreAutomatically = true
            d.shouldInferMappingModelAutomatically = true
            c.persistentStoreDescriptions = [d]
            c.loadPersistentStores { _, e in precondition(e == nil, "\(String(describing: e))") }
            c.viewContext.automaticallyMergesChangesFromParent = true
            return c
        }
        let old = container(legacy, url: url)
        let oldTag = NSEntityDescription.insertNewObject(forEntityName: "Category", into: old.viewContext)
        let tagID = UUID()
        for (key, value) in ["id": tagID, "name": "原有分类", "createdAt": Date(), "updatedAt": Date(), "isPinned": true] as [String: Any] { oldTag.setValue(value, forKey: key) }
        let oldCommand = NSEntityDescription.insertNewObject(forEntityName: "Command", into: old.viewContext)
        let commandID = UUID()
        let body = "保留原来的完整正文\n" + String(repeating: "中文代码与路径\n", count: 1000) + "末尾关键字"
        for (key, value) in ["id": commandID, "name": "旧标题", "content": body, "createdAt": Date(), "updatedAt": Date(), "isFavorite": true, "order": Int32(8), "category": oldTag] as [String: Any] { oldCommand.setValue(value, forKey: key) }
        try old.viewContext.save()
        old.viewContext.reset()
        try old.persistentStoreCoordinator.remove(old.persistentStoreCoordinator.persistentStores[0])
        let upgraded = container(model, url: url)
        let context = upgraded.viewContext
        let store = CabinetStore(context: context)
        try store.migrateLegacyTags()
        let command = try context.fetch(Command.fetchRequest())[0]
        let tag = try context.fetch(Category.fetchRequest())[0]
        precondition(command.id == commandID && tag.id == tagID && command.content == body)
        precondition(command.activeTags == [tag] && command.isFavorite && command.order == 8 && tag.isPinned)
        print("PASS: v1 SQLite migration preserves IDs, full body, title, order, favorite and pin; adds tag relation")
        let group = try store.createGroup("工作")
        let second = try store.createTag("第二标签", group: group)
        let saved = try store.save(command, title: "", body: body, tags: [tag, second])
        precondition(saved.displayTitle == "保留原来的完整正文" && saved.content == body)
        let untagged = try store.save(nil, title: "", body: "没有标签的内容", tags: [])
        try store.migrateLegacyTags()
        precondition(untagged.activeTags.isEmpty && saved.activeTags.count == 2)
        try store.trash(tag)
        precondition(saved.activeTags.count == 1 && saved.content == body)
        try store.restore(tag)
        precondition(saved.activeTags.count == 2)
        try store.trash(group)
        precondition(second.group == nil)
        try store.rename(second, to: "改名后的标签")
        try store.restore(group)
        precondition(second.group == group && second.name == "改名后的标签")
        try store.trash(group)
        let other = try store.createGroup("其他")
        try store.move(second, to: other)
        try store.restore(group)
        precondition(second.group == other)
        do { _ = try store.createTag(" 改名后的标签 "); preconditionFailure("Duplicate tag accepted") }
        catch CabinetError.invalid { }
        print("PASS: multi-tag, optional title, no-tag save, non-destructive deletion, rename and group restore conflicts")
        let history = ClipboardItem(context: context, content: "原始记录")
        let collected = try store.collect(history)
        _ = try store.save(collected, title: "", body: "编辑后的片段", tags: [second])
        let again = try store.collect(history)
        precondition(again == collected && history.content == "原始记录")
        let imageData = Data([1, 2, 3, 4])
        let image = try store.save(nil, title: "", body: "", tags: [], image: imageData)
        let archive = try BackupService(context: context).makeArchive()
        let encoded = try JSONEncoder().encode(archive)
        let decoded = try JSONDecoder().decode(BackupArchive.self, from: encoded)
        let restored = container(model)
        _ = try BackupService(context: restored.viewContext).importArchive(decoded)
        let records = try restored.viewContext.fetch(Command.fetchRequest())
        precondition(records.count == 4 && records.contains { $0.content == body && $0.activeTags.count == 2 })
        precondition(records.contains { $0.content == "没有标签的内容" && $0.activeTags.isEmpty })
        precondition(records.contains { $0.imageData == imageData })
        precondition(records.contains { $0.originID == history.id })
        let v1 = BackupArchive(version: 1, categories: [BackupCategory(id: UUID(), name: "旧备份", order: 0,
            isPinned: false, createdAt: Date(), updatedAt: Date(), commands: [BackupCommand(id: UUID(),
            name: "旧片段", content: "旧备份正文", order: 0, isFavorite: false, favoriteOrder: nil,
            createdAt: Date(), updatedAt: Date())])])
        _ = try BackupService(context: restored.viewContext).importArchive(v1)
        let legacyImported = try restored.viewContext.fetch(Command.fetchRequest())
        precondition(legacyImported.contains { $0.content == "旧备份正文" && $0.activeTags.count == 1 })
        print("PASS: history source dedup and original protection; v2 JSON roundtrip covers groups, images, no tags and origin; imports v1")
        let named = NSPasteboard(name: .init("cabinet-check-\(UUID())"))
        let vm = CabinetViewModel(context: context, pasteboard: named)
        vm.search("末尾关键字")
        precondition(vm.items.count == 1)
        vm.copy(close: false)
        precondition(named.string(forType: .string) == body)
        vm.navigate(.clipboard)
        vm.search("原始记录")
        precondition(vm.items.count == 1)
        let selected = vm.selection
        vm.navigate(.all)
        vm.navigate(.clipboard)
        precondition(vm.query == "原始记录" && vm.selection == selected)
        let file = ClipboardItem(context: context, content: "file:///tmp/cabinet-check.txt", type: "file")
        precondition(ClipboardPayload.write(file, to: named))
        precondition(named.string(forType: .fileURL) == "file:///tmp/cabinet-check.txt")
        let link = ClipboardItem(context: context, content: "https://example.com/docs", type: "url")
        precondition(ClipboardPayload.write(link, to: named))
        precondition(named.string(forType: .URL) == link.content)
        let rich = ClipboardItem(context: context, content: "带格式正文", type: "rtf")
        rich.data = try NSAttributedString(string: "带格式正文").data(from: NSRange(location: 0, length: 5),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        precondition(ClipboardPayload.write(rich, to: named))
        precondition(named.data(forType: .rtf) == rich.data)
        let html = ClipboardItem(context: context, content: "<b>格式验收</b>", type: "html")
        precondition(ClipboardPayload.write(html, to: named))
        precondition(named.string(forType: .html) == html.content)
        precondition(named.string(forType: .string)?.contains("格式验收") == true)
        print("PASS: original file URL, URL, RTF and HTML payloads survive copying")
        named.releaseGlobally()
        print("PASS: full-body tail search, exact copy on isolated pasteboard, clipboard query and selection restoration")
        try context.save()
        let worker = upgraded.newBackgroundContext()
        try worker.performAndWait {
            _ = ClipboardItem(context: worker, content: "后台剪贴板实时到达")
            try worker.save()
        }
        try await Task.sleep(for: .milliseconds(250))
        vm.search("后台剪贴板实时到达")
        precondition(vm.items.count == 1 && vm.clipboardCount == 6)
        print("PASS: background clipboard save merges on main and becomes searchable without reopening")
        let savedImageID = image.id
        context.reset()
        try upgraded.persistentStoreCoordinator.remove(upgraded.persistentStoreCoordinator.persistentStores[0])
        let reopened = container(model, url: url)
        let persisted = try reopened.viewContext.fetch(Command.fetchRequest())
        precondition(persisted.count == 4 && persisted.contains { $0.id == savedImageID && $0.imageData == imageData })
        print("PASS: disk store closes and reopens with image and multi-tag assets intact")
        print("Isolated evidence store: \(directory.path)")
    }
}
