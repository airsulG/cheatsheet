//
//  ShelfView.swift
//  cheatsheet
//
//  Created by Codex on 2025/8/28.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ShelfView: View {
    @ObservedObject var viewModel: ShelfViewModel

    @State private var showingAddCommandSheet = false
    @State private var renamingCategory: Category? = nil
    @State private var newCategoryName: String = ""
    @State private var searchText: String = ""
    @State private var isClipboardSelected: Bool = false // 将剪贴板作为一个“标签”
    @State private var isFavoritesSelected: Bool = false  // 收藏标签
    @State private var isSearching: Bool = false

    private let cardSpacing: CGFloat = 12
    @StateObject private var dragState = ShelfDragState.shared
    @StateObject private var tabDragState = ShelfTabDragState.shared
    @State private var appeared = false

    var body: some View {
        ZStack {
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                headerBar
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                Divider().opacity(0.3)

                // 卡片区域（横向滚动）
                ScrollView(.horizontal, showsIndicators: true) {
                    if isClipboardSelected {
                        // 剪贴板
                        LazyHStack(spacing: cardSpacing) {
                            ForEach(viewModel.pagedClipboardVM.items.filter { item in
                                let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !q.isEmpty else { return true }
                                let type = item.type ?? ""
                                let content = item.content ?? ""
                                return type.localizedCaseInsensitiveContains(q) || content.localizedCaseInsensitiveContains(q)
                            }, id: \.id) { item in
                                ClipboardShelfCard(item: item) {
                                    if viewModel.pagedClipboardVM.copyItem(item) {
                                        viewModel.showCopyToast = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { viewModel.showCopyToast = false }
                                    }
                                } onDelete: {
                                    viewModel.pagedClipboardVM.deleteItem(item)
                                }
                                .onAppear {
                                    if item.objectID == viewModel.pagedClipboardVM.items.last?.objectID {
                                        viewModel.pagedClipboardVM.loadNextPage()
                                    }
                                }
                            }
                        }
                    } else if isFavoritesSelected {
                        // 收藏命令：搜索为空可重排，否则只读
                        let fq = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if fq.isEmpty {
                            ReorderableHStack(
                                items: viewModel.favorites,
                                id: \.id,
                                spacing: cardSpacing,
                                content: { cmd in
                                    ShelfCardView(
                                        title: cmd.name ?? "",
                                        subtitle: (cmd.content ?? "").components(separatedBy: .newlines).first ?? "",
                                        onTap: {
                                            viewModel.commandVM.copyCommand(cmd)
                                            if viewModel.commandVM.showCopyToast { viewModel.showToast() }
                                        },
                                        onEdit: {
                                            EditorWindowController.shared.presentCommandEdit(command: cmd, commandViewModel: viewModel.commandVM)
                                        },
                                        onDelete: {
                                            viewModel.commandVM.deleteCommand(cmd)
                                            viewModel.fetchFavorites()
                                        },
                                        onToggleFavorite: {
                                            viewModel.toggleFavorite(cmd)
                                        },
                                        isFavorite: cmd.isFavorite
                                    )
                                },
                                onMove: { from, to in
                                    viewModel.moveFavorite(from: from, to: to)
                                }
                            )
                        } else {
                            LazyHStack(spacing: cardSpacing) {
                                ForEach(viewModel.favorites.filter { cmd in
                                    return (cmd.name ?? "").localizedCaseInsensitiveContains(fq) ||
                                           (cmd.content ?? "").localizedCaseInsensitiveContains(fq)
                                }, id: \.id) { cmd in
                                    ShelfCardView(
                                        title: cmd.name ?? "",
                                        subtitle: (cmd.content ?? "").components(separatedBy: .newlines).first ?? "",
                                        onTap: {
                                            viewModel.commandVM.copyCommand(cmd)
                                            if viewModel.commandVM.showCopyToast { viewModel.showToast() }
                                        },
                                        onEdit: { EditorWindowController.shared.presentCommandEdit(command: cmd, commandViewModel: viewModel.commandVM) },
                                        onDelete: { viewModel.commandVM.deleteCommand(cmd); viewModel.fetchFavorites() },
                                        onToggleFavorite: { viewModel.toggleFavorite(cmd) },
                                        isFavorite: cmd.isFavorite
                                    )
                                }
                            }
                        }
                    } else {
                        // 当前分类中的命令（DragGesture 重排，仅在搜索为空时）
                        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if q.isEmpty {
                            ReorderableHStack(
                                items: viewModel.commandVM.commands,
                                id: \.id,
                                spacing: cardSpacing,
                                content: { cmd in
                                    ShelfCardView(
                                        title: cmd.name ?? "",
                                        subtitle: (cmd.content ?? "").components(separatedBy: .newlines).first ?? "",
                                        onTap: {
                                            viewModel.commandVM.copyCommand(cmd)
                                            if viewModel.commandVM.showCopyToast { viewModel.showToast() }
                                        },
                                        onEdit: {
                                            EditorWindowController.shared.presentCommandEdit(command: cmd, commandViewModel: viewModel.commandVM)
                                        },
                                        onDelete: { viewModel.commandVM.deleteCommand(cmd) },
                                        onToggleFavorite: { viewModel.toggleFavorite(cmd) },
                                        isFavorite: cmd.isFavorite
                                    )
                                },
                                onMove: { from, to in
                                    viewModel.commandVM.moveCommand(from: from, to: to)
                                }
                            )
                        } else {
                            LazyHStack(spacing: cardSpacing) {
                                ForEach(viewModel.filteredCommands, id: \.id) { cmd in
                                    ShelfCardView(
                                        title: cmd.name ?? "",
                                        subtitle: (cmd.content ?? "").components(separatedBy: .newlines).first ?? "",
                                        onTap: {
                                            viewModel.commandVM.copyCommand(cmd)
                                            if viewModel.commandVM.showCopyToast { viewModel.showToast() }
                                        },
                                        onEdit: {
                                            EditorWindowController.shared.presentCommandEdit(command: cmd, commandViewModel: viewModel.commandVM)
                                        },
                                        onDelete: { viewModel.commandVM.deleteCommand(cmd) },
                                        onToggleFavorite: { viewModel.toggleFavorite(cmd) },
                                        isFavorite: cmd.isFavorite
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxHeight: .infinity)
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)
                .animation(.interpolatingSpring(stiffness: 220, damping: 22), value: appeared)

                if !isClipboardSelected && !isFavoritesSelected {
                    bottomBar
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }
            }
        }
        .frame(minHeight: 300) // 默认高度 300
        .overlay(
            // 顶部柔和阴影，增强与桌面边界的层次感
            VStack(spacing: 0) {
                Rectangle().fill(Color.black.opacity(0.12)).frame(height: 0.5)
                Rectangle().fill(Color.black.opacity(0.06)).frame(height: 0.5)
                Spacer()
            }
        )
        .onChange(of: searchText) { newValue in
            viewModel.searchText = newValue
        }
        .onChange(of: isClipboardSelected) { selected in
            if selected {
                viewModel.pagedClipboardVM.ensureFirstPageLoaded()
            }
        }
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
        .overlay(
            Group {
                if viewModel.showCopyToast || viewModel.commandVM.showCopyToast {
                    CopyToastView()
                        .transition(.opacity.combined(with: .scale))
                        .animation(.easeInOut(duration: 0.3), value: viewModel.showCopyToast)
                }
            }
        )
        // 移除新建命令的 sheet，改为独立窗口（见 bottomBar）
        .alert("重命名分类", isPresented: Binding(get: { renamingCategory != nil }, set: { if !$0 { renamingCategory = nil } })) {
            TextField("新的分类名称", text: $newCategoryName)
            Button("取消", role: .cancel) { renamingCategory = nil }
            Button("确定") {
                if let cat = renamingCategory {
                    viewModel.categoryVM.updateCategory(cat, name: newCategoryName)
                    renamingCategory = nil
                }
            }
        } message: {
            Text("请输入新的分类名称")
        }
    }

    private var headerBar: some View {
        HStack(spacing: 8) {
            // 左侧：标签（含“剪贴板/收藏/分类”）
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // 剪贴板标签
                    Text("剪贴板")
                        .font(.system(size: 13, weight: isClipboardSelected ? .semibold : .regular))
                        .foregroundColor(isClipboardSelected ? .white : .primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(isClipboardSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor)))
                        .overlay(Capsule().stroke(Color(NSColor.separatorColor), lineWidth: isClipboardSelected ? 0 : 1))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isClipboardSelected = true
                            isFavoritesSelected = false
                            viewModel.clearSelection()
                        }

                    // 收藏标签
                    Text("收藏")
                        .font(.system(size: 13, weight: isFavoritesSelected ? .semibold : .regular))
                        .foregroundColor(isFavoritesSelected ? .white : .primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(isFavoritesSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor)))
                        .overlay(Capsule().stroke(Color(NSColor.separatorColor), lineWidth: isFavoritesSelected ? 0 : 1))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isFavoritesSelected = true
                            isClipboardSelected = false
                            viewModel.clearSelection()
                            viewModel.fetchFavorites()
                        }

                    // 分类标签（DragGesture 重排）
                    ReorderableHStack(
                        items: viewModel.categoryVM.categories,
                        id: \.id,
                        spacing: 8,
                        content: { category in
                            Text(category.name ?? "未命名")
                                .font(.system(size: 13, weight: ((!isClipboardSelected) && (!isFavoritesSelected) && (viewModel.selectedCategory?.objectID == category.objectID)) ? .semibold : .regular))
                                .foregroundColor(((!isClipboardSelected) && (!isFavoritesSelected) && (viewModel.selectedCategory?.objectID == category.objectID)) ? .white : .primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(((!isClipboardSelected) && (!isFavoritesSelected) && (viewModel.selectedCategory?.objectID == category.objectID)) ? Color.accentColor : Color(NSColor.controlBackgroundColor)))
                                .overlay(Capsule().stroke(Color(NSColor.separatorColor), lineWidth: ((!isClipboardSelected) && (!isFavoritesSelected) && (viewModel.selectedCategory?.objectID == category.objectID)) ? 0 : 1))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    isClipboardSelected = false
                                    isFavoritesSelected = false
                                    viewModel.selectCategory(category)
                                }
                                .contextMenu {
                                    Button("重命名") {
                                        renamingCategory = category
                                        newCategoryName = category.name ?? ""
                                    }
                                    Button("删除", role: .destructive) {
                                        viewModel.categoryVM.deleteCategory(category)
                                        if viewModel.selectedCategory?.objectID == category.objectID {
                                            viewModel.selectedCategory = viewModel.categoryVM.categories.first
                                            if let first = viewModel.selectedCategory { viewModel.commandVM.fetchCommands(for: first) }
                                        }
                                    }
                                }
                        },
                        onMove: { from, to in
                            withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                                viewModel.categoryVM.forceMoveCategory(from: from, to: to)
                            }
                        }
                    )

                    // 新建分类按钮
                    Button {
                        let name = "新建分类"
                        viewModel.categoryVM.createCategory(name: name)
                        viewModel.categoryVM.fetchCategories()
                        if let created = viewModel.categoryVM.categories.first(where: { $0.name == name }) {
                            isClipboardSelected = false
                            viewModel.selectCategory(created)
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .padding(6)
                            .background(Circle().stroke(Color(NSColor.separatorColor), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
                .animation(.interpolatingSpring(stiffness: 300, damping: 25), value: viewModel.categoryVM.categories)
            }

            Spacer(minLength: 8)

            // 右侧：搜索图标 / 搜索框（默认隐藏，点击图标展开）
            if isSearching {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField(isClipboardSelected ? "搜索剪贴板（文本/链接）" : (isFavoritesSelected ? "搜索收藏（名称/内容）" : "搜索命令（名称/内容)"), text: $searchText)
                        .textFieldStyle(.plain)
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSearching = false
                            searchText = ""
                            viewModel.searchText = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(8)
                .frame(width: 260)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.textBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(NSColor.separatorColor), lineWidth: 1))
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isSearching = true }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .regular))
                        .padding(8)
                        .background(Circle().fill(Color(NSColor.controlBackgroundColor)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Spacer()
            Button {
                if let cat = viewModel.selectedCategory {
                    EditorWindowController.shared.presentNewCommand(category: cat, commandViewModel: viewModel.commandVM)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 14))
                    Text("新建命令").font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().stroke(Color.gray.opacity(0.6), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - 剪贴板卡片

private struct ClipboardShelfCard: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // 图标层（在文字下一层）：文本类置于下方，图片类置于上方
            if isTextBased() {
                appIconView
            }

            // 内容层
            VStack(alignment: .leading, spacing: 6) {
                switch item.type ?? "text" {
                case "image":
                    if let data = item.data, let img = NSImage(data: data) {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 220, height: 120)
                            .clipped()
                    } else {
                        placeholder("<image>")
                    }
                case "file":
                    HStack(alignment: .center, spacing: 10) {
                        if let data = item.data, let icon = NSImage(data: data) {
                            Image(nsImage: icon).resizable().frame(width: 40, height: 40)
                        }
                        Text(fileName(from: item.content))
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(width: 220, height: 120, alignment: .leading)
                case "html":
                    textPreview(item.content ?? "<html>")
                case "rtf":
                    textPreview(item.content ?? "<rtf>")
                case "url":
                    textPreview(item.content ?? "")
                default:
                    textPreview(item.content ?? "")
                }
                // 来源 App 名称（文本类）
                if let name = item.sourceAppName, isTextBased() {
                    Text(name)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // 图标层（在图片类时置于上方）
            if !isTextBased() {
                appIconView
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button("复制") { onCopy() }
            Button("删除", role: .destructive) { onDelete() }
        }
        .onTapGesture { onCopy() }
    }

    private var appIconView: some View {
        Group {
            if let iconData = item.sourceAppIcon, let icon = NSImage(data: iconData) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .padding(6)    // 右下内边距
            }
        }
    }

    private func isTextBased() -> Bool {
        (item.type ?? "text") != "image"
    }

    private func textPreview(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(5)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 220, height: 120, alignment: .topLeading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func placeholder(_ title: String) -> some View {
        VStack {
            Spacer()
            Text(title).foregroundColor(.secondary)
            Spacer()
        }
        .frame(width: 220, height: 120)
    }

    private func fileName(from content: String?) -> String {
        guard let s = content, let url = URL(string: s) else { return content ?? "<file>" }
        return url.lastPathComponent
    }
}

// MARK: - 拖拽排序（仅在非搜索状态启用）

final class ShelfDragState: ObservableObject {
    static let shared = ShelfDragState()
    @Published var draggingId: UUID?
}

// 顶部标签拖拽状态
final class ShelfTabDragState: ObservableObject {
    static let shared = ShelfTabDragState()
    @Published var draggingId: UUID?
}

// 顶部标签的 DropDelegate：当拖拽进入目标标签时，实时移动元素，形成“跟手”效果
private struct TabDropDelegate: DropDelegate {
    let target: Category
    @Binding var categories: [Category]
    @ObservedObject var dragState: ShelfTabDragState
    let moveAction: (_ from: Int, _ to: Int) -> Void

    func performDrop(info: DropInfo) -> Bool { true }

    func dropEntered(info: DropInfo) {
        guard let draggedId = dragState.draggingId,
              let fromIndex = categories.firstIndex(where: { $0.id == draggedId }),
              let toIndex = categories.firstIndex(where: { $0.objectID == target.objectID }),
              fromIndex != toIndex else { return }
        moveAction(fromIndex, toIndex)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

private struct CommandDropDelegate: DropDelegate {
    let item: Command
    @Binding var items: [Command]
    let filteredItems: [Command]
    @ObservedObject var dragState: ShelfDragState
    let moveAction: (_ from: Int, _ to: Int) -> Void

    func performDrop(info: DropInfo) -> Bool {
        // 在 onDrop 阶段已处理重排
        return true
    }

    func dropEntered(info: DropInfo) {
        // 仅在无过滤时允许排序
        guard filteredItems.count == items.count else { return }
        guard let draggedId = dragState.draggingId,
              let fromIndex = items.firstIndex(where: { $0.id == draggedId }) else { return }
        guard let toIndex = items.firstIndex(where: { $0.objectID == item.objectID }) else { return }
        if fromIndex != toIndex {
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                moveAction(fromIndex, toIndex)
            }
        }
    }

    func dropExited(info: DropInfo) { }
}
