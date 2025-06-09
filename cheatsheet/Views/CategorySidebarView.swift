//
//  CategorySidebarView.swift
//  cheatsheet
//
//  Created by 周麒 on 2025/6/9.
//

import SwiftUI

struct CategorySidebarView: View {
    @ObservedObject var categoryViewModel: CategoryViewModel
    @State private var showingAddCategoryAlert = false
    @State private var newCategoryName = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // 分类列表
            List(selection: $categoryViewModel.selectedCategory) {
                if !categoryViewModel.pinnedCategories.isEmpty {
                    Section("固定分类") {
                        ForEach(categoryViewModel.pinnedCategories) { category in
                            CategoryRowView(category: category, categoryViewModel: categoryViewModel)
                                .tag(category)
                        }
                    }
                }
                
                if !categoryViewModel.unpinnedCategories.isEmpty {
                    Section(categoryViewModel.pinnedCategories.isEmpty ? "分类" : "其他分类") {
                        ForEach(categoryViewModel.unpinnedCategories) { category in
                            CategoryRowView(category: category, categoryViewModel: categoryViewModel)
                                .tag(category)
                        }
                    }
                }
                
                if categoryViewModel.categories.isEmpty {
                    EmptyCategoryView(categoryViewModel: categoryViewModel)
                }
            }
            .listStyle(SidebarListStyle())
            .refreshable {
                categoryViewModel.fetchCategories()
            }
        }
        .navigationTitle("CheatHub")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showingAddCategoryAlert = true
                    newCategoryName = ""
                }) {
                    Label("添加分类", systemImage: "plus")
                }
            }
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
    }
}

struct CategoryRowView: View {
    let category: Category
    @ObservedObject var categoryViewModel: CategoryViewModel
    @State private var isEditing = false
    @State private var editingName = ""
    
    var body: some View {
        HStack {
            if isEditing {
                TextField("分类名称", text: $editingName, onCommit: {
                    if !editingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        categoryViewModel.updateCategory(category, name: editingName)
                    }
                    isEditing = false
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
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
        .onTapGesture(count: 2) {
            startEditing()
        }
        .contextMenu {
            Button("重命名") {
                startEditing()
            }
            
            Button(category.isPinned ? "取消固定" : "固定到顶部") {
                categoryViewModel.togglePinCategory(category)
            }
            
            Divider()
            
            Button("删除", role: .destructive) {
                categoryViewModel.deleteCategory(category)
            }
        }
    }
    
    private func startEditing() {
        editingName = category.name ?? ""
        isEditing = true
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
