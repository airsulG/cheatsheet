//
//  CategoryManagementTests.swift
//  cheatsheetTests
//
//  Created by 周麒 on 2025/6/9.
//

import XCTest
import CoreData
@testable import cheatsheet

final class CategoryManagementTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var categoryViewModel: CategoryViewModel!
    
    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        categoryViewModel = CategoryViewModel(context: context)
    }
    
    override func tearDownWithError() throws {
        persistenceController = nil
        context = nil
        categoryViewModel = nil
    }
    
    // MARK: - AC1: 创建分类测试
    
    func testCreateCategory() throws {
        // 测试创建分类
        categoryViewModel.createCategory(name: "Docker")
        
        XCTAssertEqual(categoryViewModel.categories.count, 1)
        XCTAssertEqual(categoryViewModel.categories.first?.name, "Docker")
        XCTAssertEqual(categoryViewModel.categories.first?.order, 0)
        XCTAssertFalse(categoryViewModel.categories.first?.isPinned ?? true)
        XCTAssertNil(categoryViewModel.errorMessage)
    }
    
    func testCreateMultipleCategories() throws {
        // 测试创建多个分类
        categoryViewModel.createCategory(name: "Docker")
        categoryViewModel.createCategory(name: "Git")
        categoryViewModel.createCategory(name: "OpenSSL")
        
        XCTAssertEqual(categoryViewModel.categories.count, 3)
        
        // 验证顺序
        let sortedCategories = categoryViewModel.categories.sorted { $0.order < $1.order }
        XCTAssertEqual(sortedCategories[0].name, "Docker")
        XCTAssertEqual(sortedCategories[1].name, "Git")
        XCTAssertEqual(sortedCategories[2].name, "OpenSSL")
        
        // 验证 order 字段
        XCTAssertEqual(sortedCategories[0].order, 0)
        XCTAssertEqual(sortedCategories[1].order, 1)
        XCTAssertEqual(sortedCategories[2].order, 2)
    }
    
    func testCreateCategoryWithEmptyName() throws {
        // 测试创建空名称分类
        categoryViewModel.createCategory(name: "")
        
        XCTAssertEqual(categoryViewModel.categories.count, 0)
        XCTAssertNotNil(categoryViewModel.errorMessage)
        XCTAssertEqual(categoryViewModel.errorMessage, "分类名称不能为空")
    }
    
    func testCreateCategoryWithWhitespaceOnlyName() throws {
        // 测试创建只有空格的分类名称
        categoryViewModel.createCategory(name: "   ")
        
        XCTAssertEqual(categoryViewModel.categories.count, 0)
        XCTAssertNotNil(categoryViewModel.errorMessage)
        XCTAssertEqual(categoryViewModel.errorMessage, "分类名称不能为空")
    }
    
    // MARK: - AC2: 删除分类测试
    
    func testDeleteCategory() throws {
        // 创建分类
        categoryViewModel.createCategory(name: "待删除分类")
        XCTAssertEqual(categoryViewModel.categories.count, 1)
        
        let category = categoryViewModel.categories.first!
        
        // 删除分类
        categoryViewModel.deleteCategory(category)
        
        XCTAssertEqual(categoryViewModel.categories.count, 0)
        XCTAssertNil(categoryViewModel.errorMessage)
    }
    
    func testDeleteCategoryWithCommands() throws {
        // 创建分类和命令
        let category = Category(context: context, name: "有命令的分类")
        let command1 = Command(context: context, name: "命令1", content: "cmd1", category: category)
        let command2 = Command(context: context, name: "命令2", content: "cmd2", category: category)
        
        try context.save()
        categoryViewModel.fetchCategories()
        
        XCTAssertEqual(categoryViewModel.categories.count, 1)
        XCTAssertEqual(category.commandCount, 2)
        
        // 删除分类（应该级联删除命令）
        categoryViewModel.deleteCategory(category)
        
        XCTAssertEqual(categoryViewModel.categories.count, 0)
        
        // 验证命令也被删除了
        let commandFetch: NSFetchRequest<Command> = Command.fetchRequest()
        let commands = try context.fetch(commandFetch)
        XCTAssertEqual(commands.count, 0)
    }
    
    func testDeleteSelectedCategory() throws {
        // 创建并选择分类
        categoryViewModel.createCategory(name: "选中的分类")
        let category = categoryViewModel.categories.first!
        categoryViewModel.selectCategory(category)
        
        XCTAssertEqual(categoryViewModel.selectedCategory, category)
        
        // 删除选中的分类
        categoryViewModel.deleteCategory(category)
        
        XCTAssertEqual(categoryViewModel.categories.count, 0)
        XCTAssertNil(categoryViewModel.selectedCategory)
    }
    
    // MARK: - AC3: 重命名分类测试
    
    func testUpdateCategoryName() throws {
        // 创建分类
        categoryViewModel.createCategory(name: "原始名称")
        let category = categoryViewModel.categories.first!
        
        // 重命名分类
        categoryViewModel.updateCategory(category, name: "新名称")
        
        XCTAssertEqual(category.name, "新名称")
        XCTAssertNil(categoryViewModel.errorMessage)
        
        // 验证时间戳更新
        XCTAssertNotNil(category.updatedAt)
    }
    
    func testUpdateCategoryWithEmptyName() throws {
        // 创建分类
        categoryViewModel.createCategory(name: "原始名称")
        let category = categoryViewModel.categories.first!
        let originalName = category.name
        
        // 尝试用空名称重命名
        categoryViewModel.updateCategory(category, name: "")
        
        XCTAssertEqual(category.name, originalName) // 名称不应该改变
        XCTAssertNotNil(categoryViewModel.errorMessage)
        XCTAssertEqual(categoryViewModel.errorMessage, "分类名称不能为空")
    }
    
    func testUpdateCategoryWithWhitespaceOnlyName() throws {
        // 创建分类
        categoryViewModel.createCategory(name: "原始名称")
        let category = categoryViewModel.categories.first!
        let originalName = category.name
        
        // 尝试用只有空格的名称重命名
        categoryViewModel.updateCategory(category, name: "   ")
        
        XCTAssertEqual(category.name, originalName) // 名称不应该改变
        XCTAssertNotNil(categoryViewModel.errorMessage)
        XCTAssertEqual(categoryViewModel.errorMessage, "分类名称不能为空")
    }
    
    // MARK: - 固定分类测试
    
    func testTogglePinCategory() throws {
        // 创建分类
        categoryViewModel.createCategory(name: "测试分类")
        let category = categoryViewModel.categories.first!
        
        XCTAssertFalse(category.isPinned)
        
        // 固定分类
        categoryViewModel.togglePinCategory(category)
        
        XCTAssertTrue(category.isPinned)
        
        // 取消固定
        categoryViewModel.togglePinCategory(category)
        
        XCTAssertFalse(category.isPinned)
    }
    
    func testPinnedCategoriesOrder() throws {
        // 创建多个分类
        categoryViewModel.createCategory(name: "分类1")
        categoryViewModel.createCategory(name: "分类2")
        categoryViewModel.createCategory(name: "分类3")
        
        let category1 = categoryViewModel.categories[0]
        let category2 = categoryViewModel.categories[1]
        
        // 固定分类2和分类1
        categoryViewModel.togglePinCategory(category2)
        categoryViewModel.togglePinCategory(category1)
        
        // 验证固定分类在顶部
        let pinnedCategories = categoryViewModel.pinnedCategories
        let unpinnedCategories = categoryViewModel.unpinnedCategories
        
        XCTAssertEqual(pinnedCategories.count, 2)
        XCTAssertEqual(unpinnedCategories.count, 1)
        XCTAssertTrue(pinnedCategories.contains(category1))
        XCTAssertTrue(pinnedCategories.contains(category2))
    }
}
