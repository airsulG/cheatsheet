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

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Category.isPinned, ascending: false),
            NSSortDescriptor(keyPath: \Category.order, ascending: true)
        ],
        animation: .default)
    private var categories: FetchedResults<Category>

    var body: some View {
        NavigationSplitView {
            // 左侧分类列表
            List {
                ForEach(categories) { category in
                    NavigationLink(value: category) {
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
                    }
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
        } detail: {
            // 右侧命令列表
            Text("请选择一个分类")
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    private func addCategory() {
        withAnimation {
            let newCategory = Category(context: viewContext, name: "新分类")
            newCategory.order = Int32(categories.count)

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("添加分类失败: \(nsError), \(nsError.userInfo)")
            }
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
