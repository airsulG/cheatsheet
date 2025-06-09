//
//  CategorySidebarView.swift
//  cheatsheet
//
//  Created by 周麒 on 2025/6/9.
//

import SwiftUI

struct CategorySidebarView: View {
    @ObservedObject var categoryViewModel: CategoryViewModel
    var commandViewModel: CommandViewModel? = nil
    @State private var showingAddCategoryAlert = false
    @State private var newCategoryName = ""
    @State private var showingImportAlert = false
    @State private var importJsonText = ""
    @StateObject private var dragState = DragState()
    
    var body: some View {
        VStack(spacing: 0) {
            // 分类标题
            HStack {
                Text("分类")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.clear)

            // 分类列表
            List(selection: $categoryViewModel.selectedCategory) {
                // 欢迎页选项
                Button(action: {
                    categoryViewModel.selectedCategory = nil
                }) {
                    HStack {
                        Text("欢迎页")
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .listRowBackground(categoryViewModel.selectedCategory == nil ? Color.accentColor.opacity(0.2) : Color.clear)

                // 固定分类
                ForEach(Array(categoryViewModel.pinnedCategories.enumerated()), id: \.element.id) { index, category in
                    CategoryRowView(
                        category: category,
                        categoryViewModel: categoryViewModel,
                        dragState: dragState,
                        index: index,
                        isPinnedSection: true
                    )
                    .tag(category)
                }

                // 其他分类
                ForEach(Array(categoryViewModel.unpinnedCategories.enumerated()), id: \.element.id) { index, category in
                    CategoryRowView(
                        category: category,
                        categoryViewModel: categoryViewModel,
                        dragState: dragState,
                        index: categoryViewModel.pinnedCategories.count + index,
                        isPinnedSection: false
                    )
                    .tag(category)
                }
                
                if categoryViewModel.categories.isEmpty {
                    EmptyCategoryView(categoryViewModel: categoryViewModel)
                }
            }
            .listStyle(SidebarListStyle())
            .refreshable {
                categoryViewModel.fetchCategories()
            }
            .padding(.top, 0)

            // 拖拽指示器
            if dragState.isDragging {
                DragIndicatorView(dragState: dragState)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            // 底部添加分类按钮
            HStack {
                Spacer()
                Button(action: {
                    showingAddCategoryAlert = true
                    newCategoryName = ""
                }) {
                    Image(systemName: "folder.badge.plus")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("n", modifiers: .command)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .alert("添加分类", isPresented: $showingAddCategoryAlert) {
            TextField("分类名称", text: $newCategoryName)
            Button("取消", role: .cancel) { }
            Button("添加") {
                if !newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    categoryViewModel.createCategory(name: newCategoryName)
                }
            }
        } message: {
            Text("请输入新分类的名称")
        }
        .alert("JSON 批量导入", isPresented: $showingImportAlert) {
            TextField("JSON 数据", text: $importJsonText, axis: .vertical)
                .lineLimit(5...10)
            Button("取消", role: .cancel) {
                importJsonText = ""
            }
            Button("导入") {
                importFromJson()
            }
        } message: {
            Text("请输入 JSON 格式的命令数据：[{\"name\":\"命令名\",\"prompt\":\"命令内容\"}]")
        }
    }

    // MARK: - 视图组件

    private var bottomActionBar: some View {
        HStack(spacing: 8) {
            Button(action: {
                showingAddCategoryAlert = true
                newCategoryName = ""
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("添加分类")
                }
                .font(.caption)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .keyboardShortcut("n", modifiers: .command)

            Button(action: {
                showingImportAlert = true
                importJsonText = ""
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down")
                    Text("JSON导入")
                }
                .font(.caption)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Rectangle()
                .fill(.regularMaterial)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(NSColor.separatorColor))
                        .opacity(0.5),
                    alignment: .top
                )
        )
    }

    // MARK: - JSON 导入功能

    private func importFromJson() {
        guard !importJsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        do {
            guard let jsonData = importJsonText.data(using: .utf8) else {
                throw ImportError.invalidData
            }

            let commands = try JSONDecoder().decode([ImportCommand].self, from: jsonData)

            // 创建新分类用于导入的命令
            let categoryName = "导入的命令 - \(Date().formatted(date: .abbreviated, time: .shortened))"
            categoryViewModel.createCategory(name: categoryName)

            // 获取刚创建的分类
            categoryViewModel.fetchCategories()
            guard let importCategory = categoryViewModel.categories.first(where: { $0.name == categoryName }) else {
                throw ImportError.invalidFormat
            }

            // 批量创建命令
            for command in commands {
                commandViewModel?.createCommand(
                    name: command.name,
                    content: command.prompt,
                    category: importCategory
                )
            }

            // 清空输入
            importJsonText = ""

            // 刷新分类列表
            categoryViewModel.fetchCategories()

        } catch {
            // 处理错误
            categoryViewModel.errorMessage = "JSON 导入失败：\(error.localizedDescription)"
        }
    }
}

struct CategoryRowView: View {
    let category: Category
    @ObservedObject var categoryViewModel: CategoryViewModel
    @ObservedObject var dragState: DragState
    let index: Int
    let isPinnedSection: Bool

    @State private var isEditing = false
    @State private var editingName = ""
    @State private var showingDeleteAlert = false
    @FocusState private var isTextFieldFocused: Bool

    private var dragData: DragData {
        DragData(id: category.id?.uuidString ?? "", type: .category, index: index)
    }
    
    var body: some View {
        HStack {
            if isEditing {
                TextField("分类名称", text: $editingName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        commitEdit()
                    }
                    .onExitCommand {
                        cancelEdit()
                    }
                    .focused($isTextFieldFocused)
            } else {
                HStack {
                    Text(category.name ?? "未命名分类")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if category.isPinned {
                        Image(systemName: "pin.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                    
                    Text("\(category.commandCount)")
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(8)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            print("🔍 CategoryRowView: 点击分类 \(category.name ?? "未命名")")
            categoryViewModel.selectedCategory = category
        }
        .draggable(dragData: dragData, dragState: dragState)
        .droppable(
            dropData: dragData,
            dragState: dragState,
            onDrop: handleDrop
        )

        .contextMenu {
            Button("重命名") {
                startEditing()
            }
            
            Button(category.isPinned ? "取消固定" : "固定到顶部") {
                categoryViewModel.togglePinCategory(category)
            }
            
            Divider()
            
            Button("删除", role: .destructive) {
                showingDeleteAlert = true
            }
        }
        .alert("删除分类", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                categoryViewModel.deleteCategory(category)
            }
        } message: {
            Text("确定要删除分类 \"\(category.name ?? "未命名分类")\" 吗？\n\n此操作将同时删除该分类下的所有命令，且无法撤销。")
        }
    }

    private func startEditing() {
        editingName = category.name ?? ""
        isEditing = true
        isTextFieldFocused = true
    }

    private func commitEdit() {
        if !editingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            categoryViewModel.updateCategory(category, name: editingName)
        }
        isEditing = false
        isTextFieldFocused = false
    }

    private func cancelEdit() {
        editingName = category.name ?? ""
        isEditing = false
        isTextFieldFocused = false
    }

    private func handleDrop(draggedItem: DragData, dropTarget: DragData) -> Bool {
        guard draggedItem.type == .category,
              draggedItem.id != dropTarget.id else {
            return false
        }

        // 检查是否在同一个分组内拖拽
        let draggedCategory = categoryViewModel.categories.first { $0.id?.uuidString == draggedItem.id }
        let targetCategory = categoryViewModel.categories.first { $0.id?.uuidString == dropTarget.id }

        guard let draggedCat = draggedCategory,
              let targetCat = targetCategory,
              draggedCat.isPinned == targetCat.isPinned else {
            return false // 不允许跨分组拖拽
        }

        categoryViewModel.moveCategory(from: draggedItem.index, to: dropTarget.index)
        return true
    }
}

struct EmptyCategoryView: View {
    @ObservedObject var categoryViewModel: CategoryViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("暂无分类")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("点击右上角的 + 按钮\n创建第一个分类")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let categoryViewModel = CategoryViewModel(context: context)

    return NavigationView {
        CategorySidebarView(categoryViewModel: categoryViewModel)
            .frame(width: 250)
    }
}
