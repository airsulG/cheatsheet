//
//  CardContainer.swift
//  cheatsheet
//
//  统一卡片容器：固定外观与尺寸，提供 header 与 content 槽位
//

import SwiftUI

struct CardContainer<Header: View, Content: View>: View {
    let headerHeight: CGFloat
    let cornerRadius: CGFloat
    let containerHeight: CGFloat?
    let header: Header
    let content: Content

    init(headerHeight: CGFloat = 28,
         cornerRadius: CGFloat = 12,
         containerHeight: CGFloat? = nil,
         @ViewBuilder header: () -> Header,
         @ViewBuilder content: () -> Content) {
        self.headerHeight = headerHeight
        self.cornerRadius = cornerRadius
        self.containerHeight = containerHeight
        self.header = header()
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                // 统一高度的标题区域（即使不展示文字也占位，保持节奏一致）
                HStack(spacing: 8) {
                    header
                }
                .frame(height: headerHeight, alignment: .center)
                .padding(.horizontal, 10)

                // 内容区域：统一内边距与布局
                content
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(width: 260, height: containerHeight ?? 180, alignment: .topLeading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 4)
        .contentShape(Rectangle())
    }
}
