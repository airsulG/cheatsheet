import AppKit
import CoreData
import SwiftUI
import Combine
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
        precondition(CabinetContent.title(" \r\n\t\u{2028}  第一行 👩🏽‍💻  \n后续正文") == "第一行 👩🏽‍💻")
        precondition(CabinetContent.title(" \n\t", image: true) == "图片")
        precondition(CabinetContent.title(" \n\t") == "未命名片段")
        precondition(vm.rowPreview(for: .snippet(command)).title == command.displayTitle)
        vm.search("末尾关键字")
        precondition(vm.items.count == 1)
        precondition(vm.rowPreview(for: .snippet(command)).excerpt.contains("末尾关键字"))
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
        vm.navigate(.all)
        vm.search("")
        let scrollBefore = vm.selectionScrollRequest
        if let last = vm.items.last { vm.select(last.id) }
        precondition(vm.selectionScrollRequest == scrollBefore, "Mouse selection must not request scrolling")
        vm.moveSelection(-1)
        precondition(vm.selectionScrollRequest == scrollBefore + 1, "Keyboard selection should remain visible")
        _ = NSApplication.shared
        checkReader(itemID: command.objectID, otherID: untagged.objectID)
        let searchWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 80),
                                    styleMask: [.titled], backing: .buffered, defer: false)
        let field = NSTextField(frame: NSRect(x: 20, y: 25, width: 320, height: 25))
        let searchDelegate = CabinetSearchField.Coordinator(model: vm)
        field.delegate = searchDelegate
        searchWindow.contentView?.addSubview(field)
        searchWindow.makeKeyAndOrderFront(nil)
        precondition(searchWindow.makeFirstResponder(field))
        let fieldEditor = field.currentEditor() as! NSTextView
        fieldEditor.setMarkedText("sheji", selectedRange: NSRange(location: 5, length: 0),
                                  replacementRange: NSRange(location: NSNotFound, length: 0))
        searchDelegate.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
        precondition(fieldEditor.hasMarkedText() && vm.query.isEmpty,
                     "Uncommitted IME text must not be used as a search query")
        precondition(!searchDelegate.control(field, textView: fieldEditor,
            doCommandBy: #selector(NSResponder.insertNewline(_:))), "IME Return must commit text, not copy")
        fieldEditor.insertText("设计", replacementRange: NSRange(location: NSNotFound, length: 0))
        searchDelegate.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
        precondition(!fieldEditor.hasMarkedText() && vm.query == "设计", "Committed Chinese should become the search query")
        searchWindow.orderOut(nil)
        print("PASS: mouse selection does not scroll; keyboard selection requests visibility; IME composition waits for Chinese commit")
        let savedIcon = NSImage(size: NSSize(width: 22, height: 22))
        savedIcon.lockFocus()
        NSColor.green.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 22, height: 22)).fill()
        savedIcon.unlockFocus()
        let savedIconData = savedIcon.tiffRepresentation!
        precondition(CabinetSourceIcon.image(data: savedIconData, bundleID: "missing.app") != nil)
        precondition(CabinetSourceIcon.image(data: Data([0, 1]), bundleID: "com.apple.finder") != nil)
        precondition(CabinetSourceIcon.image(data: nil, bundleID: "missing.app") == nil)
        print("PASS: clipboard source icon uses saved data, falls back to installed app, and tolerates missing apps")
        try await checkRefresh(container: container(model))
        try checkGridInteraction(container: container(model))
        try await checkSaveToast(container: container(model))
        let failureContext = RejectingSaveContext(concurrencyType: .mainQueueConcurrencyType)
        failureContext.persistentStoreCoordinator = container(model).persistentStoreCoordinator
        let failureStore = CabinetStore(context: failureContext)
        let intact = try failureStore.save(nil, title: "原标题", body: "磁盘写入失败前的正文", tags: [])
        let failingVM = CabinetViewModel(context: failureContext, pasteboard: named)
        failingVM.draft?.body = "必须留在草稿中的修改"
        failureContext.rejectSave = true
        precondition(!failingVM.autosave() && failingVM.dirty && failingVM.draft?.body == "必须留在草稿中的修改")
        precondition(intact.content == "磁盘写入失败前的正文", "A failed save must restore the managed object's prior fields")
        failureContext.rejectSave = false
        precondition(failingVM.autosave() && intact.content == "必须留在草稿中的修改")
        print("PASS: simulated disk save failure preserves draft, restores the record and supports retry")
        try await checkEditableText(model: failingVM)
        vm.search("")
        vm.select(image.objectID)
        vm.draft?.body = "自动保存后重启仍保留"
        precondition(vm.allowLeaving())
        let savedImageID = image.id
        context.reset()
        try upgraded.persistentStoreCoordinator.remove(upgraded.persistentStoreCoordinator.persistentStores[0])
        let reopened = container(model, url: url)
        let persisted = try reopened.viewContext.fetch(Command.fetchRequest())
        precondition(persisted.count == 4 && persisted.contains { $0.id == savedImageID && $0.imageData == imageData && $0.content == "自动保存后重启仍保留" })
        print("PASS: disk store closes and reopens with image and multi-tag assets intact")
        print("Isolated evidence store: \(directory.path)")
    }

    @MainActor static func checkEditableText(model: CabinetViewModel) async throws {
        let host = NSHostingView(rootView: CabinetEditor(model: model, palette: CabinetPalette(dark: true)))
        host.frame = NSRect(x: 0, y: 0, width: 500, height: 540)
        host.layoutSubtreeIfNeeded()
        @MainActor func find(_ root: NSView) -> CabinetEditableTextView? {
            if let text = root as? CabinetEditableTextView { return text }
            return root.subviews.lazy.compactMap { find($0) }.first
        }
        let view = find(host)!
        let coordinator = view.delegate as! CabinetTextEditor.Coordinator
        let original = model.draft!.body
        view.setSelectedRange(NSRange(location: (view.string as NSString).length, length: 0))
        view.setMarkedText("sheji", selectedRange: NSRange(location: 5, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: view))
        precondition(view.hasMarkedText() && model.draft?.body == original, "Uncommitted composition must not overwrite the draft")
        view.insertText("设计", replacementRange: NSRange(location: NSNotFound, length: 0))
        coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: view))
        precondition(!view.hasMarkedText() && model.draft?.body == original + "设计")
        _ = view.resignFirstResponder()
        precondition(!model.dirty && model.saveStatus == "已保存" && model.selected?.body == original + "设计")
        print("PASS: native editor excludes marked IME text, commits Chinese and saves through its real blur callback")
    }

    @MainActor static func checkSaveToast(container: NSPersistentContainer) async throws {
        let store = CabinetStore(context: container.viewContext)
        let record = try store.save(nil, title: "反馈验证", body: "保存前", tags: [])
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let vm = CabinetViewModel(context: container.viewContext, pasteboard: board)
        var messages: [String] = []
        let observation = vm.$toastMessage.compactMap { $0 }.sink { messages.append($0) }
        defer { observation.cancel() }
        vm.openDetail(record.objectID)
        precondition(vm.autosave() && vm.toastMessage == nil)
        vm.draft?.body = "自动保存完成"
        precondition(vm.autosave() && vm.toastMessage == "已保存" && messages == ["已保存"])
        precondition(vm.autosave() && messages.count == 1, "No-op blur must not restart a success toast")
        precondition(vm.closeDetail() && vm.toastMessage == "已保存", "Closing the panel must retain save feedback in the grid")
        vm.openDetail(record.objectID)
        vm.draft?.body = "复制前也要保存"
        vm.copy(close: false)
        precondition(vm.toastMessage == "已复制到剪贴板" && board.string(forType: .string) == record.content)
        precondition(messages.suffix(2) == ["已保存", "已复制到剪贴板"], "Latest copy feedback supersedes save feedback")
        vm.draft?.body = ""
        precondition(!vm.autosave() && vm.toastMessage == nil && vm.dirty,
                     "A failed save must clear old success feedback and retain the draft")
        vm.draft?.body = "失败后重试成功"
        precondition(vm.autosave() && vm.toastMessage == "已保存")
        let deadline = Date().addingTimeInterval(3)
        while vm.toastMessage != nil && Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
        precondition(vm.toastMessage == nil && vm.copiedItemID == nil && vm.feedback.isEmpty,
                     "Success feedback must dismiss automatically")
        precondition(vm.autosave() && vm.toastMessage == nil)
        vm.newSnippet()
        precondition(vm.autosave() && vm.toastMessage == nil, "An empty new draft must not claim it was saved")
        print("PASS: save toast, no-op/blank suppression, panel-close persistence, latest-copy precedence, failure clearing and timed dismissal")
    }

    @MainActor static func checkGridInteraction(container: NSPersistentContainer) throws {
        let store = CabinetStore(context: container.viewContext)
        let first = try store.save(nil, title: "卡片 A", body: "第一张的完整正文", tags: [])
        let second = try store.save(nil, title: "卡片 B", body: "第二张的完整正文", tags: [])
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let vm = CabinetViewModel(context: container.viewContext, pasteboard: board)
        precondition(!vm.isDetailPresented, "Initial browsing must not mount an editor")
        precondition(vm.openDetail(first.objectID) && vm.isDetailPresented)
        vm.draft?.body = "收起前保存的中文 👩🏽‍💻"
        precondition(vm.closeDetail() && !vm.isDetailPresented && first.content == "收起前保存的中文 👩🏽‍💻")
        vm.openDetail(first.objectID)
        vm.draft?.body = ""
        precondition(!vm.closeDetail() && vm.isDetailPresented && vm.dirty, "Failed save must keep the panel open")
        vm.draft?.body = "修正后保存"
        vm.search("卡片")
        precondition(!vm.isDetailPresented && first.content == "修正后保存")
        vm.openDetail(first.objectID)
        vm.navigate(.favorites)
        precondition(!vm.isDetailPresented)
        vm.navigate(.all)
        vm.search("")

        let clicks = CabinetCardInteraction(model: vm)
        func mouse(_ type: NSEvent.EventType, _ count: Int, _ time: TimeInterval, x: CGFloat = 800) -> NSEvent {
            NSEvent.mouseEvent(with: type, location: NSPoint(x: x, y: 400), modifierFlags: [], timestamp: time,
                              windowNumber: 0, context: nil, eventNumber: 0, clickCount: count, pressure: 1)!
        }
        clicks.activate(first.objectID, event: mouse(.leftMouseUp, 1, 1))
        precondition(vm.isDetailPresented, "Single click must open immediately without a double-click timer")
        precondition(clicks.handle(mouse(.leftMouseDown, 2, 1 + NSEvent.doubleClickInterval / 2)))
        precondition(board.string(forType: .string) == first.content && !vm.isDetailPresented,
                     "Second click over the new panel must copy the original card and return to the grid")
        precondition(clicks.handle(mouse(.leftMouseUp, 2, 1 + NSEvent.doubleClickInterval / 2)))
        vm.openDetail(first.objectID)
        clicks.activate(second.objectID, event: mouse(.leftMouseUp, 1, 3))
        precondition(clicks.handle(mouse(.leftMouseDown, 2, 3 + NSEvent.doubleClickInterval / 2)))
        precondition(board.string(forType: .string) == second.content && vm.isDetailPresented,
                     "Copying another visible card must preserve an already open panel")
        _ = clicks.handle(mouse(.leftMouseUp, 2, 3 + NSEvent.doubleClickInterval / 2))
        clicks.activate(first.objectID, event: mouse(.leftMouseUp, 1, 5))
        precondition(!clicks.handle(mouse(.leftMouseDown, 2, 5 + NSEvent.doubleClickInterval / 2, x: 100)))
        precondition(!clicks.handle(mouse(.leftMouseDown, 2, 6 + NSEvent.doubleClickInterval)))
        vm.openDetail(first.objectID)
        vm.draft?.body = "再次点击当前卡片也要保存"
        clicks.activate(first.objectID, event: mouse(.leftMouseUp, 1, 8))
        precondition(!vm.isDetailPresented && first.content == "再次点击当前卡片也要保存",
                     "A later click on the current card must save and close")
        precondition(clicks.handle(mouse(.leftMouseDown, 2, 8 + NSEvent.doubleClickInterval / 2)))
        precondition(board.string(forType: .string) == first.content && !vm.isDetailPresented,
                     "Double-clicking the current card must still copy after the first click closes it")
        _ = clicks.handle(mouse(.leftMouseUp, 2, 8 + NSEvent.doubleClickInterval / 2))
        vm.openDetail(first.objectID)
        vm.draft?.body = ""
        clicks.activate(first.objectID, event: mouse(.leftMouseUp, 1, 10))
        precondition(vm.isDetailPresented && vm.dirty, "Toggle must retain a draft that cannot be saved")
        vm.draft?.body = "切换其他卡片前保存"
        clicks.activate(second.objectID, event: mouse(.leftMouseUp, 1, 12))
        precondition(vm.isDetailPresented && vm.selection == second.objectID && first.content == "切换其他卡片前保存")
        vm.newSnippet()
        precondition(vm.isDetailPresented && vm.draft?.commandID == nil)
        vm.escape()
        precondition(!vm.isDetailPresented && vm.snippetCount == 2)
        print("PASS: grid default, immediate drawer open, repeat-click toggle with save/failure protection, other-card switch, navigation/search dismissal, double-click source routing, pointer/time boundaries and blank-new dismissal")
    }

    @MainActor static func checkReader(itemID: NSManagedObjectID, otherID: NSManagedObjectID) {
        let text = "中文与 👩🏽‍💻 Café\r\n\n" + String(repeating: "长文跨行选择和宽度变化后仍应保留完整正文。\n", count: 240) + "末尾关键字"
        let reader = CabinetReaderScrollView()
        reader.frame = NSRect(x: 0, y: 0, width: 600, height: 360)
        reader.update(itemID: itemID, text: text, query: "末尾关键字", dark: true, header: AnyView(Text("元信息")))
        reader.layoutSubtreeIfNeeded()
        let view = reader.content.textView
        precondition(view.frame.minY > CabinetGrid.detailInset + 20, "Header height and spacing must be reserved above the body")
        precondition(view.string == text && !view.isEditable && view.isSelectable)
        precondition(reader.content.matches.count == 1)
        let match = reader.content.matches[0]
        precondition((text as NSString).substring(with: match) == "末尾关键字")
        precondition(view.textStorage?.attribute(.backgroundColor, at: match.location, effectiveRange: nil) != nil)
        precondition(reader.contentView.bounds.minY > 0, "A tail match must scroll into view")
        let glyphs = view.layoutManager!.glyphRange(forCharacterRange: match, actualCharacterRange: nil)
        let rect = view.layoutManager!.boundingRect(forGlyphRange: glyphs, in: view.textContainer!)
        precondition(reader.contentView.bounds.intersects(reader.content.convert(rect, from: view)), "Matched text must be visible")
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        view.setSelectedRange(NSRange(location: 0, length: (text as NSString).length))
        let textType = view.writablePasteboardTypes[0]
        precondition(view.writeSelection(to: pasteboard, types: [textType]))
        precondition(pasteboard.string(forType: textType) == text, "Cross-line copy must preserve original Unicode and newlines")
        let selected = view.selectedRange()
        let scrollPosition = reader.contentView.bounds.origin
        reader.update(itemID: itemID, text: text, query: "末尾关键字", dark: false, header: AnyView(Text("元信息")))
        reader.layoutSubtreeIfNeeded()
        precondition(view.selectedRange() == selected && reader.contentView.bounds.origin == scrollPosition,
                     "Unrelated updates and appearance changes must preserve selection and reading position")
        let wideHeight = view.frame.height
        reader.frame.size.width = 250
        reader.needsLayout = true
        reader.layoutSubtreeIfNeeded()
        precondition(view.frame.height > wideHeight, "Narrow columns must wrap and expand the document")
        reader.update(itemID: otherID, text: "短文", query: "", dark: true, header: AnyView(EmptyView()))
        reader.layoutSubtreeIfNeeded()
        precondition(view.string == "短文" && view.selectedRange().length == 0 && reader.contentView.bounds.minY == 0)
        precondition(reader.content.matches.isEmpty)
        let unicodeMatches = CabinetReaderDocument.matchRanges(in: "👩🏽‍💻 Café\r\nCAFE", query: "cafe")
        precondition(unicodeMatches.count == 2)
        precondition(("👩🏽‍💻 Café\r\nCAFE" as NSString).substring(with: unicodeMatches[0]) == "Café")
        print("PASS: continuous reader preserves cross-line Unicode copy, tail-match highlight and visibility, reading position, wrapping and item reset")
    }

    @MainActor static func checkRefresh(container: NSPersistentContainer) async throws {
        @MainActor func waitFor(_ condition: () -> Bool) async throws {
            for _ in 0..<100 {
                if condition() { return }
                try await Task.sleep(for: .milliseconds(20))
            }
            precondition(condition(), "Timed out waiting for Core Data merge and coalesced UI refresh")
        }
        let context = container.viewContext
        let store = CabinetStore(context: context)
        let a = try store.createTag("标签 A")
        let b = try store.createTag("标签 B")
        let original = try store.save(nil, title: "", body: "原始首行\n正文", tags: [a])
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let vm = CabinetViewModel(context: context, pasteboard: board)
        var catalogUpdates = 0
        let subscription = vm.$tags.dropFirst().sink { _ in catalogUpdates += 1 }
        vm.navigate(.tag(a.objectID))
        vm.search("正文")
        vm.navigate(.tag(b.objectID))
        precondition(vm.items.isEmpty)
        vm.navigate(.tag(a.objectID))
        precondition(vm.query == "正文" && vm.selection == original.objectID)
        precondition(catalogUpdates == 0, "Filtering and navigation must not reload the catalog")
        withExtendedLifetime(subscription) {}
        vm.search("")
        precondition(vm.rowPreview(for: .snippet(original)).title == "原始首行")
        _ = try store.save(original, title: "", body: "更新后的首行\n新正文", tags: [b])
        original.isFavorite = true
        try context.save()
        try await waitFor { vm.items.isEmpty && vm.tagCounts[b.objectID] == 1 }
        precondition(vm.items.isEmpty && vm.tagCounts[a.objectID] == nil && vm.tagCounts[b.objectID] == 1)
        precondition(vm.favoriteCount == 1 && vm.rowPreview(for: .snippet(original)).title == "更新后的首行")
        vm.navigate(.tag(b.objectID))
        precondition(vm.items.count == 1)
        try store.trash(original)
        try await waitFor { vm.items.isEmpty && vm.snippetCount == 0 }
        precondition(vm.items.isEmpty && vm.snippetCount == 0 && vm.favoriteCount == 0)
        try store.restore(original)
        try await waitFor { vm.items.count == 1 && vm.snippetCount == 1 }
        precondition(vm.items.count == 1 && vm.snippetCount == 1)
        try store.trash(b)
        try await waitFor { vm.location == .all && vm.tags.count == 1 }
        precondition(vm.location == .all && vm.tags.count == 1 && vm.snippetCount == 1)
        try store.restore(b)
        try await waitFor { vm.tagCounts[b.objectID] == 1 }
        precondition(vm.tagCounts[b.objectID] == 1)
        let tagID = a.objectID
        let worker = container.newBackgroundContext()
        try worker.performAndWait {
            let target = try worker.existingObject(with: tagID) as! cheatsheet.Category
            _ = try CabinetStore(context: worker).save(nil, title: "", body: "后台新增片段", tags: [target])
        }
        try await waitFor { vm.snippetCount == 2 }
        vm.navigate(.tag(a.objectID))
        precondition(vm.items.count == 1 && vm.items[0].body == "后台新增片段" && vm.snippetCount == 2)
        let editingID = vm.selection!
        precondition(vm.draft?.commandID == editingID && !vm.dirty, "Selected snippets must be editable immediately")
        let firstSession = vm.editorSession
        vm.search("后台新增")
        vm.draft?.body = "已自动保存的中文 👩🏽‍💻\n第二行"
        precondition(vm.autosave() && !vm.dirty && vm.saveStatus == "已保存")
        precondition(vm.query == "后台新增" && vm.selection == editingID && vm.draft?.commandID == editingID,
                     "Saving a draft that no longer matches must preserve the current editor and query")
        let edited = try context.existingObject(with: editingID) as! Command
        precondition(edited.content == "已自动保存的中文 👩🏽‍💻\n第二行")
        let savedAt = edited.updatedAt
        precondition(vm.autosave() && edited.updatedAt == savedAt, "Repeated blur without changes must not write")
        vm.draft?.body = ""
        precondition(!vm.navigate(.all) && vm.selection == editingID && vm.dirty && vm.draft?.body == "",
                     "Failed validation must preserve text and prevent navigation")
        precondition(edited.content == "已自动保存的中文 👩🏽‍💻\n第二行")
        vm.draft?.body = "离开前自动保存"
        precondition(vm.navigate(.all) && edited.content == "离开前自动保存")
        vm.select(original.objectID)
        vm.draft?.body = "旧事件不能保存这里"
        precondition(vm.autosave(session: firstSession) && vm.dirty && original.content != "旧事件不能保存这里")
        precondition(vm.select(editingID) && original.content == "旧事件不能保存这里")
        vm.navigate(.clipboard)
        precondition(vm.draft == nil, "Clipboard source must remain read-only")
        vm.navigate(.all)
        let beforeBlank = vm.snippetCount
        vm.newSnippet()
        precondition(vm.navigate(.tag(a.objectID)) && vm.snippetCount == beforeBlank, "Blank drafts must not create records")
        print("PASS: direct editing, Unicode autosave, filtered selection retention, no-op blur, save failure recovery, stale-session isolation and blank/history protection")
        vm.newSnippet()
        vm.draft?.body = "正在编辑"
        precondition(vm.navigate(.tag(a.objectID)) && vm.draft?.body == "正在编辑",
                     "Clicking the current tag must keep the draft")
        print("PASS: cached navigation preserves selection/query without catalog refresh; edit, retag, trash, restore and background insert refresh results and counts")
    }
}

private final class RejectingSaveContext: NSManagedObjectContext, @unchecked Sendable {
    var rejectSave = false
    override func save() throws {
        if rejectSave { throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError) }
        try super.save()
    }
}
