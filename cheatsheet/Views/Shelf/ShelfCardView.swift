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

    init(title: String,
         subtitle: String,
         onTap: @escaping () -> Void,
         onEdit: (() -> Void)? = nil,
         onDelete: (() -> Void)? = nil,
         onToggleFavorite: (() -> Void)? = nil,
         isFavorite: Bool? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.onTap = onTap
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onToggleFavorite = onToggleFavorite
        self.isFavorite = isFavorite
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 4) {
                // 标题始终左上角
                Text(title.isEmpty ? "未命名" : title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                // 正文尽量多，边距更紧凑
                Text(subtitle)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(5)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(width: 220, height: 120, alignment: .topLeading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.08), lineWidth: 0.5)
        )
        .overlay(alignment: .topTrailing) {
            if let onToggleFavorite = onToggleFavorite, let isFavorite = isFavorite {
                Button(action: { onToggleFavorite() }) {
                    Image(systemName: isFavorite ? "bolt.fill" : "bolt")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isFavorite ? .yellow : .secondary)
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
        }
        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 4)
        .contentShape(Rectangle())
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
