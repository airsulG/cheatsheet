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

    // MARK: - View Models
    @StateObject private var categoryViewModel: CategoryViewModel
    @StateObject private var commandViewModel: CommandViewModel
    @StateObject private var clipboardHistoryViewModel: ClipboardHistoryViewModel

    // MARK: - State
    enum MainContentState: Equatable {
        case welcome
        case clipboardHistory
        case category(Category)

        static func == (lhs: ContentView.MainContentState, rhs: ContentView.MainContentState) -> Bool {
            switch (lhs, rhs) {
            case (.welcome, .welcome): return true
            case (.clipboardHistory, .clipboardHistory): return true
            case (.category(let lCat), .category(let rCat)): return lCat.objectID == rCat.objectID
            default: return false
            }
        }
    }
    @State private var mainContentState: MainContentState = .welcome

    init() {
        let context = PersistenceController.shared.container.viewContext
        _categoryViewModel = StateObject(wrappedValue: CategoryViewModel(context: context))
        _commandViewModel = StateObject(wrappedValue: CommandViewModel(context: context))
        _clipboardHistoryViewModel = StateObject(wrappedValue: ClipboardHistoryViewModel(context: context))
    }

    var body: some View {
        ZStack {
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()

            CustomSplitView {
                // 左侧分类列表
                CategorySidebarView(
                    categoryViewModel: categoryViewModel,
                    commandViewModel: commandViewModel,
                    mainContentState: $mainContentState
                )
                    .background(.clear)
            } detail: {
                // 右侧主内容区
                switch mainContentState {
                case .welcome:
                    WelcomeView()
                        .background(.clear)
                case .clipboardHistory:
                    ClipboardHistoryView(viewModel: clipboardHistoryViewModel)
                        .background(.clear)
                case .category(let selectedCategory):
                    CommandListView(category: selectedCategory, commandViewModel: commandViewModel)
                        .background(.clear)
                }
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .onAppear {
            categoryViewModel.fetchCategories()
        }
        // 当 mainContentState 改变时，加载对应的数据
        .onChange(of: mainContentState) { newState in
            switch newState {
            case .category(let category):
                commandViewModel.fetchCommands(for: category)
            default:
                break
            }
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
