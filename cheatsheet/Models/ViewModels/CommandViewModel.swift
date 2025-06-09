//
//  CommandViewModel.swift
//  cheatsheet
//
//  Created by 周麒 on 2025/6/9.
//

import Foundation
import CoreData
import SwiftUI

class CommandViewModel: ObservableObject {
    
    private let viewContext: NSManagedObjectContext
    
    @Published var commands: [Command] = []
    @Published var selectedCommand: Command?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastCopiedCommand: Command?
    @Published var showCopyToast = false
    
    private var currentCategory: Category?
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
    }
    
    // MARK: - Fetch Operations
    
    func fetchCommands(for category: Category?) {
        currentCategory = category

        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }

        guard let category = category else {
            DispatchQueue.main.async {
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
            DispatchQueue.main.async {
                self.commands = fetchedCommands
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
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
    
    private func saveContext() {
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
