//
//  CustomSplitView.swift
//  cheatsheet
//
//  Created by AI Assistant on 2025/6/9.
//

import SwiftUI

/// 完全自定义的分割视图，实现真正的无边框设计
struct CustomSplitView<Sidebar: View, Detail: View>: View {
    let sidebar: Sidebar
    let detail: Detail
    
    @State private var sidebarWidth: CGFloat = 250
    @State private var isDragging = false
    
    // 分割线拖拽的最小和最大宽度
    private let minSidebarWidth: CGFloat = 220
    private let maxSidebarWidth: CGFloat = 400
    private let dividerWidth: CGFloat = 1
    
    init(@ViewBuilder sidebar: () -> Sidebar, @ViewBuilder detail: () -> Detail) {
        self.sidebar = sidebar()
        self.detail = detail()
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // 左侧边栏
            sidebar
                .frame(width: sidebarWidth)
                .background(.clear)
            
            // 分割线
            divider
            
            // 右侧详情区域
            detail
                .frame(maxWidth: .infinity)
                .background(.clear)
        }
    }
    
    // MARK: - 分割线视图
    private var divider: some View {
        Rectangle()
            .fill(Color(NSColor.separatorColor))
            .frame(width: dividerWidth)
            .background(.clear)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        let newWidth = sidebarWidth + value.translation.width
                        sidebarWidth = max(minSidebarWidth, min(maxSidebarWidth, newWidth))
                    }
                    .onEnded { _ in
                        isDragging = false
                        NSCursor.arrow.set()
                    }
            )
            .overlay(
                // 拖拽时的视觉反馈
                Rectangle()
                    .fill(Color.accentColor.opacity(isDragging ? 0.3 : 0))
                    .frame(width: 3)
                    .animation(.easeInOut(duration: 0.2), value: isDragging)
            )
    }
}

#Preview {
    CustomSplitView {
        VStack {
            Text("侧边栏")
                .font(.title2)
                .padding()
            Spacer()
        }
        .background(Color.gray.opacity(0.1))
    } detail: {
        VStack {
            Text("详情区域")
                .font(.title2)
                .padding()
            Spacer()
        }
        .background(Color.blue.opacity(0.1))
    }
    .frame(width: 800, height: 600)
}
