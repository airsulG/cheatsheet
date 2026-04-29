//
//  TagChipView.swift
//  cheatsheet
//
//  统一的标签胶囊风格视图（剪贴板/收藏/分类通用）
//

import SwiftUI

struct TagChipView: View {
    let title: String
    let isSelected: Bool
    let isDraggable: Bool
    let onTap: () -> Void
    let contextMenuBuilder: (() -> AnyView)?  // 新增：右键菜单构建器

    init(title: String,
         isSelected: Bool,
         isDraggable: Bool = false,
         onTap: @escaping () -> Void,
         contextMenuBuilder: (() -> AnyView)? = nil) {  // 新增可选参数
        self.title = title
        self.isSelected = isSelected
        self.isDraggable = isDraggable
        self.onTap = onTap
        self.contextMenuBuilder = contextMenuBuilder
    }

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor)))
            .overlay(Capsule().stroke(Color(NSColor.separatorColor), lineWidth: isSelected ? 0 : 1))
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
            .if(contextMenuBuilder != nil) { view in  // 条件添加 contextMenu
                view.contextMenu {
                    contextMenuBuilder?() ?? AnyView(EmptyView())
                }
            }
            .help(isDraggable ? "可拖拽以排序" : "")
    }
}

// 辅助扩展：条件修饰符
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

