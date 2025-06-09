//
//  CommandManagementTests.swift
//  cheatsheetTests
//
//  Created by 周麒 on 2025/6/9.
//

import XCTest
import CoreData
@testable import cheatsheet

final class CommandManagementTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    var commandViewModel: CommandViewModel!
    var testCategory: Category!
    
    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
        commandViewModel = CommandViewModel(context: context)
        
        // 创建测试分类
        testCategory = Category(context: context, name: "测试分类")
        try context.save()
    }
    
    override func tearDownWithError() throws {
        persistenceController = nil
        context = nil
        commandViewModel = nil
        testCategory = nil
    }
    
    // MARK: - AC6: 创建命令条目测试
    
    func testCreateCommand() throws {
        // 测试创建命令
        commandViewModel.createCommand(name: "Docker 启动", content: "docker run -d nginx", category: testCategory)
        
        XCTAssertEqual(commandViewModel.commands.count, 1)
        XCTAssertEqual(commandViewModel.commands.first?.name, "Docker 启动")
        XCTAssertEqual(commandViewModel.commands.first?.content, "docker run -d nginx")
        XCTAssertEqual(commandViewModel.commands.first?.category, testCategory)
        XCTAssertEqual(commandViewModel.commands.first?.order, 0)
        XCTAssertNil(commandViewModel.errorMessage)
    }
    
    func testCreateMultipleCommands() throws {
        // 测试创建多个命令
        commandViewModel.createCommand(name: "命令1", content: "echo 'cmd1'", category: testCategory)
        commandViewModel.createCommand(name: "命令2", content: "echo 'cmd2'", category: testCategory)
        commandViewModel.createCommand(name: "命令3", content: "echo 'cmd3'", category: testCategory)
        
        XCTAssertEqual(commandViewModel.commands.count, 3)
        
        // 验证顺序
        let sortedCommands = commandViewModel.commands.sorted { $0.order < $1.order }
        XCTAssertEqual(sortedCommands[0].name, "命令1")
        XCTAssertEqual(sortedCommands[1].name, "命令2")
        XCTAssertEqual(sortedCommands[2].name, "命令3")
        
        // 验证 order 字段
        XCTAssertEqual(sortedCommands[0].order, 0)
        XCTAssertEqual(sortedCommands[1].order, 1)
        XCTAssertEqual(sortedCommands[2].order, 2)
    }
    
    func testCreateCommandWithEmptyName() throws {
        // 测试创建空名称命令
        commandViewModel.createCommand(name: "", content: "echo 'test'", category: testCategory)
        
        XCTAssertEqual(commandViewModel.commands.count, 0)
        XCTAssertNotNil(commandViewModel.errorMessage)
        XCTAssertEqual(commandViewModel.errorMessage, "命令名称不能为空")
    }
    
    func testCreateCommandWithEmptyContent() throws {
        // 测试创建空内容命令
        commandViewModel.createCommand(name: "测试命令", content: "", category: testCategory)
        
        XCTAssertEqual(commandViewModel.commands.count, 0)
        XCTAssertNotNil(commandViewModel.errorMessage)
        XCTAssertEqual(commandViewModel.errorMessage, "命令内容不能为空")
    }
    
    func testCreateCommandWithWhitespaceOnly() throws {
        // 测试创建只有空格的命令
        commandViewModel.createCommand(name: "   ", content: "   ", category: testCategory)
        
        XCTAssertEqual(commandViewModel.commands.count, 0)
        XCTAssertNotNil(commandViewModel.errorMessage)
    }
    
    // MARK: - AC7: 一键复制命令测试
    
    func testCopyCommand() throws {
        // 创建命令
        commandViewModel.createCommand(name: "复制测试", content: "echo 'copy test'", category: testCategory)
        let command = commandViewModel.commands.first!
        
        // 复制命令
        commandViewModel.copyCommand(command)
        
        XCTAssertEqual(commandViewModel.lastCopiedCommand, command)
        XCTAssertTrue(commandViewModel.showCopyToast)
        
        // 验证剪贴板内容
        let clipboardContent = ClipboardManager.shared.paste()
        XCTAssertEqual(clipboardContent, "echo 'copy test'")
    }
    
    func testCopyCommandWithEmptyContent() throws {
        // 创建内容为空的命令（通过直接设置，绕过验证）
        let command = Command(context: context, name: "空命令", content: "", category: testCategory)
        try context.save()
        commandViewModel.fetchCommands(for: testCategory)
        
        // 复制命令
        commandViewModel.copyCommand(command)
        
        // 验证剪贴板内容为空字符串
        let clipboardContent = ClipboardManager.shared.paste()
        XCTAssertEqual(clipboardContent, "")
    }
    
    // MARK: - AC8: 编辑命令条目测试
    
    func testUpdateCommand() throws {
        // 创建命令
        commandViewModel.createCommand(name: "原始命令", content: "echo 'original'", category: testCategory)
        let command = commandViewModel.commands.first!
        
        // 更新命令
        commandViewModel.updateCommand(command, name: "更新后的命令", content: "echo 'updated'")
        
        XCTAssertEqual(command.name, "更新后的命令")
        XCTAssertEqual(command.content, "echo 'updated'")
        XCTAssertNil(commandViewModel.errorMessage)
        
        // 验证时间戳更新
        XCTAssertNotNil(command.updatedAt)
    }
    
    func testUpdateCommandWithEmptyName() throws {
        // 创建命令
        commandViewModel.createCommand(name: "原始命令", content: "echo 'original'", category: testCategory)
        let command = commandViewModel.commands.first!
        let originalName = command.name
        let originalContent = command.content
        
        // 尝试用空名称更新
        commandViewModel.updateCommand(command, name: "", content: "echo 'updated'")
        
        XCTAssertEqual(command.name, originalName) // 名称不应该改变
        XCTAssertEqual(command.content, originalContent) // 内容也不应该改变
        XCTAssertNotNil(commandViewModel.errorMessage)
        XCTAssertEqual(commandViewModel.errorMessage, "命令名称不能为空")
    }
    
    func testUpdateCommandWithEmptyContent() throws {
        // 创建命令
        commandViewModel.createCommand(name: "原始命令", content: "echo 'original'", category: testCategory)
        let command = commandViewModel.commands.first!
        let originalName = command.name
        let originalContent = command.content
        
        // 尝试用空内容更新
        commandViewModel.updateCommand(command, name: "更新后的命令", content: "")
        
        XCTAssertEqual(command.name, originalName) // 名称不应该改变
        XCTAssertEqual(command.content, originalContent) // 内容不应该改变
        XCTAssertNotNil(commandViewModel.errorMessage)
        XCTAssertEqual(commandViewModel.errorMessage, "命令内容不能为空")
    }
    
    // MARK: - AC9: 删除命令条目测试
    
    func testDeleteCommand() throws {
        // 创建命令
        commandViewModel.createCommand(name: "待删除命令", content: "echo 'delete me'", category: testCategory)
        XCTAssertEqual(commandViewModel.commands.count, 1)
        
        let command = commandViewModel.commands.first!
        
        // 删除命令
        commandViewModel.deleteCommand(command)
        
        XCTAssertEqual(commandViewModel.commands.count, 0)
        XCTAssertNil(commandViewModel.errorMessage)
    }
    
    func testDeleteCommandReordersRemaining() throws {
        // 创建多个命令
        commandViewModel.createCommand(name: "命令1", content: "cmd1", category: testCategory)
        commandViewModel.createCommand(name: "命令2", content: "cmd2", category: testCategory)
        commandViewModel.createCommand(name: "命令3", content: "cmd3", category: testCategory)
        
        XCTAssertEqual(commandViewModel.commands.count, 3)
        
        // 删除中间的命令
        let middleCommand = commandViewModel.commands.first { $0.name == "命令2" }!
        commandViewModel.deleteCommand(middleCommand)
        
        XCTAssertEqual(commandViewModel.commands.count, 2)
        
        // 验证剩余命令的顺序
        let remainingCommands = commandViewModel.commands.sorted { $0.order < $1.order }
        XCTAssertEqual(remainingCommands[0].name, "命令1")
        XCTAssertEqual(remainingCommands[1].name, "命令3")
        XCTAssertEqual(remainingCommands[0].order, 0)
        XCTAssertEqual(remainingCommands[1].order, 1)
    }
    
    func testDeleteSelectedCommand() throws {
        // 创建并选择命令
        commandViewModel.createCommand(name: "选中的命令", content: "selected", category: testCategory)
        let command = commandViewModel.commands.first!
        commandViewModel.selectCommand(command)
        
        XCTAssertEqual(commandViewModel.selectedCommand, command)
        
        // 删除选中的命令
        commandViewModel.deleteCommand(command)
        
        XCTAssertEqual(commandViewModel.commands.count, 0)
        XCTAssertNil(commandViewModel.selectedCommand)
    }
    
    // MARK: - 命令排序测试
    
    func testMoveCommand() throws {
        // 创建多个命令
        commandViewModel.createCommand(name: "命令1", content: "cmd1", category: testCategory)
        commandViewModel.createCommand(name: "命令2", content: "cmd2", category: testCategory)
        commandViewModel.createCommand(name: "命令3", content: "cmd3", category: testCategory)
        
        // 移动命令（从索引0移动到索引2）
        commandViewModel.moveCommand(from: 0, to: 2)
        
        // 验证新的顺序
        let reorderedCommands = commandViewModel.commands.sorted { $0.order < $1.order }
        XCTAssertEqual(reorderedCommands[0].name, "命令2")
        XCTAssertEqual(reorderedCommands[1].name, "命令3")
        XCTAssertEqual(reorderedCommands[2].name, "命令1")
    }
    
    // MARK: - 数据获取测试
    
    func testFetchCommandsForCategory() throws {
        // 创建另一个分类
        let anotherCategory = Category(context: context, name: "另一个分类")
        
        // 为不同分类创建命令
        commandViewModel.createCommand(name: "分类1命令", content: "cmd1", category: testCategory)
        commandViewModel.createCommand(name: "分类2命令", content: "cmd2", category: anotherCategory)
        
        // 获取第一个分类的命令
        commandViewModel.fetchCommands(for: testCategory)
        XCTAssertEqual(commandViewModel.commands.count, 1)
        XCTAssertEqual(commandViewModel.commands.first?.name, "分类1命令")
        
        // 获取第二个分类的命令
        commandViewModel.fetchCommands(for: anotherCategory)
        XCTAssertEqual(commandViewModel.commands.count, 1)
        XCTAssertEqual(commandViewModel.commands.first?.name, "分类2命令")
    }
    
    func testFetchCommandsForNilCategory() throws {
        // 为分类创建命令
        commandViewModel.createCommand(name: "测试命令", content: "test", category: testCategory)
        
        // 获取 nil 分类的命令
        commandViewModel.fetchCommands(for: nil)
        
        XCTAssertEqual(commandViewModel.commands.count, 0)
        XCTAssertFalse(commandViewModel.isLoading)
    }
}
