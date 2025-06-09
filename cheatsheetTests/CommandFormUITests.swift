//
//  CommandFormUITests.swift
//  cheatsheetTests
//
//  Created by 周麒 on 2025/6/9.
//

import XCTest
import SwiftUI
import CoreData
@testable import cheatsheet

final class CommandFormUITests: XCTestCase {
    
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
    
    // MARK: - 新编辑界面测试
    
    func testCommandFormCreation() throws {
        // 创建测试分类
        let category = Category(context: context, name: "测试分类")
        try context.save()
        
        // 测试创建新命令的表单
        let formView = CommandFormView(category: category, commandViewModel: commandViewModel)
        
        // 验证表单初始状态
        XCTAssertFalse(formView.isEditing)
        XCTAssertEqual(formView.commandName, "")
        XCTAssertEqual(formView.commandContent, "")
        XCTAssertEqual(formView.category.name, "测试分类")
    }
    
    func testCommandFormEditing() throws {
        // 创建测试分类和命令
        let category = Category(context: context, name: "编辑测试分类")
        let command = Command(context: context, name: "测试命令", content: "echo 'test'", category: category)
        try context.save()
        
        // 测试编辑现有命令的表单
        let formView = CommandFormView(command: command, commandViewModel: commandViewModel)
        
        // 验证表单编辑状态
        XCTAssertTrue(formView.isEditing)
        XCTAssertEqual(formView.commandName, "测试命令")
        XCTAssertEqual(formView.commandContent, "echo 'test'")
        XCTAssertEqual(formView.category.name, "编辑测试分类")
    }
    
    func testFormValidation() throws {
        // 创建测试分类
        let category = Category(context: context, name: "验证测试分类")
        try context.save()
        
        let formView = CommandFormView(category: category, commandViewModel: commandViewModel)
        
        // 测试空表单验证
        XCTAssertFalse(formView.isFormValid)
        
        // 测试只有名称的验证
        formView.commandName = "测试命令"
        XCTAssertFalse(formView.isFormValid)
        
        // 测试只有内容的验证
        formView.commandName = ""
        formView.commandContent = "echo 'test'"
        XCTAssertFalse(formView.isFormValid)
        
        // 测试完整表单验证
        formView.commandName = "测试命令"
        formView.commandContent = "echo 'test'"
        XCTAssertTrue(formView.isFormValid)
        
        // 测试空白字符验证
        formView.commandName = "   "
        formView.commandContent = "   "
        XCTAssertFalse(formView.isFormValid)
    }
    
    func testSaveNewCommand() throws {
        // 创建测试分类
        let category = Category(context: context, name: "保存测试分类")
        try context.save()
        
        let formView = CommandFormView(category: category, commandViewModel: commandViewModel)
        
        // 设置表单数据
        formView.commandName = "新命令"
        formView.commandContent = "echo 'new command'"
        
        // 验证表单有效
        XCTAssertTrue(formView.isFormValid)
        
        // 模拟保存操作
        let initialCount = commandViewModel.commands.count
        commandViewModel.createCommand(name: "新命令", content: "echo 'new command'", category: category)
        commandViewModel.fetchCommands(for: category)
        
        // 验证命令已创建
        XCTAssertEqual(commandViewModel.commands.count, initialCount + 1)
        XCTAssertEqual(commandViewModel.commands.last?.name, "新命令")
        XCTAssertEqual(commandViewModel.commands.last?.content, "echo 'new command'")
    }
    
    func testUpdateExistingCommand() throws {
        // 创建测试分类和命令
        let category = Category(context: context, name: "更新测试分类")
        let command = Command(context: context, name: "原始命令", content: "echo 'original'", category: category)
        try context.save()
        
        commandViewModel.fetchCommands(for: category)
        let initialCount = commandViewModel.commands.count
        
        let formView = CommandFormView(command: command, commandViewModel: commandViewModel)
        
        // 修改表单数据
        formView.commandName = "更新后命令"
        formView.commandContent = "echo 'updated'"
        
        // 验证表单有效
        XCTAssertTrue(formView.isFormValid)
        
        // 模拟更新操作
        commandViewModel.updateCommand(command, name: "更新后命令", content: "echo 'updated'")
        commandViewModel.fetchCommands(for: category)
        
        // 验证命令已更新，数量不变
        XCTAssertEqual(commandViewModel.commands.count, initialCount)
        XCTAssertEqual(command.name, "更新后命令")
        XCTAssertEqual(command.content, "echo 'updated'")
    }
    
    func testCopyFunctionality() throws {
        // 创建测试分类和命令
        let category = Category(context: context, name: "复制测试分类")
        let command = Command(context: context, name: "复制测试命令", content: "echo 'copy test'", category: category)
        try context.save()
        
        let formView = CommandFormView(command: command, commandViewModel: commandViewModel)
        
        // 验证编辑模式下有复制功能
        XCTAssertTrue(formView.isEditing)
        
        // 测试复制功能（通过 ViewModel）
        commandViewModel.copyCommand(command)
        
        // 验证命令内容（实际的剪贴板测试在真实环境中进行）
        XCTAssertEqual(command.content, "echo 'copy test'")
    }
    
    func testFormDataTrimming() throws {
        // 创建测试分类
        let category = Category(context: context, name: "修剪测试分类")
        try context.save()
        
        let formView = CommandFormView(category: category, commandViewModel: commandViewModel)
        
        // 设置包含空白字符的数据
        formView.commandName = "  测试命令  "
        formView.commandContent = "  echo 'test'  "
        
        // 模拟保存操作（会自动修剪空白字符）
        commandViewModel.createCommand(
            name: formView.commandName.trimmingCharacters(in: .whitespacesAndNewlines),
            content: formView.commandContent.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category
        )
        commandViewModel.fetchCommands(for: category)
        
        // 验证空白字符已被修剪
        XCTAssertEqual(commandViewModel.commands.last?.name, "测试命令")
        XCTAssertEqual(commandViewModel.commands.last?.content, "echo 'test'")
    }
    
    func testFormWithLongContent() throws {
        // 创建测试分类
        let category = Category(context: context, name: "长内容测试分类")
        try context.save()
        
        let formView = CommandFormView(category: category, commandViewModel: commandViewModel)
        
        // 设置长内容
        let longContent = """
        #!/bin/bash
        # 这是一个很长的脚本示例
        for i in {1..10}; do
            echo "Processing item $i"
            sleep 1
        done
        echo "Script completed successfully"
        """
        
        formView.commandName = "长脚本命令"
        formView.commandContent = longContent
        
        // 验证表单仍然有效
        XCTAssertTrue(formView.isFormValid)
        
        // 保存并验证
        commandViewModel.createCommand(name: "长脚本命令", content: longContent, category: category)
        commandViewModel.fetchCommands(for: category)
        
        XCTAssertEqual(commandViewModel.commands.last?.name, "长脚本命令")
        XCTAssertEqual(commandViewModel.commands.last?.content, longContent)
    }
    
    func testFormCategoryDisplay() throws {
        // 创建测试分类
        let category = Category(context: context, name: "显示测试分类")
        try context.save()
        
        let formView = CommandFormView(category: category, commandViewModel: commandViewModel)
        
        // 验证分类信息正确显示
        XCTAssertEqual(formView.category.name, "显示测试分类")
        
        // 测试编辑模式下的分类显示
        let command = Command(context: context, name: "测试命令", content: "echo 'test'", category: category)
        try context.save()
        
        let editFormView = CommandFormView(command: command, commandViewModel: commandViewModel)
        XCTAssertEqual(editFormView.category.name, "显示测试分类")
    }
}
