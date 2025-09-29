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

            VStack(spacing: 6) {
                headerBar
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                Divider().opacity(0.3)

                // 卡片区域（横向滚动）
                GeometryReader { proxy in
                    // 高度策略：最小 180，最大 380，底部保留 12pt 呼吸感
                    let paddingV: CGFloat = 8
                    let bottomGutter: CGFloat = 12
                    let cardMinHeight: CGFloat = 180
                    let cardMaxHeight: CGFloat = 380

                    let available = max(cardMinHeight, proxy.size.height - paddingV)
                    let cardHeight = min(max(available - bottomGutter, cardMinHeight), cardMaxHeight)
                    ScrollView(.horizontal, showsIndicators: true) {
                    topAligned {
                    if isClipboardSelected {
                        // 剪贴板（行容器顶对齐，且不拉升高度）
                        LazyHStack(alignment: .top, spacing: cardSpacing) {
                            ForEach(viewModel.pagedClipboardVM.items.filter { item in
                                let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !q.isEmpty else { return true }
                                let type = item.type ?? ""
                                let content = item.content ?? ""
                                return type.localizedCaseInsensitiveContains(q) || content.localizedCaseInsensitiveContains(q)
                            }, id: \.id) { item in
                                ClipboardShelfCard(item: item, cardHeight: cardHeight) {
                                    let success = viewModel.pagedClipboardVM.copyItem(item)
                                    if success {
                                        viewModel.showCopyToast = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { viewModel.showCopyToast = false }
                                    }
                                    // 复制后自动关闭横条窗口
                                    ShelfWindowController.shared.hide()
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
                                        subtitle: adaptiveSubtitle(from: cmd.content ?? ""),
                                        onTap: {
                                            viewModel.commandVM.copyCommand(cmd)
                                            if viewModel.commandVM.showCopyToast { viewModel.showToast() }
                                            // 复制后自动关闭横条窗口
                                            ShelfWindowController.shared.hide()
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
                                        isFavorite: cmd.isFavorite,
                                        cardHeight: cardHeight
                                    )
                                },
                                onMove: { from, to in
                                    viewModel.moveFavorite(from: from, to: to)
                                }
                            )
                        } else {
                            LazyHStack(alignment: .top, spacing: cardSpacing) {
                                ForEach(viewModel.favorites.filter { cmd in
                                    return (cmd.name ?? "").localizedCaseInsensitiveContains(fq) ||
                                           (cmd.content ?? "").localizedCaseInsensitiveContains(fq)
                                }, id: \.id) { cmd in
                                    ShelfCardView(
                                        title: cmd.name ?? "",
                                        subtitle: adaptiveSubtitle(from: cmd.content ?? ""),
                                        onTap: {
                                            viewModel.commandVM.copyCommand(cmd)
                                            if viewModel.commandVM.showCopyToast { viewModel.showToast() }
                                            // 复制后自动关闭横条窗口
                                            ShelfWindowController.shared.hide()
                                        },
                                        onEdit: { EditorWindowController.shared.presentCommandEdit(command: cmd, commandViewModel: viewModel.commandVM) },
                                        onDelete: { viewModel.commandVM.deleteCommand(cmd); viewModel.fetchFavorites() },
                                        onToggleFavorite: { viewModel.toggleFavorite(cmd) },
                                        isFavorite: cmd.isFavorite,
                                        cardHeight: cardHeight
                                    )
                                }
                            }
                        }
                    } else {
                        // 当前分类中的命令（DragGesture 重排，仅在搜索为空时）
                        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if q.isEmpty {
                            HStack(alignment: .top, spacing: cardSpacing) {
                                ReorderableHStack(
                                    items: viewModel.commandVM.commands,
                                    id: \.id,
                                    spacing: cardSpacing,
                                    content: { cmd in
                                        ShelfCardView(
                                            title: cmd.name ?? "",
                                            subtitle: adaptiveSubtitle(from: cmd.content ?? ""),
                                            onTap: {
                                                viewModel.commandVM.copyCommand(cmd)
                                                if viewModel.commandVM.showCopyToast { viewModel.showToast() }
                                                // 复制后自动关闭横条窗口
                                                ShelfWindowController.shared.hide()
                                            },
                                            onEdit: {
                                                EditorWindowController.shared.presentCommandEdit(command: cmd, commandViewModel: viewModel.commandVM)
                                            },
                                            onDelete: { viewModel.commandVM.deleteCommand(cmd) },
                                            onToggleFavorite: { viewModel.toggleFavorite(cmd) },
                                            isFavorite: cmd.isFavorite,
                                            cardHeight: cardHeight
                                        )
                                    },
                                    onMove: { from, to in
                                        viewModel.commandVM.moveCommand(from: from, to: to)
                                    }
                                )
                                // 新建命令卡片（标题/正文为空白）置于最右侧
                                AddCommandCard(cardHeight: cardHeight) {
                                    if let cat = viewModel.selectedCategory {
                                        EditorWindowController.shared.presentNewCommand(category: cat, commandViewModel: viewModel.commandVM)
                                    }
                                }
                            }
                        } else {
                            HStack(alignment: .top, spacing: cardSpacing) {
                                LazyHStack(alignment: .top, spacing: cardSpacing) {
                                    ForEach(viewModel.filteredCommands, id: \.id) { cmd in
                                        ShelfCardView(
                                            title: cmd.name ?? "",
                                            subtitle: adaptiveSubtitle(from: cmd.content ?? ""),
                                            onTap: {
                                                viewModel.commandVM.copyCommand(cmd)
                                                if viewModel.commandVM.showCopyToast { viewModel.showToast() }
                                                // 复制后自动关闭横条窗口
                                                ShelfWindowController.shared.hide()
                                            },
                                            onEdit: {
                                                EditorWindowController.shared.presentCommandEdit(command: cmd, commandViewModel: viewModel.commandVM)
                                            },
                                            onDelete: { viewModel.commandVM.deleteCommand(cmd) },
                                            onToggleFavorite: { viewModel.toggleFavorite(cmd) },
                                            isFavorite: cmd.isFavorite,
                                            cardHeight: cardHeight
                                        )
                                    }
                                }
                                // 新建命令卡片置于最右侧
                                AddCommandCard(cardHeight: cardHeight) {
                                    if let cat = viewModel.selectedCategory {
                                        EditorWindowController.shared.presentNewCommand(category: cat, commandViewModel: viewModel.commandVM)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 4)
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)
                .animation(.interpolatingSpring(stiffness: 220, damping: 22), value: appeared)
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
        // 新建命令入口改为左侧“新建命令卡片”（不再使用底部条）
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

        // 结束 body 视图
    }

    private var headerBar: some View {
        HStack(spacing: 8) {
            // 左侧：统一标签条
            TagStripView(
                items: buildTagItems(),
                isSelected: { item in
                    switch item {
                    case .clipboard: return isClipboardSelected
                    case .favorites: return isFavoritesSelected
                    case .category(let cat):
                        return (!isClipboardSelected) && (!isFavoritesSelected) && (viewModel.selectedCategory?.objectID == cat.objectID)
                    }
                },
                onTap: { item in
                    switch item {
                    case .clipboard:
                        isClipboardSelected = true
                        isFavoritesSelected = false
                        viewModel.clearSelection()
                    case .favorites:
                        isFavoritesSelected = true
                        isClipboardSelected = false
                        viewModel.clearSelection()
                        viewModel.fetchFavorites()
                    case .category(let cat):
                        isClipboardSelected = false
                        isFavoritesSelected = false
                        viewModel.selectCategory(cat)
                    }
                },
                onMoveCategory: { from, to in
                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                        viewModel.categoryVM.forceMoveCategory(from: from, to: to)
                    }
                }
            )
            .animation(.interpolatingSpring(stiffness: 300, damping: 25), value: viewModel.categoryVM.categories)

            // 新建分类按钮（与标签条保持同一视觉层级）
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

            Spacer(minLength: 4)

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
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { isSearching = true }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .regular))
                            .padding(8)
                            .background(Circle().fill(Color(NSColor.controlBackgroundColor)))
                    }
                    .buttonStyle(.plain)

                    // 品牌徽章：仅在搜索未展开时显示，避免与标签条重叠
                    brandBadge
                }
            }
        }
    }

}

