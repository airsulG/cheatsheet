//
//  ClipboardHistoryView.swift
//  cheatsheet
//
//  Created by 周麒 on 2025/8/11.
//

import SwiftUI

struct ClipboardHistoryView: View {
    @ObservedObject var viewModel: PagedClipboardViewModel
    @State private var showCopyToast = false
    @State private var showSettings = false

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
                    Text("(\(viewModel.items.count)条记录\(viewModel.hasMore ? "+" : ""))")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape")
                    }
                    .buttonStyle(.borderless)
                    .help("剪贴板设置")
                    
                    Button(action: {
                        viewModel.resetAndLoadFirstPage()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("刷新")
                }
                .padding([.horizontal, .top])
                .padding(.bottom, 8)

                // List of items
                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView("加载中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.items.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVGrid(columns: gridColumns, spacing: 12) {
                            ForEach(viewModel.items) { item in
                                ClipboardItemCardView(item: item, viewModel: viewModel, showCopyToast: $showCopyToast)
                                    .onAppear {
                                        // 滚动到最后几个时加载更多
                                        if item.objectID == viewModel.items.last?.objectID {
                                            viewModel.loadNextPage()
                                        }
                                    }
                            }
                        }
                        .padding()
                        
                        // 加载更多指示器
                        if viewModel.isLoading && !viewModel.items.isEmpty {
                            ProgressView()
                                .padding()
                        }
                    }
                }
            }
        }
        .onAppear {
            viewModel.ensureFirstPageLoaded()
        }
        .overlay(
            Group {
                if showCopyToast {
                    CopyToastView()
                        .transition(.opacity.combined(with: .scale))
                        .animation(.easeInOut(duration: 0.3), value: showCopyToast)
                }
            }
        )
        .sheet(isPresented: $showSettings) {
            ClipboardSettingsView(viewModel: viewModel)
        }
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
    @ObservedObject var viewModel: PagedClipboardViewModel
    @Binding var showCopyToast: Bool

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
            if viewModel.copyItem(item) {
                showCopyToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showCopyToast = false }
            }
        }
        .contextMenu {
            Button("复制") {
                if viewModel.copyItem(item) {
                    showCopyToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showCopyToast = false }
                }
            }
            Button("删除", role: .destructive) { viewModel.deleteItem(item) }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let viewModel = PagedClipboardViewModel(context: context)
    return ClipboardHistoryView(viewModel: viewModel).frame(width: 800)
}
