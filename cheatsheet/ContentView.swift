//
//  ContentView.swift
//  cheatsheet
//
//  Created by 周麒 on 2025/6/9.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @StateObject private var categoryViewModel: CategoryViewModel
    @StateObject private var commandViewModel: CommandViewModel

    init() {
        let context = PersistenceController.shared.container.viewContext
        _categoryViewModel = StateObject(wrappedValue: CategoryViewModel(context: context))
        _commandViewModel = StateObject(wrappedValue: CommandViewModel(context: context))
    }

    var body: some View {
        NavigationSplitView {
            // 左侧分类列表
            List(selection: $categoryViewModel.selectedCategory) {
                ForEach(categoryViewModel.categories) { category in
                    HStack {
                        Text(category.name ?? "未命名分类")
                        Spacer()
                        if category.isPinned {
                            Image(systemName: "pin.fill")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        Text("\(category.commandCount)")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .tag(category)
                }
            }
            .navigationTitle("分类")
            .toolbar {
                ToolbarItem {
                    Button(action: addCategory) {
                        Label("添加分类", systemImage: "plus")
                    }
                }
            }
            .refreshable {
                categoryViewModel.fetchCategories()
            }
        } detail: {
            // 右侧命令列表
            if let selectedCategory = categoryViewModel.selectedCategory {
                CommandListView(category: selectedCategory, commandViewModel: commandViewModel)
            } else {
                Text("请选择一个分类")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            categoryViewModel.fetchCategories()
        }
        .onChange(of: categoryViewModel.selectedCategory) { category in
            commandViewModel.fetchCommands(for: category)
        }
    }

    private func addCategory() {
        withAnimation {
            categoryViewModel.createCategory(name: "新分类")
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