// MARK: - 品牌徽章（位于 headerBar 右侧，避免与标签条重叠）
private extension ShelfView {
    var brandBadge: some View {
        HStack(spacing: 6) {
            Image("iconImage")
                .resizable()
                .frame(width: 16, height: 16)
                .cornerRadius(3)
            Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "CheatHub")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(Capsule().stroke(Color(NSColor.separatorColor), lineWidth: 0.5))
        )
        .help("CheatHub")
    }
}

// 已移除底部操作条，改为左侧“新建命令”卡片

// MARK: - 新建命令卡片（标题/正文留白，点击打开编辑窗口）
private struct AddCommandCard: View {
    let cardHeight: CGFloat
    let onTap: () -> Void

    var body: some View {
        ZStack {
            // 留白内容区域（与普通卡片相同尺寸）
            VStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(.secondary)
                Text("添加命令")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(width: 260, height: cardHeight)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 4)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .help("添加命令")
    }
}

// MARK: - 剪贴板卡片

private struct ClipboardShelfCard: View {
    let item: ClipboardItem
    let cardHeight: CGFloat
    let onCopy: () -> Void
    let onDelete: () -> Void

    var body: some View {
        CardContainer(containerHeight: cardHeight) {
            // Header：类型胶囊 + 来源应用名（如有）
            HStack(spacing: 6) {
                typeChip
                if let name = item.sourceAppName, !name.isEmpty {
                    Text(name)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
        } content: {
            ZStack(alignment: .bottomTrailing) {
                // 内容层
                switch item.type ?? "text" {
                case "image":
                    if let data = item.data, let img = NSImage(data: data) {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                    } else {
                        placeholder("<image>")
                    }
                case "file":
                    HStack(alignment: .center, spacing: 10) {
                        if let data = item.data, let icon = NSImage(data: data) {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 40, height: 40)
                        }
                        Text(fileName(from: item.content))
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                case "html":
                    textPreview(item.content ?? "<html>")
                case "rtf":
                    textPreview(item.content ?? "<rtf>")
                case "url":
                    textPreview(item.content ?? "")
                default:
                    textPreview(item.content ?? "")
                }

                // 右下角来源图标（如有）
                appIconView
            }
        }
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
                    .interpolation(.high)
                    .antialiased(true)
                    .frame(width: 48, height: 48)
                    .padding(8)    // 放大后相应增大边距，避免贴边
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5)
                    )
            }
        }
    }

    private func isTextBased() -> Bool { (item.type ?? "text") != "image" }

    private func textPreview(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(nil)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func placeholder(_ title: String) -> some View {
        VStack {
            Spacer()
            Text(title).foregroundColor(.secondary)
            Spacer()
        }
        .frame(width: 260, height: cardHeight)
    }

    private func fileName(from content: String?) -> String {
        guard let s = content, let url = URL(string: s) else { return content ?? "<file>" }
        return url.lastPathComponent
    }

    // MARK: - Header 辅助视图

    private var typeChip: some View {
        let label = typeDisplayName(item.type ?? "text")
        return Text(label)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color(NSColor.controlBackgroundColor)))
            .overlay(Capsule().stroke(Color(NSColor.separatorColor), lineWidth: 0.5))
    }

    private func typeDisplayName(_ type: String) -> String {
        switch type.lowercased() {
        case "text": return "文本"
        case "url": return "URL"
        case "image": return "图片"
        case "file": return "文件"
        case "html": return "HTML"
        case "rtf": return "RTF"
        default: return type.uppercased()
        }
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

// MARK: - 顶对齐包装（确保分隔线→卡片距离稳定）
private func topAligned<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    VStack(spacing: 0) {
        content()
        Spacer(minLength: 0)
    }
    .frame(maxHeight: .infinity, alignment: .topLeading)
}

