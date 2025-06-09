//
//  CategoryViewModel.swift
//  cheatsheet
//
//  Created by 周麒 on 2025/6/9.
//

import Foundation
import CoreData
import SwiftUI

class CategoryViewModel: ObservableObject {
    
    private let viewContext: NSManagedObjectContext
    
    @Published var categories: [Category] = []
    @Published var selectedCategory: Category?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
        fetchCategories()
    }
    
    // MARK: - Fetch Operations
    
    func fetchCategories() {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }

        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Category.isPinned, ascending: false),
            NSSortDescriptor(keyPath: \Category.order, ascending: true)
        ]

        do {
            let fetchedCategories = try viewContext.fetch(request)
            DispatchQueue.main.async {
                self.categories = fetchedCategories
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "获取分类失败: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    // MARK: - CRUD Operations
    
    func createCategory(name: String) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "分类名称不能为空"
            return
        }
        
        let newCategory = Category(context: viewContext, name: name)
        newCategory.order = Int32(categories.count)
        
        saveContext()
        fetchCategories()
    }
    
    func updateCategory(_ category: Category, name: String) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "分类名称不能为空"
            return
        }
        
        category.name = name
        category.updateTimestamp()
        
        saveContext()
        fetchCategories()
    }
    
    func deleteCategory(_ category: Category) {
        viewContext.delete(category)
        
        // 重新排序剩余分类
        reorderCategories()
        
        saveContext()
        fetchCategories()
        
        // 如果删除的是当前选中的分类，清除选择
        if selectedCategory == category {
            selectedCategory = nil
        }
    }
    
    func togglePinCategory(_ category: Category) {
        category.isPinned.toggle()
        category.updateTimestamp()
        
        // 重新排序分类
        reorderCategories()
        
        saveContext()
        fetchCategories()
    }
    
    // MARK: - Drag & Drop Operations
    
    func moveCategory(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              sourceIndex < categories.count,
              destinationIndex < categories.count else { return }
        
        let sourceCategory = categories[sourceIndex]
        let destinationCategory = categories[destinationIndex]
        
        // 不允许将固定分类拖拽到非固定区域，反之亦然
        if sourceCategory.isPinned != destinationCategory.isPinned {
            return
        }
        
        // 更新本地数组
        categories.move(fromOffsets: IndexSet(integer: sourceIndex), toOffset: destinationIndex)
        
        // 更新数据库中的顺序
        updateCategoryOrders()
        
        saveContext()
    }
    
    private func updateCategoryOrders() {
        for (index, category) in categories.enumerated() {
            category.order = Int32(index)
            category.updateTimestamp()
        }
    }
    
    private func reorderCategories() {
        let pinnedCategories = categories.filter { $0.isPinned }.sorted { $0.order < $1.order }
        let unpinnedCategories = categories.filter { !$0.isPinned }.sorted { $0.order < $1.order }
        
        // 重新分配顺序
        for (index, category) in pinnedCategories.enumerated() {
            category.order = Int32(index)
        }
        
        for (index, category) in unpinnedCategories.enumerated() {
            category.order = Int32(index)
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
    
    func selectCategory(_ category: Category) {
        selectedCategory = category
    }
    
    func clearSelection() {
        selectedCategory = nil
    }
    
    // MARK: - Computed Properties
    
    var pinnedCategories: [Category] {
        categories.filter { $0.isPinned }
    }
    
    var unpinnedCategories: [Category] {
        categories.filter { !$0.isPinned }
    }
}
