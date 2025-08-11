//
//  ClipboardHistoryView.swift
//  cheatsheet
//
//  Created by 周麒 on 2025/8/11.
//

import SwiftUI

struct ClipboardHistoryView: View {
    @ObservedObject var viewModel: ClipboardHistoryViewModel

    private let gridColumns = [
        GridItem(.adaptive(minimum: 240, maximum: 320), spacing: 12)
    ]

    var body: some View {
        ZStack {
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("剪贴板")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("(\(viewModel.items.count)条记录)")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: {
                        viewModel.fetchItems()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                }
                .padding([.horizontal, .top])
                .padding(.bottom, 8)

                // List of items
                if viewModel.isLoading {
                    ProgressView("加载中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.items.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVGrid(columns: gridColumns, spacing: 12) {
                            ForEach(viewModel.items) { item in
                                ClipboardItemCardView(item: item, viewModel: viewModel)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .onAppear {
            // No longer needed to call cleanup here
            viewModel.fetchItems()
        }
        .overlay(
            Group {
                if viewModel.showCopyToast {
                    CopyToastView()
                        .transition(.opacity.combined(with: .scale))
                        .animation(.easeInOut(duration: 0.3), value: viewModel.showCopyToast)
                }
            }
        )
        .alert("错误", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("确定") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("剪贴板历史为空")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("复制一些文本，它们将自动显示在这里。")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ClipboardItemCardView: View {
    let item: ClipboardItem
    @ObservedObject var viewModel: ClipboardHistoryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.content ?? "无内容")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(4)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 80)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.copyItem(item)
        }
        .contextMenu {
            Button("复制") { viewModel.copyItem(item) }
            Button("删除", role: .destructive) { viewModel.deleteItem(item) }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let viewModel = ClipboardHistoryViewModel(context: context)
    return ClipboardHistoryView(viewModel: viewModel).frame(width: 800)
}
