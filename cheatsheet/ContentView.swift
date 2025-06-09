import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var store = CheatStore()
    @State private var selectedCategoryID: CheatCategory.ID?

    @State private var showingAddCategory = false
    @State private var newCategoryName = ""

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedCategoryID) {
                ForEach(store.categories) { category in
                    Text(category.name)
                        .tag(category.id)
                        .contextMenu {
                            Button("重命名") {
                                renameCategory(category)
                            }
                            Button("删除", role: .destructive) {
                                if let index = store.categories.firstIndex(where: { $0.id == category.id }) {
                                    store.deleteCategories(at: IndexSet(integer: index))
                                }
                            }
                        }
                }
                .onMove { indices, newOffset in
                    store.moveCategories(from: indices, to: newOffset)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddCategory = true }) {
                        Label("新增分类", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddCategory) {
                AddCategorySheet(name: $newCategoryName) { name in
                    store.addCategory(named: name)
                    newCategoryName = ""
                }
            }
        } detail: {
            if let id = selectedCategoryID,
               let binding = binding(for: id) {
                CommandListView(category: binding, store: store)
            } else {
                Text("请在左侧选择或创建一个分类")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    func binding(for id: UUID) -> Binding<CheatCategory>? {
        guard let index = store.categories.firstIndex(where: { $0.id == id }) else { return nil }
        return $store.categories[index]
    }

    func renameCategory(_ category: CheatCategory) {
        let alert = NSAlert()
        alert.messageText = "重命名分类"
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.stringValue = category.name
        alert.accessoryView = input
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            store.renameCategory(category, newName: input.stringValue)
        }
    }
}

struct AddCategorySheet: View {
    @Binding var name: String
    var onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Text("新建分类").font(.headline)
            TextField("名称", text: $name)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("取消") { dismiss() }
                Spacer()
                Button("保存") {
                    onSave(name)
                    dismiss()
                }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
}
