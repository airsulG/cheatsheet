//
//  DragDropTests.swift
//  cheatsheetTests
//
//  Created by 周麒 on 2025/6/9.
//

import XCTest
import CoreData
@testable import cheatsheet

final class DragDropTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var categoryViewModel: CategoryViewModel!
    var commandViewModel: CommandViewModel!
    
    override func setUpWithError() throws {
        persistenceController = PersistenceController.preview
        context = persistenceController.container.viewContext
        categoryViewModel = CategoryViewModel(context: context)
        commandViewModel = CommandViewModel(context: context)
    }
    
    override func tearDownWithError() throws {
        // 清理测试数据
        let categoryRequest: NSFetchRequest<NSFetchRequestResult> = Category.fetchRequest()
        let categoryDeleteRequest = NSBatchDeleteRequest(fetchRequest: categoryRequest)
        try context.execute(categoryDeleteRequest)
        
        let commandRequest: NSFetchRequest<NSFetchRequestResult> = Command.fetchRequest()
        let commandDeleteRequest = NSBatchDeleteRequest(fetchRequest: commandRequest)
        try context.execute(commandDeleteRequest)
        
        try context.save()
        
        persistenceController = nil
        context = nil
        categoryViewModel = nil
        commandViewModel = nil
    }
    
    // MARK: - 分类拖拽排序测试
    
    func testCategoryDragAndDrop() throws {
        // 创建测试分类
        let category1 = Category(context: context, name: "分类1")
        category1.order = 0
        
        let category2 = Category(context: context, name: "分类2")
        category2.order = 1
        
        let category3 = Category(context: context, name: "分类3")
        category3.order = 2
        
        try context.save()
        categoryViewModel.fetchCategories()
        
        // 验证初始顺序
        XCTAssertEqual(categoryViewModel.categories.count, 3)
        XCTAssertEqual(categoryViewModel.categories[0].name, "分类1")
        XCTAssertEqual(categoryViewModel.categories[1].name, "分类2")
        XCTAssertEqual(categoryViewModel.categories[2].name, "分类3")
        
        // 测试拖拽：将第一个分类移动到最后
        categoryViewModel.moveCategory(from: 0, to: 2)
        
        // 验证拖拽后的顺序
        categoryViewModel.fetchCategories()
        XCTAssertEqual(categoryViewModel.categories[0].name, "分类2")
        XCTAssertEqual(categoryViewModel.categories[1].name, "分类3")
        XCTAssertEqual(categoryViewModel.categories[2].name, "分类1")
        
        // 验证 order 字段正确更新
        XCTAssertEqual(categoryViewModel.categories[0].order, 0)
        XCTAssertEqual(categoryViewModel.categories[1].order, 1)
        XCTAssertEqual(categoryViewModel.categories[2].order, 2)
    }
    
    func testCategoryDragAndDropWithPinnedCategories() throws {
        // 创建测试分类（包含固定分类）
        let pinnedCategory = Category(context: context, name: "固定分类")
        pinnedCategory.order = 0
        pinnedCategory.isPinned = true
        
        let category1 = Category(context: context, name: "普通分类1")
        category1.order = 0
        category1.isPinned = false
        
        let category2 = Category(context: context, name: "普通分类2")
        category2.order = 1
        category2.isPinned = false
        
        try context.save()
        categoryViewModel.fetchCategories()
        
        // 验证初始状态
        XCTAssertEqual(categoryViewModel.pinnedCategories.count, 1)
        XCTAssertEqual(categoryViewModel.unpinnedCategories.count, 2)
        
        // 测试在普通分类间拖拽（应该成功）
        let initialUnpinnedCount = categoryViewModel.unpinnedCategories.count
        categoryViewModel.moveCategory(from: 1, to: 2) // 在普通分类间移动
        
        categoryViewModel.fetchCategories()
        XCTAssertEqual(categoryViewModel.unpinnedCategories.count, initialUnpinnedCount)
        
        // 验证固定分类不受影响
        XCTAssertEqual(categoryViewModel.pinnedCategories.count, 1)
        XCTAssertEqual(categoryViewModel.pinnedCategories[0].name, "固定分类")
    }
    
    // MARK: - 命令拖拽排序测试
    
    func testCommandDragAndDrop() throws {
        // 创建测试分类和命令
        let category = Category(context: context, name: "测试分类")
        
        let command1 = Command(context: context, name: "命令1", content: "echo 1", category: category)
        command1.order = 0
        
        let command2 = Command(context: context, name: "命令2", content: "echo 2", category: category)
        command2.order = 1
        
        let command3 = Command(context: context, name: "命令3", content: "echo 3", category: category)
        command3.order = 2
        
        try context.save()
        commandViewModel.fetchCommands(for: category)
        
        // 验证初始顺序
        XCTAssertEqual(commandViewModel.commands.count, 3)
        XCTAssertEqual(commandViewModel.commands[0].name, "命令1")
        XCTAssertEqual(commandViewModel.commands[1].name, "命令2")
        XCTAssertEqual(commandViewModel.commands[2].name, "命令3")
        
        // 测试拖拽：将第一个命令移动到最后
        commandViewModel.moveCommand(from: 0, to: 2)
        
        // 验证拖拽后的顺序
        commandViewModel.fetchCommands(for: category)
        XCTAssertEqual(commandViewModel.commands[0].name, "命令2")
        XCTAssertEqual(commandViewModel.commands[1].name, "命令3")
        XCTAssertEqual(commandViewModel.commands[2].name, "命令1")
        
        // 验证 order 字段正确更新
        XCTAssertEqual(commandViewModel.commands[0].order, 0)
        XCTAssertEqual(commandViewModel.commands[1].order, 1)
        XCTAssertEqual(commandViewModel.commands[2].order, 2)
    }
    
    func testCommandDragAndDropPersistence() throws {
        // 创建测试分类和命令
        let category = Category(context: context, name: "测试分类")
        
        let command1 = Command(context: context, name: "命令A", content: "echo A", category: category)
        command1.order = 0
        
        let command2 = Command(context: context, name: "命令B", content: "echo B", category: category)
        command2.order = 1
        
        try context.save()
        commandViewModel.fetchCommands(for: category)
        
        // 执行拖拽操作
        commandViewModel.moveCommand(from: 0, to: 1)
        
        // 重新创建 ViewModel 来测试持久化
        let newCommandViewModel = CommandViewModel(context: context)
        newCommandViewModel.fetchCommands(for: category)
        
        // 验证顺序在重新加载后仍然正确
        XCTAssertEqual(newCommandViewModel.commands.count, 2)
        XCTAssertEqual(newCommandViewModel.commands[0].name, "命令B")
        XCTAssertEqual(newCommandViewModel.commands[1].name, "命令A")
    }
    
    // MARK: - 边界条件测试
    
    func testInvalidDragAndDropOperations() throws {
        // 创建测试分类
        let category1 = Category(context: context, name: "分类1")
        category1.order = 0
        
        let category2 = Category(context: context, name: "分类2")
        category2.order = 1
        
        try context.save()
        categoryViewModel.fetchCategories()
        
        let initialOrder = categoryViewModel.categories.map { $0.name }
        
        // 测试无效的拖拽操作
        categoryViewModel.moveCategory(from: 0, to: 0) // 相同位置
        categoryViewModel.moveCategory(from: -1, to: 1) // 无效源索引
        categoryViewModel.moveCategory(from: 0, to: 10) // 无效目标索引
        
        // 验证顺序没有改变
        categoryViewModel.fetchCategories()
        let finalOrder = categoryViewModel.categories.map { $0.name }
        XCTAssertEqual(initialOrder, finalOrder)
    }
}
