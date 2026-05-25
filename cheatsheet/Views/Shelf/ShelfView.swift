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
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    @State private var showingAddCommandSheet = false
    @State private var renamingCategory: Category? = nil
    @State private var newCategoryName: String = ""
    @State private var searchText: String = ""
    /// 上次用户选中的 tab，跨 panel 生命周期持久化。
    /// 取值："clipboard" | "favorites" | category-uuid。第一次启动默认进剪贴板。
    @AppStorage("shelfLastTab") private var shelfLastTabRaw: String = "clipboard"
    private var isClipboardSelected: Bool { shelfLastTabRaw == "clipboard" }
    private var isFavoritesSelected: Bool { shelfLastTabRaw == "favorites" }
    @State private var isSearching: Bool = false
    @State private var showingAddCategoryAlert = false  // 新增：新建分类对话框
    @State private var newAddCategoryName: String = ""  // 新增：新建分类名称
    @State private var showingDeleteCategoryAlert = false  // 新增：删除分类确认
    @State private var deletingCategory: Category? = nil   // 新增：待删除的分类
    @AppStorage(ShelfCardSortSettings.storageKey) private var shelfCardSortModeRaw: String = ShelfCardSortMode.manual.rawValue

    private let cardSpacing: CGFloat = 12
    @StateObject private var dragState = ShelfDragState.shared
    @StateObject private var tabDragState = ShelfTabDragState.shared
    @State private var shelfResizeStartHeight: CGFloat?
    @Namespace private var glassNS
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        // 方案 1：整片矩形玻璃由外层容器统一承担；根据辅助功能判断降级
        let shouldReduceTransparency: Bool = {
            let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
            let incContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
            return reduce || incContrast || (colorSchemeContrast == .increased)
        }()

        return ZStack {
            // 背景采用液态玻璃（macOS 26+），老系统自动回退为磨砂玻璃
            GlassBackground()

            VStack(spacing: 6) {
                headerBar
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                // A2：弱化分隔线，采用低对比度描边
                Rectangle()
                    .fill(Color(NSColor.separatorColor).opacity(0.15))
                    .frame(height: 0.5)

                // 卡片区域（横向滚动）
                GeometryReader { proxy in
                    // 高度策略：跟随面板高度增长，底部保留 12pt 呼吸感。
                    let paddingV: CGFloat = 8
                    let bottomGutter: CGFloat = 12
                    let cardMinHeight: CGFloat = 180
                    let cardMaxHeight: CGFloat = ShelfPanelHeightSettings.maxHeight - 92

                    let available = max(cardMinHeight, proxy.size.height - paddingV)
                    let cardHeight = min(max(available - bottomGutter, cardMinHeight), cardMaxHeight)

                    ScrollView(.horizontal, showsIndicators: true) {
                        topAligned {
                            Group {
                                if isClipboardSelected {
                                    // 剪贴板（行容器顶对齐，且不拉升高度）
                                    LazyHStack(alignment: .top, spacing: cardSpacing) {
                                        if viewModel.pagedClipboardVM.previewItems.isEmpty,
                                           viewModel.pagedClipboardVM.isPreviewLoading {
                                            clipboardLoadingCard(cardHeight: cardHeight)
                                        }

                                        ForEach(viewModel.pagedClipboardVM.filteredPreviewItems(matching: searchText)) { item in
                                            ClipboardShelfCard(item: item, cardHeight: cardHeight) {
                                                let success = viewModel.pagedClipboardVM.copyPreviewItem(item)
                                                if success {
                                                    viewModel.showCopyToast = true
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { viewModel.showCopyToast = false }
                                                }
                                                // 复制后自动关闭横条窗口
                                                ShelfWindowController.shared.hide()
                                            } onDelete: {
                                                viewModel.pagedClipboardVM.deletePreviewItem(item)
                                            }
                                            .onAppear {
                                                viewModel.pagedClipboardVM.loadNextPreviewPageIfNeeded(currentItem: item)
                                            }
                                        }

                                        if !viewModel.pagedClipboardVM.previewItems.isEmpty,
                                           viewModel.pagedClipboardVM.isPreviewLoading {
                                            clipboardLoadingCard(cardHeight: cardHeight)
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
                                            allowsReordering: currentSortMode == .manual,
                                            content: { cmd in
                                                ShelfCardView(
                                                    title: cmd.name ?? "",
                                                    subtitle: adaptiveSubtitle(from: cmd.content ?? "", cardHeight: cardHeight),
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
                                                    cardHeight: cardHeight,
                                                    availableCategories: viewModel.categoryVM.categories,  // 新增
                                                    onMoveTo: { category in  // 新增
                                                        viewModel.commandVM.moveCommand(cmd, to: category)
                                                        viewModel.fetchFavorites()
                                                    }
                                                )
                                            },
                                            onSwap: { from, to in
                                                viewModel.swapFavoritePositions(from: from, to: to)
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
                                                    subtitle: adaptiveSubtitle(from: cmd.content ?? "", cardHeight: cardHeight),
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
                                                    cardHeight: cardHeight,
                                                    availableCategories: viewModel.categoryVM.categories,  // 新增
                                                    onMoveTo: { category in  // 新增
                                                        viewModel.commandVM.moveCommand(cmd, to: category)
                                                        viewModel.fetchFavorites()
                                                    }
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
                                                allowsReordering: currentSortMode == .manual,
                                                content: { cmd in
                                                    ShelfCardView(
                                                        title: cmd.name ?? "",
                                                        subtitle: adaptiveSubtitle(from: cmd.content ?? "", cardHeight: cardHeight),
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
                                                        cardHeight: cardHeight,
                                                        availableCategories: viewModel.categoryVM.categories.filter { $0.objectID != viewModel.selectedCategory?.objectID },  // 新增：排除当前分类
                                                        onMoveTo: { category in  // 新增
                                                            viewModel.commandVM.moveCommand(cmd, to: category)
                                                        }
                                                    )
                                                },
                                                onSwap: { from, to in
                                                    viewModel.commandVM.swapCommandPositions(from: from, to: to)
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
                                                        subtitle: adaptiveSubtitle(from: cmd.content ?? "", cardHeight: cardHeight),
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
                                                        cardHeight: cardHeight,
                                                        availableCategories: viewModel.categoryVM.categories.filter { $0.objectID != viewModel.selectedCategory?.objectID },  // 新增：排除当前分类
                                                        onMoveTo: { category in  // 新增
                                                            viewModel.commandVM.moveCommand(cmd, to: category)
                                                        }
                                                    )
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    // 方案 1：由外层整片矩形玻璃统一承载，内部不再局部玻璃
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 4)
            }
        }
        // 方案 1：把整条横栏（ZStack）矩形玻璃化（macOS 26+ 才启用）
        .glassEffectRectCompat(shouldReduceTransparency: shouldReduceTransparency)
        .frame(minHeight: ShelfPanelHeightSettings.minHeight)
        .overlay(
            // 顶部柔和阴影，增强与桌面边界的层次感
            VStack(spacing: 0) {
                Rectangle().fill(Color.black.opacity(0.12)).frame(height: 0.5)
                Rectangle().fill(Color.black.opacity(0.06)).frame(height: 0.5)
                Spacer()
            }
            .allowsHitTesting(false)
        )
        .overlay(alignment: .top) {
            shelfResizeHandle
        }
        .onChange(of: searchText) { _, newValue in
            viewModel.searchText = newValue
        }
        .onAppear {
            // 视图首次出现：按上次记住的 tab 立即触发对应 ViewModel 加载，
            // 让数据加载和 panel 打开动画并行。
            applyShelfLastTab()
        }
        .onChange(of: shelfLastTabRaw) { _, _ in
            applyShelfLastTab()
        }
        .onChange(of: shelfCardSortModeRaw) { _, newValue in
            ShelfCardSortSettings.mode = ShelfCardSortMode(rawValue: newValue) ?? .manual
            viewModel.applyShelfSortMode()
        }
        .onExitCommand {
            if isSearching {
                closeSearch()
            } else {
                ShelfWindowController.shared.hide()
            }
        }
        .overlay(
            Group {
                if viewModel.showCopyToast || viewModel.commandVM.showCopyToast {
                    CopyToastView()
                        .transition(.opacity.combined(with: .scale))
                        .animation(.easeInOut(duration: 0.3), value: viewModel.showCopyToast)
                }
            }
        )
        // 新建命令入口改为右侧"新建命令卡片"（不再使用底部条）
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
        .alert("新建分类", isPresented: $showingAddCategoryAlert) {
            TextField("分类名称", text: $newAddCategoryName)
            Button("取消", role: .cancel) { }
            Button("创建") {
                let name = newAddCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    viewModel.categoryVM.createCategory(name: name)
                    viewModel.categoryVM.fetchCategories()
                    if let created = viewModel.categoryVM.categories.first(where: { $0.name == name }) {
                        if let id = created.id?.uuidString {
                            shelfLastTabRaw = id
                        }
                        viewModel.selectCategory(created)
                    }
                }
            }
        } message: {
            Text("请输入分类名称")
        }
        .alert("删除分类", isPresented: $showingDeleteCategoryAlert) {
            Button("取消", role: .cancel) {
                deletingCategory = nil
            }
            Button("删除", role: .destructive) {
                if let cat = deletingCategory {
                    viewModel.categoryVM.deleteCategory(cat)
                    viewModel.categoryVM.fetchCategories()
                    // 如果删除的是当前选中的分类，切换到收藏
                    if viewModel.selectedCategory?.objectID == cat.objectID {
                        shelfLastTabRaw = "favorites"
                        viewModel.clearSelection()
                        viewModel.fetchFavorites()
                    }
                    deletingCategory = nil
                }
            }
        } message: {
            Text("确定要删除分类 \"\(deletingCategory?.name ?? "")\" 吗？\n\n此操作将同时删除该分类下的所有命令，且无法撤销。")
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
                        shelfLastTabRaw = "clipboard"
                        viewModel.clearSelection()
                    case .favorites:
                        shelfLastTabRaw = "favorites"
                        viewModel.clearSelection()
                        viewModel.fetchFavorites()
                    case .category(let cat):
                        if let id = cat.id?.uuidString {
                            shelfLastTabRaw = id
                        }
                        viewModel.selectCategory(cat)
                    }
                },
                onMoveCategory: { from, to in
                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                        viewModel.categoryVM.forceMoveCategory(from: from, to: to)
                    }
                },
                onRenameCategory: { category in  // 新增：重命名回调
                    renamingCategory = category
                    newCategoryName = category.name ?? ""
                },
                onDeleteCategory: { category in  // 新增：删除回调
                    showingDeleteCategoryAlert = true
                    deletingCategory = category
                }
            )
            .animation(.interpolatingSpring(stiffness: 300, damping: 25), value: viewModel.categoryVM.categories)

            // 新建分类按钮（与标签条保持同一视觉层级）
            Button {
                showingAddCategoryAlert = true
                newAddCategoryName = ""  // 清空输入
            } label: {
                toolbarIcon("plus")
            }
            .buttonStyle(.plain)

            Spacer(minLength: 4)

            // 右侧：搜索图标 / 搜索框（默认隐藏，点击图标展开）
            if isSearching {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    searchScopeChip
                    TextField(searchPlaceholder, text: $searchText)
                        .textFieldStyle(.plain)
                        .focused($isSearchFocused)
                    Button {
                        closeSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .keyboardShortcut(.cancelAction)
                }
                .padding(8)
                .frame(width: 320)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.textBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(NSColor.separatorColor), lineWidth: 1))
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                HStack(spacing: 8) {
                    sortToggleButton

                    Button {
                        BackupWindowController.shared.present(context: viewModel.viewContext)
                    } label: {
                        toolbarIcon("externaldrive.badge.timemachine")
                    }
                    .buttonStyle(.plain)
                    .help("备份与恢复")

                    // 剪贴板设置按钮（仅在选中剪贴板时显示）
                    if isClipboardSelected {
                        Button {
                            ClipboardSettingsWindowController.shared.present(viewModel: viewModel.pagedClipboardVM)
                        } label: {
                            toolbarIcon("gearshape")
                        }
                        .buttonStyle(.plain)
                        .help("剪贴板设置")
                    }

                    Button {
                        openSearch()
                    } label: {
                        toolbarIcon("magnifyingglass")
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("f", modifiers: [.command])

                    // 品牌徽章：仅在搜索未展开时显示，避免与标签条重叠
                    brandBadge
                }
            }
        }
    }

    private var shelfResizeHandle: some View {
        VStack(spacing: 2) {
            Capsule()
                .fill(Color.secondary.opacity(0.42))
                .frame(width: 48, height: 4)
                .padding(.top, 2)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 10)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    let startHeight = shelfResizeStartHeight ?? ShelfWindowController.shared.currentHeight()
                    if shelfResizeStartHeight == nil {
                        shelfResizeStartHeight = startHeight
                    }
                    ShelfWindowController.shared.resizeFromTopDrag(
                        startHeight: startHeight,
                        translationY: value.translation.height,
                        persist: false
                    )
                }
                .onEnded { value in
                    let startHeight = shelfResizeStartHeight ?? ShelfWindowController.shared.currentHeight()
                    ShelfWindowController.shared.resizeFromTopDrag(
                        startHeight: startHeight,
                        translationY: value.translation.height,
                        persist: true
                    )
                    shelfResizeStartHeight = nil
                }
        )
        .help("拖拽调整面板高度")
    }

    private func clipboardLoadingCard(cardHeight: CGFloat) -> some View {
        CardContainer(containerHeight: cardHeight) {
            HStack(spacing: 6) {
                Text("加载中")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
        } content: {
            VStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("正在加载剪贴板")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var searchScopeChip: some View {
        Text(searchScopeTitle)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color(NSColor.controlBackgroundColor)))
            .overlay(Capsule().stroke(Color(NSColor.separatorColor), lineWidth: 0.5))
            .fixedSize()
    }

    /// 把当前 `shelfLastTabRaw` 反映到 viewModel 的真实选择和数据加载上。
    /// 在 onAppear 与 shelfLastTabRaw 变化时各调一次：让 panel 出现的同一帧
    /// 就启动对应 tab 的数据预取，不再等用户点击。
    private func applyShelfLastTab() {
        switch shelfLastTabRaw {
        case "clipboard":
            viewModel.clearSelection()
            viewModel.pagedClipboardVM.ensurePreviewFirstPageLoaded()
        case "favorites":
            viewModel.clearSelection()
            viewModel.fetchFavorites()
        default:
            // 视为分类 UUID
            if let uuid = UUID(uuidString: shelfLastTabRaw),
               let cat = viewModel.categoryVM.categories.first(where: { $0.id == uuid }) {
                viewModel.selectCategory(cat)
            } else {
                // 找不到对应分类（首次启动 / 分类被删除）→ 回退到剪贴板并写回 AppStorage
                shelfLastTabRaw = "clipboard"
                viewModel.clearSelection()
                viewModel.pagedClipboardVM.ensurePreviewFirstPageLoaded()
            }
        }
    }

    private var searchScopeTitle: String {
        if isClipboardSelected { return "剪贴板" }
        if isFavoritesSelected { return "收藏" }
        return viewModel.selectedCategory?.name ?? "命令"
    }

    private var searchPlaceholder: String {
        if isClipboardSelected { return "搜索文本或链接" }
        if isFavoritesSelected { return "搜索名称或内容" }
        return "搜索名称或内容"
    }

    private func openSearch() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isSearching = true
        }
        DispatchQueue.main.async {
            isSearchFocused = true
        }
    }

    private func closeSearch() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isSearching = false
            searchText = ""
            viewModel.searchText = ""
            isSearchFocused = false
        }
    }

}

