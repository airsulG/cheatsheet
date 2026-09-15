import AppKit
import CoreData
import SwiftUI
@testable import cheatsheet

@main struct CabinetOrganizationChecks {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        try await checkSidebar()
        let modelURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let model = NSManagedObjectModel(contentsOf: modelURL)!
        precondition(model.entitiesByName["Command"]?.relationshipsByName["pinnedTags"] != nil)
        try checkPinsAndBackup(model)
        try checkFailures(model)
        try checkV2Migration(modelURL)
    }

    @MainActor static func checkSidebar() async throws {
        precondition(CabinetSidebarWidth.visible(900, in: 1600) == 320)
        precondition(CabinetSidebarWidth.visible(100, in: 1600) == 160)
        precondition(CabinetSidebarWidth.visible(.nan, in: 1600) == 188)
        let suite = "cabinet-sidebar-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(280.0, forKey: CabinetSidebarWidth.preferenceKey)
        let host = NSHostingView(rootView: CabinetSplitView {
            Color.gray
        } content: {
            Color.black
        }.defaultAppStorage(defaults))
        host.frame = NSRect(x: 0, y: 0, width: 760, height: 560)
        func settle() async throws {
            host.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(30))
            host.layoutSubtreeIfNeeded()
        }
        func divider(in view: NSView) -> CabinetSidebarDivider? {
            (view as? CabinetSidebarDivider) ?? view.subviews.lazy.compactMap { divider(in: $0) }.first
        }
        func mouse(_ type: NSEvent.EventType, _ x: CGFloat) -> NSEvent {
            NSEvent.mouseEvent(with: type, location: NSPoint(x: x, y: 40), modifierFlags: [],
                timestamp: 0, windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)!
        }
        try await settle()
        let handle = divider(in: host)!
        func width() -> Double { (handle.accessibilityValue() as! NSNumber).doubleValue }
        precondition(width() == 228)
        precondition(defaults.double(forKey: CabinetSidebarWidth.preferenceKey) == 280)
        handle.mouseDown(with: mouse(.leftMouseDown, 228))
        handle.mouseUp(with: mouse(.leftMouseUp, 228))
        precondition(defaults.double(forKey: CabinetSidebarWidth.preferenceKey) == 280)
        host.frame.size.width = 1140
        try await settle()
        precondition(width() == 280, "Widening must restore the preference, not the temporary clamp")
        handle.mouseDown(with: mouse(.leftMouseDown, 280))
        handle.mouseDragged(with: mouse(.leftMouseDragged, 300))
        try await settle()
        precondition(width() == 300)
        precondition(defaults.double(forKey: CabinetSidebarWidth.preferenceKey) == 280, "Persist only at drag end")
        handle.mouseDragged(with: mouse(.leftMouseDragged, 600))
        handle.mouseUp(with: mouse(.leftMouseUp, 600))
        try await settle()
        precondition(width() == 320 && defaults.double(forKey: CabinetSidebarWidth.preferenceKey) == 320)
        precondition(handle.accessibilityPerformDecrement())
        try await settle()
        precondition(width() == 310 && UserDefaults(suiteName: suite)!.double(forKey: CabinetSidebarWidth.preferenceKey) == 310)
        handle.mouseDown(with: mouse(.leftMouseDown, 310))
        handle.mouseDragged(with: mouse(.leftMouseDragged, -100))
        handle.mouseUp(with: mouse(.leftMouseUp, -100))
        try await settle()
        precondition(width() == 160)
        print("PASS: native sidebar drag, min/max, adaptive clamp, no-op click, end-only persistence, resize restoration and accessibility step")
    }

    static func container(_ model: NSManagedObjectModel, url: URL? = nil) -> NSPersistentContainer {
        let result = NSPersistentContainer(name: "cheatsheet", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        if let url { description.url = url } else { description.type = NSInMemoryStoreType }
        description.shouldAddStoreAsynchronously = false
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        result.persistentStoreDescriptions = [description]
        result.loadPersistentStores { _, error in precondition(error == nil, "\(String(describing: error))") }
        return result
    }

    @MainActor static func checkPinsAndBackup(_ model: NSManagedObjectModel) throws {
        let data = container(model)
        let store = CabinetStore(context: data.viewContext)
        let a = try store.createTag("标签 A"), b = try store.createTag("标签 B")
        let first = try store.save(nil, title: "A", body: "needle-a", tags: [a, b])
        let last = try store.save(nil, title: "Z", body: "needle-z", tags: [a, b])
        let middle = try store.save(nil, title: "M", body: "needle-m", tags: [a, b])
        first.order = 0; last.order = 1; middle.order = 2
        first.updatedAt = Date(timeIntervalSince1970: 3)
        last.updatedAt = Date(timeIntervalSince1970: 2)
        middle.updatedAt = Date(timeIntervalSince1970: 1)
        last.isFavorite = true
        try data.viewContext.save()
        let timestamps = [first, last, middle].map(\.updatedAt)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let vm = CabinetViewModel(context: data.viewContext, pasteboard: board)
        func ids() -> [NSManagedObjectID] { vm.items.map(\.id) }
        for sort in ["标题", "最近修改", "手动顺序"] {
            vm.sort = sort
            vm.navigate(.tag(b.objectID)); vm.reload()
            let baseline = ids()
            vm.navigate(.tag(a.objectID))
            precondition(vm.togglePin(last) && vm.togglePin(middle))
            let pinned = sort == "标题" ? [middle, last] : [last, middle]
            precondition(ids() == (pinned + [first]).map(\.objectID), "Pin partitions must retain each selected sort")
            vm.navigate(.tag(b.objectID))
            precondition(ids() == baseline && !vm.isPinnedInCurrentTag(last))
            vm.navigate(.all)
            precondition(ids() == baseline && vm.pinningTag(for: last) == nil && !vm.togglePin(last))
            vm.navigate(.favorites)
            precondition(ids() == [last.objectID] && !vm.isPinnedInCurrentTag(last))
            vm.navigate(.tag(a.objectID)); vm.search("needle-a")
            precondition(ids() == [first.objectID], "Pins must not bypass search")
            vm.search("")
            precondition(vm.togglePin(last) && vm.togglePin(middle))
            precondition(ids() == baseline)
        }
        precondition([first, last, middle].map(\.updatedAt) == timestamps)
        precondition([first, last, middle].map(\.order) == [0, 1, 2] && last.isFavorite && !a.isPinned)
        for _ in 0..<10 { precondition(vm.togglePin(last)) }
        precondition(!last.isPinned(in: a))
        try store.setPinned(true, command: last, tag: a)
        try store.setPinned(true, command: middle, tag: b)
        try store.rename(a, to: "标签 A 改名")
        precondition(last.isPinned(in: a))
        try store.trash(a)
        precondition(!last.isPinned(in: a))
        _ = try store.save(last, title: "Z", body: "编辑时保留隐藏标签", tags: [b])
        precondition((last.pinnedTags as? Set<cheatsheet.Category>)?.contains(a) == true)
        try store.restore(a)
        precondition(last.isPinned(in: a), "Editing while a tag is trashed must retain restoration evidence")
        try store.trash(last); precondition(!last.isPinned(in: a))
        try store.restore(last); precondition(last.isPinned(in: a))
        _ = try store.save(last, title: "Z", body: "取消标签关联", tags: [b])
        precondition((last.pinnedTags as? Set<cheatsheet.Category>)?.contains(a) == false)
        _ = try store.save(last, title: "Z", body: "重新添加标签", tags: [a, b])
        precondition(!last.isPinned(in: a))
        try store.setPinned(true, command: last, tag: a)
        // 同值排序在刷新和重复筛选后保持一致。
        for command in [first, last, middle] { command.name = "同名"; command.order = 0; command.updatedAt = timestamps[0] }
        try data.viewContext.save()
        vm.sort = "标题"; vm.reload()
        let tied = ids()
        for _ in 0..<10 { vm.reload(); precondition(ids() == tied) }
        let archive = try BackupService(context: data.viewContext).makeArchive()
        precondition(archive.version == 3)
        let encoded = try JSONEncoder().encode(archive)
        let decoded = try JSONDecoder().decode(BackupArchive.self, from: encoded)
        let restored = container(model)
        let existingSameName = try CabinetStore(context: restored.viewContext).createTag(a.name!)
        _ = try BackupService(context: restored.viewContext).importArchive(decoded)
        let imported = try restored.viewContext.fetch(Command.fetchRequest())
        let importedLast = imported.first { $0.content == last.content }!
        let importedMiddle = imported.first { $0.content == middle.content }!
        let importedA = importedLast.activeTags.first { $0.name!.hasPrefix("标签 A 改名") }!
        let importedB = importedLast.activeTags.first { $0.name == b.name }!
        precondition(importedA != existingSameName && importedA.id != a.id)
        precondition(importedLast.isPinned(in: importedA) && !importedLast.isPinned(in: importedB))
        precondition(importedMiddle.isPinned(in: importedB) && !importedMiddle.isPinned(in: importedA))
        // 旧 JSON 缺少新字段时应正常读取且全部未置顶。
        var json = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        json["version"] = 2
        json["commands"] = (json["commands"] as! [[String: Any]]).map { value in
            var record = value; record.removeValue(forKey: "pinnedTagIDs"); return record
        }
        let oldArchive = try JSONDecoder().decode(BackupArchive.self, from: JSONSerialization.data(withJSONObject: json))
        let oldRestore = container(model)
        _ = try BackupService(context: oldRestore.viewContext).importArchive(oldArchive)
        let oldCommands = try oldRestore.viewContext.fetch(Command.fetchRequest())
        precondition(oldCommands.allSatisfy { ($0.pinnedTags?.count ?? 0) == 0 })
        // 外来置顶 ID 不能生成不存在的标签或关联到未加入的标签。
        let foreign = UUID()
        var malformed = decoded
        malformed.commands = malformed.commands?.map { value in
            var record = value; record.tagIDs = []; record.pinnedTagIDs = [a.id!, foreign]; return record
        }
        let malformedRestore = container(model)
        _ = try BackupService(context: malformedRestore.viewContext).importArchive(malformed)
        let malformedCommands = try malformedRestore.viewContext.fetch(Command.fetchRequest())
        precondition(malformedCommands.allSatisfy { ($0.pinnedTags?.count ?? 0) == 0 })
        print("PASS: per-tag pins, three stable sorts, search, global/favorite isolation, ten toggles, rename, trash/restore, unlink/re-add and v3/v2 backup identity remapping")
    }

    @MainActor static func checkFailures(_ model: NSManagedObjectModel) throws {
        let data = container(model)
        let context = PinFailureContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = data.persistentStoreCoordinator
        let store = CabinetStore(context: context)
        let a = try store.createTag("A"), b = try store.createTag("B")
        let command = try store.save(nil, title: "失败保护", body: "原文", tags: [a, b])
        let other = try store.save(nil, title: "其他草稿", body: "未涉及", tags: [])
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let vm = CabinetViewModel(context: context, pasteboard: board)
        vm.navigate(.tag(a.objectID))
        let timestamp = command.updatedAt
        other.content = "其他待保存修改"
        context.reject = true
        precondition(!vm.togglePin(command) && !command.isPinned(in: a) && vm.error != nil)
        precondition(command.updatedAt == timestamp && other.content == "其他待保存修改")
        context.reject = false
        precondition(vm.togglePin(command) && command.isPinned(in: a))
        context.reject = true
        precondition(!vm.togglePin(command) && command.isPinned(in: a))
        do {
            _ = try store.save(command, title: "变化", body: "失败的正文", tags: [b])
            preconditionFailure("Expected save rejection")
        } catch { }
        precondition(command.isPinned(in: a) && command.content == "原文" && command.activeTags.contains(a))
        context.reject = false
        try context.save()
        let sibling = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        sibling.persistentStoreCoordinator = data.persistentStoreCoordinator
        let loaded = try sibling.existingObject(with: command.objectID) as! Command
        let loadedTag = try sibling.existingObject(with: a.objectID) as! cheatsheet.Category
        precondition(loaded.isPinned(in: loadedTag))
        print("PASS: pin/unpin and tag-removal save failures restore only affected fields; persisted pin survives retry")
    }

    @MainActor static func checkV2Migration(_ modelURL: URL) throws {
        let oldModel = NSManagedObjectModel(contentsOf: modelURL.appendingPathComponent("cheatsheetV2.mom"))!
        oldModel.entities.forEach { $0.managedObjectClassName = "NSManagedObject" }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("cabinet-v3-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("migration.sqlite")
        let old = container(oldModel, url: url)
        let tag = NSEntityDescription.insertNewObject(forEntityName: "Category", into: old.viewContext)
        let command = NSEntityDescription.insertNewObject(forEntityName: "Command", into: old.viewContext)
        let commandID = UUID(), tagID = UUID(), date = Date(timeIntervalSince1970: 12345)
        tag.setValuesForKeys(["id": tagID, "name": "v2 标签", "createdAt": date, "updatedAt": date, "isPinned": true])
        command.setValuesForKeys(["id": commandID, "name": "v2 正文", "content": "中文与表情 🙂", "createdAt": date,
            "updatedAt": date, "isFavorite": true, "order": Int32(9), "tagsMigrated": true,
            "tags": NSSet(object: tag), "imageData": Data([1, 2, 3])])
        try old.viewContext.save()
        old.viewContext.reset()
        try old.persistentStoreCoordinator.remove(old.persistentStoreCoordinator.persistentStores[0])
        let current = NSManagedObjectModel(contentsOf: modelURL)!
        let upgraded = container(current, url: url)
        let record = try upgraded.viewContext.fetch(Command.fetchRequest())[0]
        let currentTag = try upgraded.viewContext.fetch(Category.fetchRequest())[0]
        precondition(record.id == commandID && currentTag.id == tagID && record.content == "中文与表情 🙂")
        precondition(record.activeTags == [currentTag] && record.imageData == Data([1, 2, 3]))
        precondition(record.updatedAt == date && record.order == 9 && record.isFavorite && currentTag.isPinned)
        precondition(record.pinnedTags?.count ?? 0 == 0)
        try CabinetStore(context: upgraded.viewContext).setPinned(true, command: record, tag: currentTag)
        upgraded.viewContext.reset()
        try upgraded.persistentStoreCoordinator.remove(upgraded.persistentStoreCoordinator.persistentStores[0])
        let reopened = container(current, url: url)
        let persisted = try reopened.viewContext.fetch(Command.fetchRequest())[0]
        let persistedTag = try reopened.viewContext.fetch(Category.fetchRequest())[0]
        precondition(persisted.isPinned(in: persistedTag) && persisted.id == commandID && persisted.updatedAt == date)
        print("PASS: real v2 SQLite upgrades without losing IDs, tags, image, favorite or timestamps; pin survives disk close/reopen")
        print("Isolated migration evidence: \(directory.path)")
    }
}

final class PinFailureContext: NSManagedObjectContext, @unchecked Sendable {
    var reject = false
    override func save() throws {
        if reject { throw NSError(domain: "CabinetPinChecks", code: 1, userInfo: [NSLocalizedDescriptionKey: "模拟磁盘写入失败"]) }
        try super.save()
    }
}
