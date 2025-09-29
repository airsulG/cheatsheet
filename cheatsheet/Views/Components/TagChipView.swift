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

    init(title: String,
         isSelected: Bool,
         isDraggable: Bool = false,
         onTap: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.isDraggable = isDraggable
        self.onTap = onTap
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
            .help(isDraggable ? "可拖拽以排序" : "")
    }
}

