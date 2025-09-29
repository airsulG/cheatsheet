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

    init(title: String,
         subtitle: String,
         onTap: @escaping () -> Void,
         onEdit: (() -> Void)? = nil,
         onDelete: (() -> Void)? = nil,
         onToggleFavorite: (() -> Void)? = nil,
         isFavorite: Bool? = nil,
         cardHeight: CGFloat? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.onTap = onTap
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onToggleFavorite = onToggleFavorite
        self.isFavorite = isFavorite
        self.cardHeight = cardHeight
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
            if let onDelete = onDelete {
                Divider()
                Button("删除", role: .destructive) { onDelete() }
            }
        }
    }
}
