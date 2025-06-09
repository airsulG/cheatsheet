//
//  CommandFormView.swift
//  cheatsheet
//
//  Created by 周麒 on 2025/6/9.
//

import SwiftUI

struct CommandFormView: View {
    let category: Category
    @ObservedObject var commandViewModel: CommandViewModel
    
    @State private var commandName: String
    @State private var commandContent: String
    @State private var isEditing: Bool
    
    private let command: Command?
    
    @Environment(\.dismiss) private var dismiss
    
    // 创建新命令的初始化器
    init(category: Category, commandViewModel: CommandViewModel) {
        self.category = category
        self.commandViewModel = commandViewModel
        self.command = nil
        self.isEditing = false
        self._commandName = State(initialValue: "")
        self._commandContent = State(initialValue: "")
    }
    
    // 编辑现有命令的初始化器
    init(command: Command, commandViewModel: CommandViewModel) {
        self.category = command.category!
        self.commandViewModel = commandViewModel
        self.command = command
        self.isEditing = true
        self._commandName = State(initialValue: command.name ?? "")
        self._commandContent = State(initialValue: command.content ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("命令信息") {
                    TextField("命令名称", text: $commandName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("命令内容")
                            .font(.headline)
                        
                        TextEditor(text: $commandContent)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                            )
                    }
                }
                
                if isEditing {
                    Section("操作") {
                        Button("测试复制") {
                            if let command = command {
                                commandViewModel.copyCommand(command)
                            } else {
                                ClipboardManager.shared.copy(commandContent)
                            }
                        }
                        .disabled(commandContent.isEmpty)
                    }
                }
            }
            .navigationTitle(isEditing ? "编辑命令" : "添加命令")

            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "保存" : "添加") {
                        saveCommand()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
    
    private var isFormValid: Bool {
        !commandName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !commandContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func saveCommand() {
        let trimmedName = commandName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = commandContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if isEditing, let command = command {
            commandViewModel.updateCommand(command, name: trimmedName, content: trimmedContent)
        } else {
            commandViewModel.createCommand(name: trimmedName, content: trimmedContent, category: category)
        }
        
        dismiss()
    }
}

#Preview("添加命令") {
    let context = PersistenceController.preview.container.viewContext
    let category = Category(context: context, name: "预览分类")
    let commandViewModel = CommandViewModel(context: context)
    
    return CommandFormView(category: category, commandViewModel: commandViewModel)
}

#Preview("编辑命令") {
    let context = PersistenceController.preview.container.viewContext
    let category = Category(context: context, name: "预览分类")
    let command = Command(context: context, name: "示例命令", content: "echo 'Hello World'", category: category)
    let commandViewModel = CommandViewModel(context: context)
    
    return CommandFormView(command: command, commandViewModel: commandViewModel)
}
