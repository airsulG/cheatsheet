//
//  ShelfViewModel.swift
//  cheatsheet
//
//  Created by Codex on 2025/8/28.
//

import Foundation
import CoreData
import SwiftUI

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
        // 合并更改并刷新
        viewContext.perform { [weak self] in
            guard let self = self else { return }
            self.viewContext.mergeChanges(fromContextDidSave: noti)
            self.categoryVM.fetchCategories()
            // 剪贴板：仅刷新第一页，避免加载过多
            self.pagedClipboardVM.resetAndLoadFirstPage()
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
            DispatchQueue.main.async { self.favorites = result }
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
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            // 可以扩展为抛出或记录日志，这里静默以免打断 UI
            print("Save context (ShelfViewModel) failed: \(error)")
        }
    }
}