private extension ShelfView {
    func toolbarIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.primary)
            .padding(6)
            .background(Circle().stroke(Color(NSColor.separatorColor), lineWidth: 1))
            .contentShape(Circle())
    }

    var currentSortMode: ShelfCardSortMode {
        ShelfCardSortMode(rawValue: shelfCardSortModeRaw) ?? .manual
    }

    var nextSortMode: ShelfCardSortMode {
        currentSortMode == .manual ? .title : .manual
    }

    var sortToggleButton: some View {
        Button {
            toggleShelfSortMode()
        } label: {
            Text(currentSortMode.label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().stroke(Color(NSColor.separatorColor), lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("点击切换为\(nextSortMode.label)")
    }

    func toggleShelfSortMode() {
        shelfCardSortModeRaw = nextSortMode.rawValue
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
        .padding(.horizontal, 2)
        // 去除徽章化的背景与冗余内边距，仅保留图标与文字
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

private final class SourceAppIconCache {
    static let shared = SourceAppIconCache()

    private let cache = NSCache<NSString, NSImage>()

    private init() {}

    func image(for data: Data?, cacheKey: String?) -> NSImage? {
        guard let data, let cacheKey else { return nil }

        let key = cacheKey as NSString
        if let image = cache.object(forKey: key) {
            return image
        }

        guard let image = NSImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}

private struct ClipboardShelfCard: View {
    let item: ClipboardPreviewItem
    let cardHeight: CGFloat
    let onCopy: () -> Void
    let onDelete: () -> Void

    var body: some View {
        CardContainer(containerHeight: cardHeight) {
            // Header：来源 App + 类型
            HStack(spacing: 6) {
                sourceAppIconView
                if let name = item.sourceAppName, !name.isEmpty {
                    Text(name)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer()
                typeChip
            }
        } content: {
            ZStack(alignment: .bottomTrailing) {
                // 内容层
                switch item.type {
                case "image":
                    if let data = item.imageData, let img = NSImage(data: data) {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        placeholder("<image>")
                    }
                case "file":
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: "doc")
                            .font(.system(size: 32, weight: .regular))
                            .foregroundColor(.secondary)
                        Text(item.contentPreview)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                default:
                    textPreview(item.contentPreview)
                }
            }
        }
        .contextMenu {
            Button("复制") { onCopy() }
            Button("删除", role: .destructive) { onDelete() }
        }
        .onTapGesture { onCopy() }
    }

    private func textPreview(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(textPreviewLineLimit)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var textPreviewLineLimit: Int {
        let contentHeight = max(0, cardHeight - 54)
        let estimatedLineHeight: CGFloat = 18
        let lines = Int(contentHeight / estimatedLineHeight)
        return min(max(lines, 10), 34)
    }

    private func placeholder(_ title: String) -> some View {
        VStack {
            Spacer()
            Text(title).foregroundColor(.secondary)
            Spacer()
        }
        .frame(width: 260, height: cardHeight)
    }

    // MARK: - Header 辅助视图

    private var sourceAppIconView: some View {
        Group {
            if let image = SourceAppIconCache.shared.image(
                for: item.sourceAppIconData,
                cacheKey: item.sourceAppIconCacheKey
            ) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(3)
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 16, height: 16)
    }

    private var typeChip: some View {
        let label = typeDisplayName(item.type)
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
                              cardHeight: CGFloat,
                              baseChars: Int = 160,
                              baseLines: Int = 4) -> String {
    let extraHeight = max(0, cardHeight - 180)
    let targetChars = min(1_200, baseChars + Int(extraHeight * 3.2))
    let maxLines = min(24, baseLines + Int(extraHeight / 28))

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
