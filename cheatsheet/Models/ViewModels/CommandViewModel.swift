//
//  CommandViewModel.swift
//  cheatsheet
//
//  Created by 周麒 on 2025/6/9.
//

import Foundation
import CoreData
import SwiftUI

enum ShelfCardSortMode: String, CaseIterable, Identifiable {
    case manual
    case title

    var id: String { rawValue }

    var label: String {
        switch self {
        case .manual: return "手动排序"
        case .title: return "按标题排序"
        }
    }

    var systemImage: String {
        switch self {
        case .manual: return "hand.draw"
        case .title: return "textformat.abc"
        }
    }
}

enum ShelfCardSortSettings {
    static let storageKey = "shelf_card_sort_mode"
    static let defaultMode: ShelfCardSortMode = .title

    static var mode: ShelfCardSortMode {
        get {
            let raw = UserDefaults.standard.string(forKey: storageKey) ?? defaultMode.rawValue
            return ShelfCardSortMode(rawValue: raw) ?? defaultMode
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
        }
    }
}

enum CommandTitleSorter {
    private static let chineseDigitOrder: [Character: Int] = [
        "零": 0,
        "一": 1,
        "二": 2,
        "三": 3,
        "四": 4,
        "五": 5,
        "六": 6,
        "七": 7,
        "八": 8,
        "九": 9,
        "十": 10
    ]

    static func sorted(_ commands: [Command]) -> [Command] {
        commands.sorted { lhs, rhs in
            let result = compare(lhs.name, rhs.name)
            if result == .orderedSame {
                return (lhs.createdAt ?? .distantPast) < (rhs.createdAt ?? .distantPast)
            }
            return result == .orderedAscending
        }
    }

    static func compare(_ lhs: String?, _ rhs: String?) -> ComparisonResult {
        let left = Array((lhs ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
        let right = Array((rhs ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
        var leftIndex = 0
        var rightIndex = 0

        while leftIndex < left.count && rightIndex < right.count {
            let leftChar = left[leftIndex]
            let rightChar = right[rightIndex]

            if let leftNumber = numberToken(in: left, start: leftIndex),
               let rightNumber = numberToken(in: right, start: rightIndex) {
                if leftNumber.value != rightNumber.value {
                    return leftNumber.value < rightNumber.value ? .orderedAscending : .orderedDescending
                }
                leftIndex = leftNumber.endIndex
                rightIndex = rightNumber.endIndex
                continue
            }

            if let leftOrder = chineseDigitOrder[leftChar],
               let rightOrder = chineseDigitOrder[rightChar],
               leftOrder != rightOrder {
                return leftOrder < rightOrder ? .orderedAscending : .orderedDescending
            }

            let leftString = String(leftChar).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            let rightString = String(rightChar).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            let result = leftString.localizedStandardCompare(rightString)
            if result != .orderedSame {
                return result
            }

            leftIndex += 1
            rightIndex += 1
        }

        if left.count == right.count { return .orderedSame }
        return left.count < right.count ? .orderedAscending : .orderedDescending
    }

    private static func numberToken(in characters: [Character], start: Int) -> (value: Int, endIndex: Int)? {
        var index = start
        var digits = ""

        while index < characters.count, characters[index].isNumber {
            digits.append(characters[index])
            index += 1
        }

        guard !digits.isEmpty, let value = Int(digits) else { return nil }
        return (value, index)
    }
}

@MainActor
class CommandViewModel: ObservableObject {
    
    private let viewContext: NSManagedObjectContext
    
    @Published var commands: [Command] = []
    @Published var selectedCommand: Command?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastCopiedCommand: Command?
    @Published var showCopyToast = false
    var sortModeProvider: () -> ShelfCardSortMode = { .manual }
    
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
                self.commands = arrangedCommands(fetchedCommands)
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
              currentCategory != nil else { return }
        
        // 更新本地数组
        commands.move(fromOffsets: IndexSet(integer: sourceIndex), toOffset: destinationIndex)
        
        // 更新数据库中的顺序
        updateCommandOrders()
        
        saveContext()
    }

    func swapCommandPositions(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              commands.indices.contains(sourceIndex),
              commands.indices.contains(destinationIndex),
              currentCategory != nil else { return }

        commands.swapAt(sourceIndex, destinationIndex)
        updateCommandOrders()
        saveContext()
    }
    
    private func updateCommandOrders() {
        for (index, command) in commands.enumerated() {
            command.order = Int32(index)
            command.updateTimestamp()
        }
    }

    private func arrangedCommands(_ fetchedCommands: [Command]) -> [Command] {
        if sortModeProvider() == .title {
            let sorted = CommandTitleSorter.sorted(fetchedCommands)
            persistCommandOrderIfNeeded(sorted)
            return sorted
        }

        // 收藏置左：先按 isFavorite 降序，其次按 order 升序，保持稳定顺序
        return fetchedCommands.sorted { lhs, rhs in
            if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite && !rhs.isFavorite }
            return lhs.order < rhs.order
        }
    }

    private func persistCommandOrderIfNeeded(_ sortedCommands: [Command]) {
        var changed = false
        for (index, command) in sortedCommands.enumerated() where command.order != Int32(index) {
            command.order = Int32(index)
            command.updateTimestamp()
            changed = true
        }

        if changed {
            saveContext()
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
