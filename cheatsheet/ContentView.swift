//
//  ContentView.swift
//  cheatsheet
//
//  Created by 周麒 on 2025/6/9.
//

import SwiftUI
import CoreData
import AppKit

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
        ZStack {
            // 现代化透明磨砂背景
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()

            // 完全自定义的分割视图布局
            CustomSplitView {
                // 左侧分类列表
                CategorySidebarView(categoryViewModel: categoryViewModel, commandViewModel: commandViewModel)
                    .background(.clear)
            } detail: {
                // 右侧命令列表
                if let selectedCategory = categoryViewModel.selectedCategory {
                    CommandListView(category: selectedCategory, commandViewModel: commandViewModel)
                        .background(.clear)
                } else {
                    WelcomeView()
                        .background(.clear)
                }
            }
        }
        .frame(minWidth: 800, minHeight: 500)
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
