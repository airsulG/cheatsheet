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

    @State private var showingAddCommandSheet = false
    @State private var showingEditCommandSheet = false
    @State private var editingCommand: Command?
    @State private var showingImportPanel = false
    @State private var showingExportAlert = false
    @StateObject private var dragState = DragState()

    // 网格列配置：自适应列，最小宽度 240pt，最大宽度 320pt
    private let gridColumns = [
        GridItem(.adaptive(minimum: 240, maximum: 320), spacing: 12)
    ]

    init(category: Category, commandViewModel: CommandViewModel) {
        self.category = category
        self.commandViewModel = commandViewModel
    }

    // 计算属性：收藏命令
    private var favoriteCommands: [Command] {
        commandViewModel.commands.filter { $0.isFavorite }
    }

    // 计算属性：普通命令
    private var regularCommands: [Command] {
        commandViewModel.commands.filter { !$0.isFavorite }
    }
    
    var body: some View {
        ZStack {
            // 透明磨砂背景
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 命令面板标题和操作按钮
                CommandHeaderView(
                    category: category,
                    showingAddCommandSheet: $showingAddCommandSheet,
                    showingImportPanel: $showingImportPanel,
                    showingExportAlert: $showingExportAlert
                )

                // 命令列表内容
                if commandViewModel.isLoading {
                    ProgressView("加载中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if commandViewModel.commands.isEmpty {
                    EmptyCommandView(category: category, commandViewModel: commandViewModel)
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // 收藏命令部分
                            if !favoriteCommands.isEmpty {
                                VStack(spacing: 12) {
                                    HStack {
                                        Text("收藏")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                    .padding(.horizontal)

                                    LazyVGrid(columns: gridColumns, spacing: 12) {
                                        ForEach(Array(favoriteCommands.enumerated()), id: \.element.id) { index, command in
                                            CommandItemView(
                                                command: command,
                                                commandViewModel: commandViewModel,
                                                dragState: dragState,
                                                index: index
                                            )
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }

                            // 普通命令部分
                            if !regularCommands.isEmpty {
                                VStack(spacing: 12) {
                                    HStack {
                                        Text("指令")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                    .padding(.horizontal)

                                    LazyVGrid(columns: gridColumns, spacing: 12) {
                                        ForEach(Array(regularCommands.enumerated()), id: \.element.id) { index, command in
                                            CommandItemView(
                                                command: command,
                                                commandViewModel: commandViewModel,
                                                dragState: dragState,
                                                index: favoriteCommands.count + index
                                            )
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.top, 0)
                        .padding(.bottom)

                        // 拖拽指示器
                        if dragState.isDragging {
                            DragIndicatorView(dragState: dragState)
                                .padding(.horizontal)
                                .padding(.bottom, 8)
                        }
                    }
                    .background(.clear)
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
        .sheet(isPresented: $showingAddCommandSheet) {
            CommandFormView(category: category, commandViewModel: commandViewModel)
        }
        .sheet(isPresented: $showingEditCommandSheet) {
            if let editingCommand = editingCommand {
                CommandFormView(command: editingCommand, commandViewModel: commandViewModel)
            }
        }
        .sheet(isPresented: $showingImportPanel) {
            ImportPanelView(category: category, commandViewModel: commandViewModel)
        }
        .alert("导出命令", isPresented: $showingExportAlert) {
            Button("复制到剪贴板") {
                copyExportToClipboard()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("导出当前分类的所有命令为 JSON 格式")
        }
    }

    // MARK: - JSON 导出功能

    private func copyExportToClipboard() {
        let exportCommands = commandViewModel.commands.map { command in
            ImportCommand(name: command.name ?? "", prompt: command.content ?? "")
        }

        do {
            let jsonData = try JSONEncoder().encode(exportCommands)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                ClipboardManager.shared.copy(jsonString)
                commandViewModel.showCopyToast = true

                // 3秒后隐藏提示
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    commandViewModel.showCopyToast = false
                }
            }
        } catch {
            commandViewModel.errorMessage = "导出失败：\(error.localizedDescription)"
        }
    }
}

struct CommandHeaderView: View {
    let category: Category
    @Binding var showingAddCommandSheet: Bool
    @Binding var showingImportPanel: Bool
    @Binding var showingExportAlert: Bool

    var body: some View {
        HStack(spacing: 12) {
            Spacer()

            // 导出按钮
            Button(action: {
                showingExportAlert = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                    Text("导出")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .stroke(Color.gray.opacity(0.6), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // JSON导入按钮
            Button(action: {
                showingImportPanel = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                    Text("批量导入")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .stroke(Color.gray.opacity(0.6), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // 添加命令按钮
            Button(action: {
                showingAddCommandSheet = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                    Text("添加")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .stroke(Color.gray.opacity(0.6), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.clear)
    }
}

struct CommandItemView: View {
    let command: Command
    @ObservedObject var commandViewModel: CommandViewModel
    @ObservedObject var dragState: DragState
    let index: Int

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false

    private var dragData: DragData {
        DragData(id: command.id?.uuidString ?? "", type: .command, index: index)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 第一行：命令名称和收藏按钮
            HStack {
                Text(command.name ?? "未命名命令")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                Button(action: {
                    command.toggleFavorite()
                    commandViewModel.saveContext()
                }) {
                    Image(systemName: command.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 14))
                        .foregroundColor(command.isFavorite ? .white : .secondary)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    // 可以添加悬停效果
                }
            }

            // 第二行：命令内容
            Text(command.content ?? "")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 60)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
        .contentShape(Rectangle())
        .draggable(dragData: dragData, dragState: dragState)
        .droppable(
            dropData: dragData,
            dragState: dragState,
            onDrop: handleDrop
        )
        .onTapGesture {
            commandViewModel.copyCommand(command)
        }
        .onTapGesture(count: 2) {
            showingEditSheet = true
        }
        .contextMenu {
            Button("复制") {
                commandViewModel.copyCommand(command)
            }

            Button(command.isFavorite ? "取消收藏" : "收藏") {
                command.toggleFavorite()
                commandViewModel.saveContext()
            }

            Button("编辑") {
                showingEditSheet = true
            }

            Divider()

            Button("删除", role: .destructive) {
                showingDeleteAlert = true
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            CommandFormView(command: command, commandViewModel: commandViewModel)
        }
        .alert("删除命令", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                commandViewModel.deleteCommand(command)
            }
        } message: {
            Text("确定要删除命令 \"\(command.name ?? "未命名命令")\" 吗？\n\n此操作无法撤销。")
        }
    }

    private func handleDrop(draggedItem: DragData, dropTarget: DragData) -> Bool {
        guard draggedItem.type == .command,
              draggedItem.id != dropTarget.id else {
            return false
        }

        commandViewModel.moveCommand(from: draggedItem.index, to: dropTarget.index)
        return true
    }
}

struct EmptyCommandView: View {
    let category: Category
    @ObservedObject var commandViewModel: CommandViewModel

    @State private var showingAddCommandSheet = false
    
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
                showingAddCommandSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingAddCommandSheet) {
            CommandFormView(category: category, commandViewModel: commandViewModel)
        }
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

// MARK: - 导入数据模型

struct ImportCommand: Codable {
    let name: String
    let prompt: String
}

enum ImportError: LocalizedError {
    case invalidData
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "无效的 JSON 数据"
        case .invalidFormat:
            return "JSON 格式不正确，请使用 [{\"name\":\"命令名\",\"prompt\":\"命令内容\"}] 格式"
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let category = Category(context: context, name: "预览分类")
    let commandViewModel = CommandViewModel(context: context)

    return CommandListView(category: category, commandViewModel: commandViewModel)
}
