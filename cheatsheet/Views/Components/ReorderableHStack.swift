//
//  ReorderableHStack.swift
//  cheatsheet
//
//  Created by Codex on 2025/8/28.
//

import SwiftUI

// 通用的可重排横向容器：拖动时只移动当前卡片，松手后提交一次位置交换。
struct ReorderableHStack<Item, ID: Hashable, Content: View>: View {
    let items: [Item]
    let id: KeyPath<Item, ID>
    let spacing: CGFloat
    let allowsReordering: Bool
    let content: (Item) -> Content
    let onSwap: (_ from: Int, _ to: Int) -> Void

    @State private var draggingKey: AnyHashable? = nil
    @State private var dragTranslation: CGFloat = 0
    @State private var dropTargetKey: AnyHashable? = nil
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.accentColor.opacity(dropTargetKey == itemKey ? 0.55 : 0), lineWidth: 2)
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard allowsReordering else { return }
                                if draggingKey == nil { draggingKey = itemKey }
                                dragTranslation = value.translation.width
                                updateDropTarget(for: itemKey)
                            }
                            .onEnded { _ in
                                guard allowsReordering else { return }
                                commitDrop(for: itemKey)
                                draggingKey = nil
                                dragTranslation = 0
                                dropTargetKey = nil
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

    private func updateDropTarget(for draggedKey: AnyHashable) {
        dropTargetKey = targetKey(for: draggedKey)
    }

    private func commitDrop(for draggedKey: AnyHashable) {
        guard let targetKey = dropTargetKey,
              targetKey != draggedKey,
              let fromIndex = items.firstIndex(where: { AnyHashable($0[keyPath: id]) == draggedKey }),
              let toIndex = items.firstIndex(where: { AnyHashable($0[keyPath: id]) == targetKey }) else { return }

        withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
            onSwap(fromIndex, toIndex)
        }
    }

    private func targetKey(for draggedKey: AnyHashable) -> AnyHashable? {
        guard let draggedFrame = frames[draggedKey] else { return nil }
        let draggedCenterX = draggedFrame.midX + dragTranslation

        // 当前按布局位置排序的 id 列表
        let centers: [(AnyHashable, CGFloat)] = items.compactMap { item in
            let key: AnyHashable = AnyHashable(item[keyPath: id])
            if let f = frames[key] { return (key, f.midX) }
            return nil
        }
        .filter { $0.0 != draggedKey }
        .sorted { $0.1 < $1.1 }

        return centers.min { lhs, rhs in
            abs(lhs.1 - draggedCenterX) < abs(rhs.1 - draggedCenterX)
        }?.0
    }
}

private struct ItemFramesPrefKey: PreferenceKey {
    static var defaultValue: [AnyHashable: CGRect] = [:]
    static func reduce(value: inout [AnyHashable: CGRect], nextValue: () -> [AnyHashable: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
