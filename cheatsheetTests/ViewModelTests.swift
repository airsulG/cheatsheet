//
//  ViewModelTests.swift
//  cheatsheetTests
//
//  Created by 周麒 on 2025/6/9.
//

import XCTest
import CoreData
@testable import cheatsheet

final class ViewModelTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var categoryViewModel: CategoryViewModel!
    var commandViewModel: CommandViewModel!
    
    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        categoryViewModel = CategoryViewModel(context: context)
        commandViewModel = CommandViewModel(context: context)
    }
    
    override func tearDownWithError() throws {
        persistenceController = nil
        context = nil
        categoryViewModel = nil
        commandViewModel = nil
    }
    
    // MARK: - CategoryViewModel Tests
    
    func testCategoryViewModelInitialization() throws {
        XCTAssertNotNil(categoryViewModel)
        XCTAssertEqual(categoryViewModel.categories.count, 0)
        XCTAssertNil(categoryViewModel.selectedCategory)
        XCTAssertFalse(categoryViewModel.isLoading)
        XCTAssertNil(categoryViewModel.errorMessage)
    }
    
    func testCreateCategory() throws {
        categoryViewModel.createCategory(name: "测试分类")
        
        XCTAssertEqual(categoryViewModel.categories.count, 1)
        XCTAssertEqual(categoryViewModel.categories.first?.name, "测试分类")
        XCTAssertNil(categoryViewModel.errorMessage)
    }
    
    func testCreateCategoryWithEmptyName() throws {
        categoryViewModel.createCategory(name: "")
        
        XCTAssertEqual(categoryViewModel.categories.count, 0)
        XCTAssertNotNil(categoryViewModel.errorMessage)
        XCTAssertEqual(categoryViewModel.errorMessage, "分类名称不能为空")
    }
    
    func testUpdateCategory() throws {
        categoryViewModel.createCategory(name: "原始名称")
        let category = categoryViewModel.categories.first!
        
        categoryViewModel.updateCategory(category, name: "更新后的名称")
        
        XCTAssertEqual(category.name, "更新后的名称")
        XCTAssertNil(categoryViewModel.errorMessage)
    }
    
    func testDeleteCategory() throws {
        categoryViewModel.createCategory(name: "待删除分类")
        let category = categoryViewModel.categories.first!
        
        categoryViewModel.deleteCategory(category)
        
        XCTAssertEqual(categoryViewModel.categories.count, 0)
    }
    
    func testTogglePinCategory() throws {
        categoryViewModel.createCategory(name: "测试分类")
        let category = categoryViewModel.categories.first!
        
        XCTAssertFalse(category.isPinned)
        
        categoryViewModel.togglePinCategory(category)
        
        XCTAssertTrue(category.isPinned)
    }
    
    // MARK: - CommandViewModel Tests
    
    func testCommandViewModelInitialization() throws {
        XCTAssertNotNil(commandViewModel)
        XCTAssertEqual(commandViewModel.commands.count, 0)
        XCTAssertNil(commandViewModel.selectedCommand)
        XCTAssertFalse(commandViewModel.isLoading)
        XCTAssertNil(commandViewModel.errorMessage)
    }
    
    func testCreateCommand() throws {
        let category = Category(context: context, name: "测试分类")
        
        commandViewModel.createCommand(name: "测试命令", content: "echo 'test'", category: category)
        
        XCTAssertEqual(commandViewModel.commands.count, 1)
        XCTAssertEqual(commandViewModel.commands.first?.name, "测试命令")
        XCTAssertEqual(commandViewModel.commands.first?.content, "echo 'test'")
        XCTAssertNil(commandViewModel.errorMessage)
    }
    
    func testCreateCommandWithEmptyName() throws {
        let category = Category(context: context, name: "测试分类")
        
        commandViewModel.createCommand(name: "", content: "echo 'test'", category: category)
        
        XCTAssertEqual(commandViewModel.commands.count, 0)
        XCTAssertNotNil(commandViewModel.errorMessage)
        XCTAssertEqual(commandViewModel.errorMessage, "命令名称不能为空")
    }
    
    func testCreateCommandWithEmptyContent() throws {
        let category = Category(context: context, name: "测试分类")
        
        commandViewModel.createCommand(name: "测试命令", content: "", category: category)
        
        XCTAssertEqual(commandViewModel.commands.count, 0)
        XCTAssertNotNil(commandViewModel.errorMessage)
        XCTAssertEqual(commandViewModel.errorMessage, "命令内容不能为空")
    }
    
    func testUpdateCommand() throws {
        let category = Category(context: context, name: "测试分类")
        commandViewModel.createCommand(name: "原始命令", content: "echo 'original'", category: category)
        let command = commandViewModel.commands.first!
        
        commandViewModel.updateCommand(command, name: "更新后的命令", content: "echo 'updated'")
        
        XCTAssertEqual(command.name, "更新后的命令")
        XCTAssertEqual(command.content, "echo 'updated'")
        XCTAssertNil(commandViewModel.errorMessage)
    }
    
    func testDeleteCommand() throws {
        let category = Category(context: context, name: "测试分类")
        commandViewModel.createCommand(name: "待删除命令", content: "echo 'delete'", category: category)
        let command = commandViewModel.commands.first!
        
        commandViewModel.deleteCommand(command)
        
        XCTAssertEqual(commandViewModel.commands.count, 0)
    }
    
    func testCopyCommand() throws {
        let category = Category(context: context, name: "测试分类")
        commandViewModel.createCommand(name: "复制测试", content: "echo 'copy test'", category: category)
        let command = commandViewModel.commands.first!
        
        commandViewModel.copyCommand(command)
        
        XCTAssertEqual(commandViewModel.lastCopiedCommand, command)
        XCTAssertTrue(commandViewModel.showCopyToast)
        
        // 验证剪贴板内容
        let clipboardContent = ClipboardManager.shared.paste()
        XCTAssertEqual(clipboardContent, "echo 'copy test'")
    }
    
    func testFetchCommandsForCategory() throws {
        let category = Category(context: context, name: "测试分类")
        let command1 = Command(context: context, name: "命令1", content: "cmd1", category: category)
        let command2 = Command(context: context, name: "命令2", content: "cmd2", category: category)
        
        try context.save()
        
        commandViewModel.fetchCommands(for: category)
        
        XCTAssertEqual(commandViewModel.commands.count, 2)
        XCTAssertTrue(commandViewModel.commands.contains(command1))
        XCTAssertTrue(commandViewModel.commands.contains(command2))
    }
}
