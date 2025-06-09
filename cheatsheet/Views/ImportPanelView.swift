//
//  ImportPanelView.swift
//  cheatsheet
//
//  Created by 周麒 on 2025/6/9.
//

import SwiftUI

struct ImportPanelView: View {
    let category: Category
    @ObservedObject var commandViewModel: CommandViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var importJsonText = ""
    @State private var isImporting = false
    @State private var importResult: ImportResult?
    
    private var isFormValid: Bool {
        !importJsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                        // 导入说明卡片
                        importInstructionCard
                        
                        // JSON 编辑区域卡片
                        jsonEditorCard
                        
                        // 导入结果显示
                        if let result = importResult {
                            importResultCard(result: result)
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                }

                // 底部操作栏
                bottomActionBar
            }
        }
        .frame(minWidth: 700, minHeight: 600)
    }
    
    // MARK: - 视图组件
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("批量导入命令")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("导入到分类：\(category.name ?? "未命名分类")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(.regularMaterial))
            }
            .buttonStyle(.plain)
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
    
    private var importInstructionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
                
                Text("导入格式说明")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("请输入 JSON 格式的命令数据，格式如下：")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text("""
[
  {
    "name": "命令名称",
    "prompt": "命令内容"
  },
  {
    "name": "另一个命令",
    "prompt": "另一个命令的内容"
  }
]
""")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.controlBackgroundColor))
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
    
    private var jsonEditorCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.green)
                    .font(.title3)
                
                Text("JSON 数据")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !importJsonText.isEmpty {
                    Button("清空") {
                        importJsonText = ""
                        importResult = nil
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            // 大型文本编辑器
            TextEditor(text: $importJsonText)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color(NSColor.textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
                .frame(minHeight: 200)
                .onChange(of: importJsonText) { _ in
                    importResult = nil
                }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    private func importResultCard(result: ImportResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(result.isSuccess ? .green : .red)
                    .font(.title3)
                
                Text(result.isSuccess ? "导入成功" : "导入失败")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            Text(result.message)
                .font(.body)
                .foregroundColor(.secondary)
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

            Button("导入命令") {
                performImport()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isFormValid || isImporting)
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
    
    // MARK: - 导入功能
    
    private func performImport() {
        guard !importJsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isImporting = true
        
        do {
            guard let jsonData = importJsonText.data(using: .utf8) else {
                throw ImportError.invalidData
            }

            let commands = try JSONDecoder().decode([ImportCommand].self, from: jsonData)
            
            // 批量创建命令到当前分类
            var successCount = 0
            for command in commands {
                commandViewModel.createCommand(
                    name: command.name,
                    content: command.prompt,
                    category: category
                )
                successCount += 1
            }
            
            importResult = ImportResult(
                isSuccess: true,
                message: "成功导入 \(successCount) 个命令到分类「\(category.name ?? "未命名分类")」"
            )
            
            // 2秒后自动关闭
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                dismiss()
            }

        } catch {
            importResult = ImportResult(
                isSuccess: false,
                message: "导入失败：\(error.localizedDescription)"
            )
        }
        
        isImporting = false
    }
}

// MARK: - 辅助结构

struct ImportResult {
    let isSuccess: Bool
    let message: String
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let commandViewModel = CommandViewModel(context: context)
    let category = Category(context: context, name: "测试分类")
    
    return ImportPanelView(category: category, commandViewModel: commandViewModel)
}