// MARK: - 标签数据构建
private extension ShelfView {
    func buildTagItems() -> [TagItem] {
        var items: [TagItem] = [.clipboard, .favorites]
        items.append(contentsOf: viewModel.categoryVM.categories.map { .category($0) })
        return items
    }
}

// MARK: - 自适应摘要（按字符数与输入行数，尽量在空白/标点处截断）
private func adaptiveSubtitle(from content: String,
                              targetChars: Int = 160,
                              maxLines: Int = 4) -> String {
    let lines = content
        .replacingOccurrences(of: "\r\n", with: "\n")
        .components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }

    guard !lines.isEmpty else { return "" }

    var acc = ""
    var usedLines = 0

    for line in lines {
        let candidate = acc.isEmpty ? line : (acc + "\n" + line)
        if candidate.count <= targetChars && usedLines + 1 <= maxLines {
            acc = candidate
            usedLines += 1
        } else {
            break
        }
    }

    if acc.isEmpty {
        acc = lines.first ?? ""
    }

    // 未超长直接返回
    if acc.count <= targetChars { return acc }

    // 超长：尽量在空白/标点处截断
    let cutset = CharacterSet(charactersIn: " ，。,.;；:：、!！?？|/\\-–—_")
    let cutoff = min(targetChars, acc.count)
    var idx = acc.index(acc.startIndex, offsetBy: cutoff)
    var best = idx

    while idx > acc.startIndex {
        let prev = acc.index(before: idx)
        if String(acc[prev]).rangeOfCharacter(from: cutset) != nil {
            best = prev
            break
        }
        idx = prev
    }

    let head = String(acc[..<best]).trimmingCharacters(in: .whitespacesAndNewlines)
    return head + "…"
}
