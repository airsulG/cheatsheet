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
        NavigationSplitView(columnVisibility: .constant(.all)) {
            // 左侧分类列表
            CategorySidebarView(categoryViewModel: categoryViewModel)
        } detail: {
            // 右侧命令列表
            if let selectedCategory = categoryViewModel.selectedCategory {
                CommandListView(category: selectedCategory, commandViewModel: commandViewModel)
            } else {
                WelcomeView()
            }
        }
        .navigationSplitViewColumnWidth(
            min: 200, ideal: 250, max: 400
        )
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            categoryViewModel.fetchCategories()
        }
        .onChange(of: categoryViewModel.selectedCategory) { category in
            commandViewModel.fetchCommands(for: category)
        }
        .alert("错误", isPresented: .constant(categoryViewModel.errorMessage != nil)) {
            Button("确定") {
                categoryViewModel.errorMessage = nil
            }
        } message: {
            Text(categoryViewModel.errorMessage ?? "")
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
