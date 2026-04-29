//
//  CommandViewModel.swift
//  cheatsheet
//
//  Created by 周麒 on 2025/6/9.
//

import Foundation
import CoreData
import SwiftUI

@MainActor
class CommandViewModel: ObservableObject {
    
    private let viewContext: NSManagedObjectContext
    
    @Published var commands: [Command] = []
    @Published var selectedCommand: Command?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastCopiedCommand: Command?
    @Published var showCopyToast = false
    
    private var currentCategory: Category?
    // 防乱序令牌：仅允许最新一次拉取写入结果
    private var fetchGeneration: Int = 0
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
    }
    
    // MARK: - Fetch Operations
    
    func fetchCommands(for category: Category?) {
        // 生成本次请求的令牌
        fetchGeneration += 1
        let gen = fetchGeneration

        // 更新当前分类与加载状态
        currentCategory = category
        isLoading = true
        errorMessage = nil

        // 空分类：清空结果，仅当仍为最新请求时提交
        guard let category = category else {
            if gen == fetchGeneration {
                self.commands = []
                self.isLoading = false
            }
            return
        }

        let request: NSFetchRequest<Command> = Command.fetchRequest()
        request.predicate = NSPredicate(format: "category == %@", category)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Command.order, ascending: true)]

        do {
            let fetchedCommands = try viewContext.fetch(request)
            // 仅当此次请求仍为最新时写入结果
            if gen == fetchGeneration {
                // 收藏置左：先按 isFavorite 降序，其次按 order 升序，保持稳定顺序
                let favFirst = fetchedCommands.sorted { lhs, rhs in
                    if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite && !rhs.isFavorite }
                    return lhs.order < rhs.order
                }
                self.commands = favFirst
                self.isLoading = false
            }
        } catch {
            if gen == fetchGeneration {
                self.errorMessage = "获取命令失败: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    // MARK: - CRUD Operations
    
    func createCommand(name: String, content: String, category: Category) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "命令名称不能为空"
            return
        }
        
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "命令内容不能为空"
            return
        }
        
        let newCommand = Command(context: viewContext, name: name, content: content, category: category)
        newCommand.order = Int32(category.commandCount)
        
        saveContext()
        fetchCommands(for: category)
    }
    
    func updateCommand(_ command: Command, name: String, content: String) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "命令名称不能为空"
            return
        }
        
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "命令内容不能为空"
            return
        }
        
        command.updateContent(name: name, content: content)
        
        saveContext()
        fetchCommands(for: currentCategory)
    }
    
    func deleteCommand(_ command: Command) {
        let category = command.category
        viewContext.delete(command)
        
        // 重新排序剩余命令
        if let category = category {
            category.reorderCommands()
        }
        
        saveContext()
        fetchCommands(for: currentCategory)
        
        // 如果删除的是当前选中的命令，清除选择
        if selectedCommand == command {
            selectedCommand = nil
        }
    }
    
    // MARK: - Move Command to Another Category
    
    /// 将命令移动到另一个分类
    func moveCommand(_ command: Command, to targetCategory: Category) {
        // 保存原分类，用于重新排序
        let sourceCategory = command.category
        
        // 移动命令到目标分类
        command.category = targetCategory
        command.order = Int32(targetCategory.commandCount)
        command.updateTimestamp()
        
        // 重新排序原分类的命令
        if let sourceCategory = sourceCategory {
            sourceCategory.reorderCommands()
        }
        
        saveContext()
        
        // 刷新当前显示的分类
        fetchCommands(for: currentCategory)
    }
    
    // MARK: - Clipboard Operations
    
    func copyCommand(_ command: Command) {
        let success = ClipboardManager.shared.copy(command.content ?? "")
        
        if success {
            lastCopiedCommand = command
            showCopyToast = true
            
            // 3秒后隐藏提示
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.showCopyToast = false
            }
        } else {
            errorMessage = "复制到剪贴板失败"
        }
    }
    
    // MARK: - Drag & Drop Operations
    
    func moveCommand(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              sourceIndex < commands.count,
              destinationIndex < commands.count,
              let category = currentCategory else { return }
        
        // 更新本地数组
        commands.move(fromOffsets: IndexSet(integer: sourceIndex), toOffset: destinationIndex)
        
        // 更新数据库中的顺序
        updateCommandOrders()
        
        saveContext()
    }
    
    private func updateCommandOrders() {
        for (index, command) in commands.enumerated() {
            command.order = Int32(index)
            command.updateTimestamp()
        }
    }
    
    // MARK: - Helper Methods
    
    func saveContext() {
        do {
            try viewContext.save()
            errorMessage = nil
        } catch {
            errorMessage = "保存失败: \(error.localizedDescription)"
        }
    }
    
    func selectCommand(_ command: Command) {
        selectedCommand = command
    }
    
    func clearSelection() {
        selectedCommand = nil
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Computed Properties
    
    var hasCommands: Bool {
        !commands.isEmpty
    }
    
    var commandCount: Int {
        commands.count
    }
}
