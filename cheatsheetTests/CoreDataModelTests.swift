//
//  CoreDataModelTests.swift
//  cheatsheetTests
//
//  Created by 周麒 on 2025/6/9.
//

import XCTest
import CoreData
@testable import cheatsheet

final class CoreDataModelTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    
    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
    }
    
    override func tearDownWithError() throws {
        persistenceController = nil
        context = nil
    }
    
    func testCategoryCreation() throws {
        // 测试分类创建
        let category = Category(context: context, name: "测试分类")
        
        XCTAssertNotNil(category.id)
        XCTAssertEqual(category.name, "测试分类")
        XCTAssertEqual(category.order, 0)
        XCTAssertFalse(category.isPinned)
        XCTAssertNotNil(category.createdAt)
        XCTAssertNotNil(category.updatedAt)
    }
    
    func testCommandCreation() throws {
        // 测试命令创建
        let category = Category(context: context, name: "测试分类")
        let command = Command(context: context, name: "测试命令", content: "echo 'hello'", category: category)
        
        XCTAssertNotNil(command.id)
        XCTAssertEqual(command.name, "测试命令")
        XCTAssertEqual(command.content, "echo 'hello'")
        XCTAssertEqual(command.order, 0)
        XCTAssertNotNil(command.createdAt)
        XCTAssertNotNil(command.updatedAt)
        XCTAssertEqual(command.category, category)
    }
    
    func testCategoryCommandRelationship() throws {
        // 测试分类和命令的关系
        let category = Category(context: context, name: "测试分类")
        let command1 = Command(context: context, name: "命令1", content: "cmd1", category: category)
        let command2 = Command(context: context, name: "命令2", content: "cmd2", category: category)
        
        XCTAssertEqual(category.commandCount, 2)
        XCTAssertTrue(category.commandsArray.contains(command1))
        XCTAssertTrue(category.commandsArray.contains(command2))
    }
    
    func testCoreDataPersistence() throws {
        // 测试数据持久化
        let category = Category(context: context, name: "持久化测试")
        let command = Command(context: context, name: "测试命令", content: "test", category: category)
        
        try context.save()
        
        // 重新获取数据
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        let categories = try context.fetch(fetchRequest)
        
        XCTAssertEqual(categories.count, 1)
        XCTAssertEqual(categories.first?.name, "持久化测试")
        XCTAssertEqual(categories.first?.commandCount, 1)
    }
}
