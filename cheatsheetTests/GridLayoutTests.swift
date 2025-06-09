//
//  GridLayoutTests.swift
//  cheatsheetTests
//
//  Created by 周麒 on 2025/6/9.
//

import XCTest
import SwiftUI
import CoreData
@testable import cheatsheet

final class GridLayoutTests: XCTestCase {
    
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
    
    // MARK: - 网格布局测试
    
    func testGridLayoutConfiguration() throws {
        // 创建测试分类
        let category = Category(context: context, name: "测试分类")
        
        // 创建多个命令来测试网格布局
        for i in 1...6 {
            let command = Command(context: context, name: "命令\(i)", content: "echo \(i)", category: category)
            command.order = Int16(i - 1)
        }
        
        try context.save()
        commandViewModel.fetchCommands(for: category)
        
        // 验证命令数量
        XCTAssertEqual(commandViewModel.commands.count, 6)
        
        // 验证命令顺序
        for (index, command) in commandViewModel.commands.enumerated() {
            XCTAssertEqual(command.name, "命令\(index + 1)")
            XCTAssertEqual(command.order, Int16(index))
        }
    }
    
    func testGridLayoutWithDragAndDrop() throws {
        // 创建测试分类和命令
        let category = Category(context: context, name: "拖拽测试分类")
        
        let command1 = Command(context: context, name: "第一个命令", content: "echo 1", category: category)
        command1.order = 0
        
        let command2 = Command(context: context, name: "第二个命令", content: "echo 2", category: category)
        command2.order = 1
        
        let command3 = Command(context: context, name: "第三个命令", content: "echo 3", category: category)
        command3.order = 2
        
        try context.save()
        commandViewModel.fetchCommands(for: category)
        
        // 验证初始顺序
        XCTAssertEqual(commandViewModel.commands[0].name, "第一个命令")
        XCTAssertEqual(commandViewModel.commands[1].name, "第二个命令")
        XCTAssertEqual(commandViewModel.commands[2].name, "第三个命令")
        
        // 测试拖拽排序在网格布局中的工作
        commandViewModel.moveCommand(from: 0, to: 2)
        commandViewModel.fetchCommands(for: category)
        
        // 验证拖拽后的顺序
        XCTAssertEqual(commandViewModel.commands[0].name, "第二个命令")
        XCTAssertEqual(commandViewModel.commands[1].name, "第三个命令")
        XCTAssertEqual(commandViewModel.commands[2].name, "第一个命令")
    }
    
    func testGridLayoutWithManyCommands() throws {
        // 创建测试分类
        let category = Category(context: context, name: "大量命令测试")
        
        // 创建大量命令来测试网格布局的性能和显示
        for i in 1...20 {
            let command = Command(context: context, name: "命令\(i)", content: "echo 'This is command number \(i)'", category: category)
            command.order = Int16(i - 1)
        }
        
        try context.save()
        commandViewModel.fetchCommands(for: category)
        
        // 验证所有命令都正确加载
        XCTAssertEqual(commandViewModel.commands.count, 20)
        
        // 验证命令顺序正确
        for (index, command) in commandViewModel.commands.enumerated() {
            XCTAssertEqual(command.name, "命令\(index + 1)")
            XCTAssertEqual(command.order, Int16(index))
        }
        
        // 测试在大量数据下的拖拽排序
        commandViewModel.moveCommand(from: 0, to: 19)
        commandViewModel.fetchCommands(for: category)
        
        // 验证第一个命令移动到了最后
        XCTAssertEqual(commandViewModel.commands[19].name, "命令1")
        XCTAssertEqual(commandViewModel.commands[0].name, "命令2")
    }
    
    func testGridLayoutCommandCardContent() throws {
        // 创建测试分类和命令
        let category = Category(context: context, name: "卡片内容测试")
        
        let command = Command(context: context, name: "长命令测试", content: "这是一个很长的命令内容，用来测试在网格布局中的显示效果。命令内容应该被正确地截断并显示在卡片中。", category: category)
        command.order = 0
        
        try context.save()
        commandViewModel.fetchCommands(for: category)
        
        // 验证命令内容
        XCTAssertEqual(commandViewModel.commands.count, 1)
        XCTAssertEqual(commandViewModel.commands[0].name, "长命令测试")
        XCTAssertTrue(commandViewModel.commands[0].content?.contains("这是一个很长的命令内容") == true)
    }
    
    func testGridLayoutEmptyState() throws {
        // 创建空分类
        let category = Category(context: context, name: "空分类")
        
        try context.save()
        commandViewModel.fetchCommands(for: category)
        
        // 验证空状态
        XCTAssertEqual(commandViewModel.commands.count, 0)
    }
    
    func testGridLayoutCommandCopy() throws {
        // 创建测试分类和命令
        let category = Category(context: context, name: "复制测试分类")
        
        let command = Command(context: context, name: "复制测试命令", content: "echo 'test copy'", category: category)
        command.order = 0
        
        try context.save()
        commandViewModel.fetchCommands(for: category)
        
        // 测试复制功能
        commandViewModel.copyCommand(command)
        
        // 验证命令仍然存在（复制不会删除原命令）
        XCTAssertEqual(commandViewModel.commands.count, 1)
        XCTAssertEqual(commandViewModel.commands[0].name, "复制测试命令")
    }
    
    func testGridLayoutCommandEditing() throws {
        // 创建测试分类和命令
        let category = Category(context: context, name: "编辑测试分类")
        
        let command = Command(context: context, name: "原始命令", content: "echo 'original'", category: category)
        command.order = 0
        
        try context.save()
        commandViewModel.fetchCommands(for: category)
        
        // 测试编辑命令
        commandViewModel.updateCommand(command, name: "编辑后命令", content: "echo 'edited'")
        commandViewModel.fetchCommands(for: category)
        
        // 验证编辑结果
        XCTAssertEqual(commandViewModel.commands.count, 1)
        XCTAssertEqual(commandViewModel.commands[0].name, "编辑后命令")
        XCTAssertEqual(commandViewModel.commands[0].content, "echo 'edited'")
    }
    
    func testGridLayoutCommandDeletion() throws {
        // 创建测试分类和命令
        let category = Category(context: context, name: "删除测试分类")
        
        let command1 = Command(context: context, name: "保留命令", content: "echo 'keep'", category: category)
        command1.order = 0
        
        let command2 = Command(context: context, name: "删除命令", content: "echo 'delete'", category: category)
        command2.order = 1
        
        try context.save()
        commandViewModel.fetchCommands(for: category)
        
        // 验证初始状态
        XCTAssertEqual(commandViewModel.commands.count, 2)
        
        // 删除一个命令
        commandViewModel.deleteCommand(command2)
        commandViewModel.fetchCommands(for: category)
        
        // 验证删除结果
        XCTAssertEqual(commandViewModel.commands.count, 1)
        XCTAssertEqual(commandViewModel.commands[0].name, "保留命令")
    }
}
