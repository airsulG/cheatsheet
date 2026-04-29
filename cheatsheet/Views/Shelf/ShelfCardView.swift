//
//  ShelfCardView.swift
//  cheatsheet
//
//  Created by Codex on 2025/8/28.
//

import SwiftUI

struct ShelfCardView: View {
    let title: String
    let subtitle: String
    let onTap: () -> Void
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    let onToggleFavorite: (() -> Void)?
    let isFavorite: Bool?
    let cardHeight: CGFloat?
    let availableCategories: [Category]?  // 新增：可用分类列表
    let onMoveTo: ((Category) -> Void)?   // 新增：移动到分类回调

    init(title: String,
         subtitle: String,
         onTap: @escaping () -> Void,
         onEdit: (() -> Void)? = nil,
         onDelete: (() -> Void)? = nil,
         onToggleFavorite: (() -> Void)? = nil,
         isFavorite: Bool? = nil,
         cardHeight: CGFloat? = nil,
         availableCategories: [Category]? = nil,  // 新增可选参数
         onMoveTo: ((Category) -> Void)? = nil) { // 新增可选参数
        self.title = title
        self.subtitle = subtitle
        self.onTap = onTap
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onToggleFavorite = onToggleFavorite
        self.isFavorite = isFavorite
        self.cardHeight = cardHeight
        self.availableCategories = availableCategories
        self.onMoveTo = onMoveTo
    }

    var body: some View {
        CardContainer(containerHeight: cardHeight) {
            // Header：标题 + 可选收藏按钮
            HStack(spacing: 8) {
                Text(title.isEmpty ? "未命名" : title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()

                if let onToggleFavorite = onToggleFavorite, let isFavorite = isFavorite {
                    Button(action: { onToggleFavorite() }) {
                        Image(systemName: isFavorite ? "bolt.fill" : "bolt")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isFavorite ? .yellow : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        } content: {
            VStack(alignment: .leading, spacing: 4) {
                // 正文尽量多，边距更紧凑（容器已提供统一内边距）
                Text(subtitle)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onTapGesture { onTap() }
        .contextMenu {
            Button("复制") { onTap() }
            if let onEdit = onEdit {
                Button("编辑") { onEdit() }
            }
            if let onToggleFavorite = onToggleFavorite {
                Button("切换收藏") { onToggleFavorite() }
            }
            
            // 新增：移动到分类菜单
            if let categories = availableCategories, let onMoveTo = onMoveTo, !categories.isEmpty {
                Menu("移动到...") {
                    ForEach(categories, id: \.id) { category in
                        Button(category.name ?? "未命名分类") {
                            onMoveTo(category)
                        }
                    }
                }
            }
            
            if let onDelete = onDelete {
                Divider()
                Button("删除", role: .destructive) { onDelete() }
            }
        }
    }
}
