//
//  ShelfViewModel.swift
//  cheatsheet
//
//  Created by Codex on 2025/8/28.
//

import Foundation
import CoreData
import SwiftUI

@MainActor
final class ShelfViewModel: ObservableObject {
    let viewContext: NSManagedObjectContext

    // 子 VM 复用现有逻辑
    @Published var categoryVM: CategoryViewModel
    @Published var commandVM: CommandViewModel
    @Published var pagedClipboardVM: PagedClipboardViewModel
    @Published var favorites: [Command] = []

    // UI 状态
    @Published var selectedCategory: Category?
    @Published var searchText: String = ""
    @Published var showCopyToast = false

    init(context: NSManagedObjectContext) {
        self.viewContext = context
        self.categoryVM = CategoryViewModel(context: context)
        self.commandVM = CommandViewModel(context: context)
        self.pagedClipboardVM = PagedClipboardViewModel(context: context)
        self.commandVM.sortModeProvider = { ShelfCardSortSettings.mode }
        // 初次加载收藏
        fetchFavorites()

        // 默认选择第一个分类（若存在）
        self.selectedCategory = categoryVM.categories.first
        if let cat = selectedCategory {
            commandVM.fetchCommands(for: cat)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(contextDidSave(_:)), name: .NSManagedObjectContextDidSave, object: nil)
    }

