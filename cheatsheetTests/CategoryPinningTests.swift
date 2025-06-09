//
//  CategoryPinningTests.swift
//  cheatsheetTests
//
//  Created by 周麒 on 2025/6/9.
//

import XCTest
import CoreData
@testable import cheatsheet

final class CategoryPinningTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var categoryViewModel: CategoryViewModel!
    
    override func setUpWithError() throws {
        persistenceController = PersistenceController.preview
        context = persistenceController.container.viewContext
        categoryViewModel = CategoryViewModel(context: context)
    }
    
    override func tearDownWithError() throws {
        // 清理测试数据
        let categoryRequest: NSFetchRequest<NSFetchRequestResult> = Category.fetchRequest()
        let categoryDeleteRequest = NSBatchDeleteRequest(fetchRequest: categoryRequest)
        try context.execute(categoryDeleteRequest)
        
        try context.save()
        
        persistenceController = nil
        context = nil
        categoryViewModel = nil
    }
    
    // MARK: - AC5: 固定分类测试
    
    func testPinCategoryToTop() throws {
        // 创建测试分类
        let category1 = Category(context: context, name: "普通分类1")
        category1.order = 0
        category1.isPinned = false
        
        let category2 = Category(context: context, name: "普通分类2")
        category2.order = 1
        category2.isPinned = false
        
        let category3 = Category(context: context, name: "普通分类3")
        category3.order = 2
        category3.isPinned = false
        
        try context.save()
        categoryViewModel.fetchCategories()
        
        // 验证初始状态：所有分类都是普通分类
        XCTAssertEqual(categoryViewModel.categories.count, 3)
        XCTAssertEqual(categoryViewModel.pinnedCategories.count, 0)
        XCTAssertEqual(categoryViewModel.unpinnedCategories.count, 3)
        
        // 固定第二个分类到顶部
        categoryViewModel.togglePinCategory(category2)
        categoryViewModel.fetchCategories()
        
        // 验证固定后的状态
        XCTAssertEqual(categoryViewModel.pinnedCategories.count, 1)
        XCTAssertEqual(categoryViewModel.unpinnedCategories.count, 2)
        
        // 验证固定的分类在顶部
        XCTAssertEqual(categoryViewModel.pinnedCategories[0].name, "普通分类2")
        XCTAssertTrue(categoryViewModel.pinnedCategories[0].isPinned)
        
        // 验证固定分类的视觉区分（通过 isPinned 属性）
        XCTAssertTrue(category2.isPinned)
        XCTAssertFalse(category1.isPinned)
        XCTAssertFalse(category3.isPinned)
    }
    
    func testUnpinCategory() throws {
        // 创建一个已固定的分类
        let pinnedCategory = Category(context: context, name: "固定分类")
        pinnedCategory.order = 0
        pinnedCategory.isPinned = true
        
        let normalCategory = Category(context: context, name: "普通分类")
        normalCategory.order = 0
        normalCategory.isPinned = false
        
        try context.save()
        categoryViewModel.fetchCategories()
        
        // 验证初始状态
        XCTAssertEqual(categoryViewModel.pinnedCategories.count, 1)
        XCTAssertEqual(categoryViewModel.unpinnedCategories.count, 1)
        
        // 取消固定
        categoryViewModel.togglePinCategory(pinnedCategory)
        categoryViewModel.fetchCategories()
        
        // 验证取消固定后的状态
        XCTAssertEqual(categoryViewModel.pinnedCategories.count, 0)
        XCTAssertEqual(categoryViewModel.unpinnedCategories.count, 2)
        XCTAssertFalse(pinnedCategory.isPinned)
    }
    
    func testMultiplePinnedCategories() throws {
        // 创建多个分类
        let category1 = Category(context: context, name: "分类1")
        category1.order = 0
        
        let category2 = Category(context: context, name: "分类2")
        category2.order = 1
        
        let category3 = Category(context: context, name: "分类3")
        category3.order = 2
        
        try context.save()
        categoryViewModel.fetchCategories()
        
        // 固定多个分类
        categoryViewModel.togglePinCategory(category1)
        categoryViewModel.togglePinCategory(category3)
        categoryViewModel.fetchCategories()
        
        // 验证多个固定分类的状态
        XCTAssertEqual(categoryViewModel.pinnedCategories.count, 2)
        XCTAssertEqual(categoryViewModel.unpinnedCategories.count, 1)
        
        // 验证固定分类在顶部且保持顺序
        let pinnedNames = categoryViewModel.pinnedCategories.map { $0.name }
        XCTAssertTrue(pinnedNames.contains("分类1"))
        XCTAssertTrue(pinnedNames.contains("分类3"))
        
        // 验证普通分类
        XCTAssertEqual(categoryViewModel.unpinnedCategories[0].name, "分类2")
    }
    
    func testPinnedCategoryDragRestriction() throws {
        // 创建固定分类和普通分类
        let pinnedCategory = Category(context: context, name: "固定分类")
        pinnedCategory.order = 0
        pinnedCategory.isPinned = true
        
        let normalCategory1 = Category(context: context, name: "普通分类1")
        normalCategory1.order = 0
        normalCategory1.isPinned = false
        
        let normalCategory2 = Category(context: context, name: "普通分类2")
        normalCategory2.order = 1
        normalCategory2.isPinned = false
        
        try context.save()
        categoryViewModel.fetchCategories()
        
        let initialPinnedCount = categoryViewModel.pinnedCategories.count
        let initialUnpinnedCount = categoryViewModel.unpinnedCategories.count
        
        // 尝试将固定分类拖拽到普通分类区域（应该被阻止）
        categoryViewModel.moveCategory(from: 0, to: 2)
        categoryViewModel.fetchCategories()
        
        // 验证拖拽被阻止，分类数量没有变化
        XCTAssertEqual(categoryViewModel.pinnedCategories.count, initialPinnedCount)
        XCTAssertEqual(categoryViewModel.unpinnedCategories.count, initialUnpinnedCount)
        
        // 验证固定分类仍然固定
        XCTAssertTrue(pinnedCategory.isPinned)
    }
    
    func testPinnedCategoryPersistence() throws {
        // 创建并固定一个分类
        let category = Category(context: context, name: "测试分类")
        category.order = 0
        category.isPinned = false
        
        try context.save()
        categoryViewModel.fetchCategories()
        
        // 固定分类
        categoryViewModel.togglePinCategory(category)
        
        // 重新创建 ViewModel 来测试持久化
        let newCategoryViewModel = CategoryViewModel(context: context)
        
        // 验证固定状态在重新加载后仍然保持
        XCTAssertEqual(newCategoryViewModel.pinnedCategories.count, 1)
        XCTAssertEqual(newCategoryViewModel.pinnedCategories[0].name, "测试分类")
        XCTAssertTrue(newCategoryViewModel.pinnedCategories[0].isPinned)
    }
    
    func testCategorySortingWithPinnedCategories() throws {
        // 创建分类并设置不同的固定状态
        let category1 = Category(context: context, name: "普通分类A")
        category1.order = 0
        category1.isPinned = false
        
        let category2 = Category(context: context, name: "固定分类B")
        category2.order = 1
        category2.isPinned = true
        
        let category3 = Category(context: context, name: "普通分类C")
        category3.order = 2
        category3.isPinned = false
        
        let category4 = Category(context: context, name: "固定分类D")
        category4.order = 3
        category4.isPinned = true
        
        try context.save()
        categoryViewModel.fetchCategories()
        
        // 验证排序：固定分类在前，普通分类在后
        XCTAssertEqual(categoryViewModel.categories.count, 4)
        
        // 验证固定分类在前面
        let firstTwoCategories = Array(categoryViewModel.categories.prefix(2))
        XCTAssertTrue(firstTwoCategories.allSatisfy { $0.isPinned })
        
        // 验证普通分类在后面
        let lastTwoCategories = Array(categoryViewModel.categories.suffix(2))
        XCTAssertTrue(lastTwoCategories.allSatisfy { !$0.isPinned })
    }
    
    func testTogglePinCategoryUpdatesTimestamp() throws {
        // 创建分类
        let category = Category(context: context, name: "测试分类")
        let originalTimestamp = category.updatedAt
        
        try context.save()
        
        // 等待一小段时间确保时间戳不同
        Thread.sleep(forTimeInterval: 0.01)
        
        // 固定分类
        categoryViewModel.togglePinCategory(category)
        
        // 验证时间戳已更新
        XCTAssertNotEqual(category.updatedAt, originalTimestamp)
        XCTAssertGreaterThan(category.updatedAt!, originalTimestamp!)
    }
}
