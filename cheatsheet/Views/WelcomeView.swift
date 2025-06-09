//
//  WelcomeView.swift
//  cheatsheet
//
//  Created by 周麒 on 2025/6/9.
//

import SwiftUI

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 30) {
            // 应用图标和标题
            VStack(spacing: 16) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue.gradient)
                
                Text("CheatHub")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("你的命令管理中心")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            // 功能介绍
            VStack(spacing: 20) {
                FeatureRow(
                    icon: "folder.fill",
                    title: "分类管理",
                    description: "创建分类来组织你的命令"
                )
                
                FeatureRow(
                    icon: "doc.on.clipboard.fill",
                    title: "一键复制",
                    description: "点击命令即可复制到剪贴板"
                )
                
                FeatureRow(
                    icon: "pin.fill",
                    title: "固定分类",
                    description: "将常用分类固定到顶部"
                )
                
                FeatureRow(
                    icon: "arrow.up.arrow.down",
                    title: "拖拽排序",
                    description: "拖拽调整分类和命令的顺序"
                )
            }
            .padding(.horizontal, 40)
            
            // 开始使用提示
            VStack(spacing: 12) {
                Text("开始使用")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("从左侧边栏选择一个分类，或创建新的分类来开始管理你的命令")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    WelcomeView()
        .frame(width: 500, height: 600)
}
