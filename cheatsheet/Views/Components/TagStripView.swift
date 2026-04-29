//
//  TagStripView.swift
//  cheatsheet
//
//  统一标签容器：将“剪贴板/收藏/分类”统一在同一容器内；
//  仅分类标签可拖拽排序，剪贴板/收藏为静态项。
//

import SwiftUI

enum TagItem: Hashable {
    case clipboard
    case favorites
    case category(Category)

    var id: AnyHashable {
        switch self {
        case .clipboard: return AnyHashable("__clipboard__")
        case .favorites: return AnyHashable("__favorites__")
        case .category(let cat): return AnyHashable(cat.id ?? UUID())
        }
    }

    var title: String {
        switch self {
        case .clipboard: return "剪贴板"
        case .favorites: return "收藏"
        case .category(let cat): return cat.name ?? "未命名"
        }
    }

    var isDraggable: Bool {
        if case .category(_) = self { return true }
        return false
    }
}

struct TagStripView: View {
    let items: [TagItem]
    let isSelected: (TagItem) -> Bool
    let onTap: (TagItem) -> Void
    let onMoveCategory: (_ from: Int, _ to: Int) -> Void
    let onRenameCategory: ((Category) -> Void)?  // 新增：重命名回调
    let onDeleteCategory: ((Category) -> Void)?  // 新增：删除回调

    @State private var draggingKey: AnyHashable? = nil
    @State private var dragTranslation: CGFloat = 0
    @State private var frames: [AnyHashable: CGRect] = [:]

    private let spacing: CGFloat = 8
    private let coordSpace = "tag-strip"

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing) {
                ForEach(items, id: \.id) { item in
                    TagChipView(
                        title: item.title,
                        isSelected: isSelected(item),
                        isDraggable: item.isDraggable,
                        onTap: { onTap(item) },
                        contextMenuBuilder: item.isDraggable ? {  // 只有分类标签才有菜单
                            categoryContextMenu(for: item)
                        } : nil
                    )
                    .background(GeometryReader { geo in
                        Color.clear.preference(key: FramesPrefKey.self, value: [item.id: geo.frame(in: .named(coordSpace))])
                    })
                    .zIndex(draggingKey == item.id ? 1 : 0)
                    .offset(x: draggingKey == item.id ? dragTranslation : 0, y: 0)
                    .scaleEffect(draggingKey == item.id ? 1.04 : 1.0)
                    .shadow(color: Color.black.opacity(draggingKey == item.id ? 0.2 : 0.0), radius: draggingKey == item.id ? 10 : 0, x: 0, y: draggingKey == item.id ? 6 : 0)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard item.isDraggable else { return }
                                if draggingKey == nil { draggingKey = item.id }
                                dragTranslation = value.translation.width
                                updateReorder(for: item.id)
                            }
                            .onEnded { _ in
                                draggingKey = nil
                                dragTranslation = 0
                            }
                    )
                }
            }
            .padding(.vertical, 4)
        }
        .coordinateSpace(name: coordSpace)
        .onPreferenceChange(FramesPrefKey.self) { newValue in
            frames.merge(newValue, uniquingKeysWith: { _, new in new })
        }
    }

    private func updateReorder(for draggedKey: AnyHashable) {
        guard let draggedItem = items.first(where: { $0.id == draggedKey }), draggedItem.isDraggable else { return }
        guard let draggedFrame = frames[draggedKey] else { return }

        // 只在“分类”区域内重排：基于分类项的中心点计算目标位置
        let categoryItems: [TagItem] = items.compactMap { if case .category(_) = $0 { return $0 } else { return nil } }
        let centers: [(AnyHashable, CGFloat)] = categoryItems.compactMap { item in
            if let f = frames[item.id] { return (item.id, f.midX) }
            return nil
        }.sorted { $0.1 < $1.1 }

        let draggedCenterX = draggedFrame.midX + dragTranslation
        var targetIndex = 0
        for (idx, pair) in centers.enumerated() { if draggedCenterX > pair.1 { targetIndex = idx + 1 } }

        guard let fromIndex = categoryItems.firstIndex(where: { $0.id == draggedKey }) else { return }
        if targetIndex != fromIndex {
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                onMoveCategory(fromIndex, targetIndex)
            }
        }
    }
    
    // 构建分类标签的右键菜单
    @ViewBuilder
    private func categoryContextMenu(for item: TagItem) -> AnyView {
        if case .category(let category) = item {
            return AnyView(
                Group {
                    Button("重命名") {
                        onRenameCategory?(category)
                    }
                    
                    Divider()
                    
                    Button("删除", role: .destructive) {
                        onDeleteCategory?(category)
                    }
                }
            )
        }
        return AnyView(EmptyView())
    }
}

private struct FramesPrefKey: PreferenceKey {
    static var defaultValue: [AnyHashable: CGRect] = [:]
    static func reduce(value: inout [AnyHashable: CGRect], nextValue: () -> [AnyHashable: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

