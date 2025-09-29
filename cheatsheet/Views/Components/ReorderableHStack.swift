//
//  ReorderableHStack.swift
//  cheatsheet
//
//  Created by Codex on 2025/8/28.
//

import SwiftUI

// 通用的可重排横向容器：使用 DragGesture 实现“只有一张卡片跟手”的重排效果
struct ReorderableHStack<Item, ID: Hashable, Content: View>: View {
    let items: [Item]
    let id: KeyPath<Item, ID>
    let spacing: CGFloat
    let content: (Item) -> Content
    let onMove: (_ from: Int, _ to: Int) -> Void

    @State private var draggingKey: AnyHashable? = nil
    @State private var dragTranslation: CGFloat = 0
    @State private var frames: [AnyHashable: CGRect] = [:]

    private let coordSpace = "reorder-hstack"

    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(items, id: id) { item in
                let itemKey: AnyHashable = AnyHashable(item[keyPath: id])
                content(item)
                    .background(GeometryReader { geo in
                        Color.clear
                            .preference(key: ItemFramesPrefKey.self,
                                        value: [itemKey: geo.frame(in: .named(coordSpace))])
                    })
                    .zIndex(draggingKey == itemKey ? 1 : 0)
                    .offset(x: draggingKey == itemKey ? dragTranslation : 0, y: 0)
                    .scaleEffect(draggingKey == itemKey ? 1.04 : 1.0)
                    .shadow(color: Color.black.opacity(draggingKey == itemKey ? 0.2 : 0.12),
                            radius: draggingKey == itemKey ? 10 : 6, x: 0, y: draggingKey == itemKey ? 6 : 4)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if draggingKey == nil { draggingKey = itemKey }
                                dragTranslation = value.translation.width
                                updateReorder(for: itemKey)
                            }
                            .onEnded { _ in
                                draggingKey = nil
                                dragTranslation = 0
                            }
                    )
            }
        }
        .coordinateSpace(name: coordSpace)
        .onPreferenceChange(ItemFramesPrefKey.self) { newValue in
            // 合并多次布局采集的 frame
            frames.merge(newValue, uniquingKeysWith: { _, new in new })
        }
    }

    private func updateReorder(for draggedKey: AnyHashable) {
        guard let draggedFrame = frames[draggedKey] else { return }
        let draggedCenterX = draggedFrame.midX + dragTranslation

        // 当前按布局位置排序的 id 列表
        let centers: [(AnyHashable, CGFloat)] = items.compactMap { item in
            let key: AnyHashable = AnyHashable(item[keyPath: id])
            if let f = frames[key] { return (key, f.midX) }
            return nil
        }.sorted { $0.1 < $1.1 }

        // 拖拽中心落在第几个位置
        var targetIndex = 0
        for (idx, pair) in centers.enumerated() {
            if draggedCenterX > pair.1 { targetIndex = idx + 1 }
        }

        guard let fromIndex = items.firstIndex(where: { AnyHashable($0[keyPath: id]) == draggedKey }) else { return }
        if targetIndex != fromIndex {
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                onMove(fromIndex, targetIndex)
            }
        }
    }
}

private struct ItemFramesPrefKey: PreferenceKey {
    static var defaultValue: [AnyHashable: CGRect] = [:]
    static func reduce(value: inout [AnyHashable: CGRect], nextValue: () -> [AnyHashable: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
