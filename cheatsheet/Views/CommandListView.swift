//
//  CommandListView.swift
//  cheatsheet
//
//  Created by 周麒 on 2025/6/9.
//

import SwiftUI

struct CommandListView: View {
    let category: Category
    @ObservedObject var commandViewModel: CommandViewModel
    
    var body: some View {
        VStack {
            if commandViewModel.isLoading {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if commandViewModel.commands.isEmpty {
                EmptyCommandView(category: category, commandViewModel: commandViewModel)
            } else {
                List {
                    ForEach(commandViewModel.commands) { command in
                        CommandItemView(command: command, commandViewModel: commandViewModel)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle(category.name ?? "命令")
        .toolbar {
            ToolbarItem {
                Button(action: addCommand) {
                    Label("添加命令", systemImage: "plus")
                }
            }
        }
        .overlay(
            // 复制成功提示
            Group {
                if commandViewModel.showCopyToast {
                    CopyToastView()
                        .transition(.opacity)
                }
            }
        )
        .alert("错误", isPresented: .constant(commandViewModel.errorMessage != nil)) {
            Button("确定") {
                commandViewModel.clearError()
            }
        } message: {
            Text(commandViewModel.errorMessage ?? "")
        }
        .onAppear {
            commandViewModel.fetchCommands(for: category)
        }
    }
    
    private func addCommand() {
        commandViewModel.createCommand(
            name: "新命令",
            content: "echo 'Hello World'",
            category: category
        )
    }
}

struct CommandItemView: View {
    let command: Command
    @ObservedObject var commandViewModel: CommandViewModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(command.name ?? "未命名命令")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(command.content ?? "")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button(action: {
                commandViewModel.copyCommand(command)
            }) {
                Image(systemName: "doc.on.clipboard")
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
            .help("复制命令")
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            commandViewModel.copyCommand(command)
        }
        .contextMenu {
            Button("复制") {
                commandViewModel.copyCommand(command)
            }
            
            Button("编辑") {
                // TODO: 实现编辑功能
            }
            
            Divider()
            
            Button("删除", role: .destructive) {
                commandViewModel.deleteCommand(command)
            }
        }
    }
}

struct EmptyCommandView: View {
    let category: Category
    @ObservedObject var commandViewModel: CommandViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "terminal")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("暂无命令")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("点击右上角的 + 按钮添加第一个命令")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("添加命令") {
                commandViewModel.createCommand(
                    name: "新命令",
                    content: "echo 'Hello World'",
                    category: category
                )
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CopyToastView: View {
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("已复制到剪贴板！")
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 20)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let category = Category(context: context, name: "预览分类")
    let commandViewModel = CommandViewModel(context: context)
    
    return CommandListView(category: category, commandViewModel: commandViewModel)
}
