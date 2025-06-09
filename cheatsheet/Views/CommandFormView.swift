//
//  CommandFormView.swift
//  cheatsheet
//
//  Created by 周麒 on 2025/6/9.
//

import SwiftUI
import AppKit

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
        ZStack {
            // 现代化透明磨砂背景
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部标题栏
                headerView

                // 主要内容区域
                ScrollView {
                    VStack(spacing: 24) {
                        // 命令基本信息卡片
                        commandInfoCard

                        // 命令内容卡片
                        commandContentCard

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                }

                // 底部操作栏
                bottomActionBar
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
    
    private var isFormValid: Bool {
        !commandName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !commandContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - 视图组件

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(isEditing ? "编辑命令" : "添加命令")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("在 \"\(category.name ?? "未知分类")\" 分类中")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("取消") {
                dismiss()
            }
            .buttonStyle(.borderless)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(NSColor.separatorColor))
                        .opacity(0.5),
                    alignment: .bottom
                )
        )
    }

    private var commandInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "terminal")
                    .foregroundColor(.blue)
                    .font(.title2)

                Text("命令信息")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("命令名称")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    TextField("输入命令名称", text: $commandName)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }

    private var commandContentCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.green)
                    .font(.title2)

                Text("命令内容")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                if !commandContent.isEmpty {
                    Text("\(commandContent.count) 字符")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Shell 命令")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                TextEditor(text: $commandContent)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 120)
                    .padding(12)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
                    .overlay(
                        Group {
                            if commandContent.isEmpty {
                                VStack {
                                    HStack {
                                        Text("输入你的 Shell 命令...")
                                            .foregroundColor(.secondary)
                                            .font(.system(.body, design: .monospaced))
                                        Spacer()
                                    }
                                    Spacer()
                                }
                                .padding(16)
                                .allowsHitTesting(false)
                            }
                        }
                    )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }



    private var bottomActionBar: some View {
        HStack(spacing: 12) {
            Spacer()

            Button("取消") {
                dismiss()
            }
            .buttonStyle(.bordered)

            Button(isEditing ? "保存更改" : "添加命令") {
                saveCommand()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isFormValid)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(NSColor.separatorColor))
                        .opacity(0.5),
                    alignment: .top
                )
        )
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

// MARK: - VisualEffectView

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
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
