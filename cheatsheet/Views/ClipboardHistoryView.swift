//
//  ClipboardHistoryView.swift
//  cheatsheet
//
//  Created by 周麒 on 2025/8/11.
//

import SwiftUI

struct ClipboardHistoryView: View {
    @ObservedObject var viewModel: ClipboardHistoryViewModel
    
    var body: some View {
        ZStack {
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("剪贴板")
                        .font(.title)
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
                .padding()

                // List of items
                if viewModel.isLoading {
                    ProgressView("加载中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.items.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(viewModel.items) { item in
                            ClipboardItemRowView(item: item)
                                .onTapGesture {
                                    viewModel.copyItem(item)
                                }
                                .contextMenu {
                                    Button("复制") { viewModel.copyItem(item) }
                                    Button("删除", role: .destructive) { viewModel.deleteItem(item) }
                                }
                        }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
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

struct ClipboardItemRowView: View {
    let item: ClipboardItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.content ?? "无内容")
                    .lineLimit(2)
                    .truncationMode(.tail)
                
                HStack(spacing: 8) {
                    Text(item.type?.uppercased() ?? "N/A")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                    
                    Text(item.createdAt ?? Date(), style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let viewModel = ClipboardHistoryViewModel(context: context)
    return ClipboardHistoryView(viewModel: viewModel)
}
