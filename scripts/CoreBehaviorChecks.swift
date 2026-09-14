import AppKit
import CoreData
import Combine
@testable import cheatsheet

@main
struct RegressionChecks {
    @MainActor
    static func main() async throws {
        let modelURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let model = NSManagedObjectModel(contentsOf: modelURL)!
        let container = NSPersistentContainer(name: "cheatsheet", managedObjectModel: model)
        let store = NSPersistentStoreDescription()
        store.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [store]
        container.loadPersistentStores { _, error in precondition(error == nil, "In-memory store failed") }
        let context = container.viewContext
        context.automaticallyMergesChangesFromParent = true
        let category = Category(context: context, name: "验证分类")
        for (index, name) in ["四", "二", "三", "一"].enumerated() {
            let command = Command(context: context, name: name, content: "正文内容", category: category)
            command.order = Int32(index)
        }
        try context.save()
        let vm = CommandViewModel(context: context)
        vm.fetchCommands(for: category)
        vm.swapCommandPositions(from: 3, to: 0)
        vm.fetchCommands(for: category)
        precondition(vm.commands.map { $0.name! } == ["一", "二", "三", "四"], "Swap must only exchange endpoints")
        vm.swapCommandPositions(from: -1, to: 20)
        precondition(vm.commands.count == 4)
        vm.sortModeProvider = { .title }
        vm.fetchCommands(for: category)
        precondition(vm.commands.map { $0.order } == [0, 1, 2, 3])
        let titles = ["三", "十", "一", "二", "九"]
        precondition(titles.sorted { CommandTitleSorter.compare($0, $1) == .orderedAscending } == ["一", "二", "三", "九", "十"])
        precondition(CommandTitleSorter.compare("步骤2", "步骤10") == .orderedAscending)
        let sibling = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        sibling.persistentStoreCoordinator = container.persistentStoreCoordinator
        let request = Command.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
        let readback = try sibling.fetch(request)
        precondition(readback.map { $0.name! } == ["一", "二", "三", "四"])
        print("PASS: swap, invalid indices, title order, numeric order and persisted readback")

        if CommandLine.arguments.contains("--sorting-only") { return }
        let shelf = ShelfViewModel(context: context)
        shelf.selectCategory(category)
        let longBody = String(repeating: "长正文", count: 1000) + "末尾匹配"
        shelf.commandVM.createCommand(name: "ChatGPT 标题", content: longBody, category: category)
        for query in ["chatgpt", "标题", "末尾匹配", "  标题  "] {
            shelf.searchText = query
            precondition(shelf.filteredCommands.count == 1, "Title/full body search failed")
        }
        shelf.searchText = "不存在"
        precondition(shelf.filteredCommands.isEmpty)
        shelf.searchText = " "
        precondition(shelf.filteredCommands.count == 5)
        var notifications = 0
        let subscription = shelf.objectWillChange.sink { notifications += 1 }
        shelf.commandVM.createCommand(name: "实时刷新", content: "保存后出现", category: category)
        try await Task.sleep(for: .milliseconds(100))
        precondition(notifications > 0, "Child updates must reach Shelf")
        precondition(shelf.commandVM.commands.contains { $0.name == "实时刷新" })
        withExtendedLifetime(subscription) {}
        print("PASS: title, full body tail, case, trim, no match, empty query and child observation")

        let backup = try BackupService(context: context).makeArchive()
        precondition(backup.categories.count == 1 && backup.categories[0].commands.count == 6)
        let restore = NSPersistentContainer(name: "cheatsheet", managedObjectModel: model)
        let restoreStore = NSPersistentStoreDescription()
        restoreStore.type = NSInMemoryStoreType
        restore.persistentStoreDescriptions = [restoreStore]
        restore.loadPersistentStores { _, error in precondition(error == nil) }
        let imported = try BackupService(context: restore.viewContext).importArchive(backup)
        precondition(imported.categoryCount == 1 && imported.commandCount == 6)
        let restoredArchive = try BackupService(context: restore.viewContext).makeArchive()
        precondition(restoredArchive.commands?.contains { $0.content == longBody } == true)
        print("PASS: backup/archive import round-trip in isolated memory stores")

        _ = NSApplication.shared
        let panel = ShelfPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 80), styleMask: [.nonactivatingPanel, .fullSizeContentView], backing: .buffered, defer: false)
        panel.becomesKeyOnlyIfNeeded = true
        precondition(panel.canBecomeKey && !panel.canBecomeMain)
        let field = NSTextField(frame: NSRect(x: 10, y: 10, width: 280, height: 24))
        panel.contentView = field
        panel.orderFrontRegardless()
        panel.makeKey()
        precondition(panel.isKeyWindow && panel.makeFirstResponder(field))
        let editor = field.currentEditor() as! NSTextView
        editor.insertText("搜索正文", replacementRange: NSRange(location: NSNotFound, length: 0))
        precondition(editor.string == "搜索正文")
        panel.orderOut(nil)
        print("PASS: borderless panel key status and field editor text input")

        let fixtureURL = URL(fileURLWithPath: CommandLine.arguments[2])
        let fixtures = try JSONDecoder().decode([ImportCommand].self, from: Data(contentsOf: fixtureURL))
        precondition(!fixtures.isEmpty)
        let importCategory = Category(context: context, name: "导入示例验证")
        for fixture in fixtures {
            shelf.commandVM.createCommand(name: fixture.name, content: fixture.prompt, category: importCategory)
            precondition(shelf.commandVM.errorMessage == nil)
        }
        shelf.commandVM.fetchCommands(for: importCategory)
        precondition(shelf.commandVM.commands.count == fixtures.count)
        for fixture in fixtures {
            precondition(shelf.commandVM.commands.contains { $0.name == fixture.name && $0.content == fixture.prompt })
        }
        print("PASS: JSON import contract, command creation and full-content readback")
    }
}