    @objc private func contextDidSave(_ noti: Notification) {
        // 该 selector 是被 NotificationCenter 在「发布 save 的那个线程」上同步派发的：
        // ClipboardMonitor 与 BackupService 用的是 newBackgroundContext()，所以这里很可能在
        // 后台私有队列。viewContext 是 mainQueueConcurrencyType，跨线程动它（mergeChanges /
        // fetch / 写 @Published）会和 viewContext.automaticallyMergesChangesFromParent 在主
        // 队列触发的自动合并撞拍，破坏 CoreData 内部跟踪集，最终在
        // _postRefreshedObjectsNotificationAndClearList 路径上 setObject:forKey: nil → SIGABRT。
        //
        // 修法：
        // 1) 不再手动 mergeChanges：Persistence 已开启 automaticallyMergesChangesFromParent。
        // 2) 自我反馈防护：忽略 viewContext 自身的 save。
        // 3) userInfo 里的 NSManagedObject 跨线程只允许做类指针判断（is ClipboardItem），不读属性。
        // 4) 所有 viewContext 访问与 @Published 写入回到主队列。
        // 5) 剪贴板列表的增量更新由 PagedClipboardViewModel 自己监听 contextDidSave 处理（task 13），
        //    这里只负责 Category / Command / Favorites 分支。
        guard let saved = noti.object as? NSManagedObjectContext, saved !== viewContext else { return }

        let userInfo = noti.userInfo
        let inserted = (userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject>) ?? []
        let updated  = (userInfo?[NSUpdatedObjectsKey]  as? Set<NSManagedObject>) ?? []
        let deleted  = (userInfo?[NSDeletedObjectsKey]  as? Set<NSManagedObject>) ?? []
        let allObjects = inserted.union(updated).union(deleted)
        let hasNonClipboardChanges = allObjects.contains { !($0 is ClipboardItem) }

        // 完全是剪贴板变更时不用走 ShelfViewModel 这条刷新链；分类 / 命令 / 收藏没变。
        guard hasNonClipboardChanges else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.categoryVM.fetchCategories()
            self.fetchFavorites()
            if let cat = self.selectedCategory {
                self.commandVM.fetchCommands(for: cat)
            }
        }
    }

    func selectCategory(_ category: Category) {
        selectedCategory = category
        commandVM.fetchCommands(for: category)
    }
    
    func clearSelection() {
        selectedCategory = nil
        categoryVM.clearSelection()
    }

    // 搜索过滤后的命令
    var filteredCommands: [Command] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return commandVM.commands }
        return commandVM.commands.filter { cmd in
            (cmd.name ?? "").localizedCaseInsensitiveContains(q) ||
            (cmd.content ?? "").localizedCaseInsensitiveContains(q)
        }
    }

    // 复制提示
    func showToast() {
        showCopyToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.showCopyToast = false
        }
    }

    // MARK: - Favorites
    func fetchFavorites() {
        let request: NSFetchRequest<Command> = Command.fetchRequest()
        request.predicate = NSPredicate(format: "isFavorite == YES")
        request.sortDescriptors = [
            NSSortDescriptor(key: "favoriteOrder", ascending: true),
            NSSortDescriptor(keyPath: \Command.updatedAt, ascending: false)
        ]
        do {
            let result = try viewContext.fetch(request)
            let arranged = arrangedFavorites(result)
            DispatchQueue.main.async { self.favorites = arranged }
        } catch {
            // 静默失败，避免打断 UI
        }
    }

    // MARK: - Favorites Operations

    func toggleFavorite(_ command: Command) {
        if command.isFavorite {
            // 取消收藏：置空 favoriteOrder，并收紧其余顺序
            command.setFavorite(false)
            command.setValue(nil, forKey: "favoriteOrder")
            saveAndCompactFavorites()
        } else {
            // 添加收藏：插入到末尾（最大 favoriteOrder + 1）
            let next = (favorites.compactMap { ($0.value(forKey: "favoriteOrder") as? Int32).map(Int.init) }.max() ?? (favorites.count - 1)) + 1
            command.setFavorite(true)
            command.setValue(Int32(next), forKey: "favoriteOrder")
            saveContext()
            fetchFavorites()
        }

        // 刷新当前分类命令列表，使“收藏置左”立即生效
        if let cat = selectedCategory {
            commandVM.fetchCommands(for: cat)
        }
    }

    func moveFavorite(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              sourceIndex < favorites.count,
              destinationIndex <= favorites.count else { return }
        favorites.move(fromOffsets: IndexSet(integer: sourceIndex), toOffset: destinationIndex)
        // 重新写入顺序
        for (idx, cmd) in favorites.enumerated() {
            cmd.setValue(Int32(idx), forKey: "favoriteOrder")
            cmd.updateTimestamp()
        }
        saveContext()
        fetchFavorites()
    }

    func swapFavoritePositions(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              favorites.indices.contains(sourceIndex),
              favorites.indices.contains(destinationIndex) else { return }

        favorites.swapAt(sourceIndex, destinationIndex)
        for (idx, cmd) in favorites.enumerated() {
            cmd.setValue(Int32(idx), forKey: "favoriteOrder")
            cmd.updateTimestamp()
        }
        saveContext()
        fetchFavorites()
    }

    func applyShelfSortMode() {
        if let cat = selectedCategory {
            commandVM.fetchCommands(for: cat)
        }
        fetchFavorites()
    }

    private func saveAndCompactFavorites() {
        // 重新抓取并按当前 favorites 顺序紧凑写入
        fetchFavorites()
        for (idx, cmd) in favorites.enumerated() {
            cmd.setValue(Int32(idx), forKey: "favoriteOrder")
            cmd.updateTimestamp()
        }
        saveContext()
        fetchFavorites()
    }

    // MARK: - Helpers
    private func arrangedFavorites(_ fetchedFavorites: [Command]) -> [Command] {
        if ShelfCardSortSettings.mode == .title {
            let sorted = CommandTitleSorter.sorted(fetchedFavorites)
            persistFavoriteOrderIfNeeded(sorted)
            return sorted
        }

        return fetchedFavorites
    }

    private func persistFavoriteOrderIfNeeded(_ sortedFavorites: [Command]) {
        var changed = false
        for (index, command) in sortedFavorites.enumerated() {
            let currentOrder = command.value(forKey: "favoriteOrder") as? Int32
            if currentOrder != Int32(index) {
                command.setValue(Int32(index), forKey: "favoriteOrder")
                command.updateTimestamp()
                changed = true
            }
        }

        if changed {
            saveContext()
        }
    }

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            // 可以扩展为抛出或记录日志，这里静默以免打断 UI
            print("Save context (ShelfViewModel) failed: \(error)")
        }
    }
}
