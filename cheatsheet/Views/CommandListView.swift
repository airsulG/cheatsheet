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
        VStack(spacing: 0) {
            // 分类信息头部
            CategoryHeaderView(category: category)

            // 命令列表内容
            if commandViewModel.isLoading {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if commandViewModel.commands.isEmpty {
                EmptyCommandView(category: category, commandViewModel: commandViewModel)
            } else {
                List {
                    ForEach(commandViewModel.commands) { command in
                        CommandItemView(command: command, commandViewModel: commandViewModel)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(PlainListStyle())
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .navigationTitle(category.name ?? "命令")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
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
                        .transition(.opacity.combined(with: .scale))
                        .animation(.easeInOut(duration: 0.3), value: commandViewModel.showCopyToast)
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

struct CategoryHeaderView: View {
    let category: Category

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name ?? "未命名分类")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text("\(category.commandCount) 个命令")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if category.isPinned {
                Label("已固定", systemImage: "pin.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .bottom
        )
    }
}

struct CommandItemView: View {
    let command: Command
    @ObservedObject var commandViewModel: CommandViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(command.name ?? "未命名命令")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(command.content ?? "")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
            }

            Spacer()

            Button(action: {
                commandViewModel.copyCommand(command)
            }) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
            .help("复制命令到剪贴板")
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
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
        .padding(.horizontal)
        .padding(.vertical, 4)
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
