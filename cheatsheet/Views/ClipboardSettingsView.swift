//
//  ClipboardSettingsView.swift
//  cheatsheet
//
//  Created by Claude on 2025/12/20.
//

import SwiftUI

struct ClipboardSettingsView: View {
    @ObservedObject var viewModel: PagedClipboardViewModel
    @ObservedObject private var settings = ClipboardSettings.shared
    @Environment(\.dismiss) private var dismiss
    private let showsHeader: Bool
    
    @State private var totalCount: Int = 0
    @State private var storageSize: Int64 = 0
    @State private var showClearAllAlert = false
    @State private var showClearOldAlert = false
    @State private var isClearing = false
    @State private var clearResultMessage: String?

    init(viewModel: PagedClipboardViewModel, showsHeader: Bool = true) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.showsHeader = showsHeader
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if showsHeader {
                // 标题栏
                HStack {
                    Text("剪贴板设置")
                        .font(.headline)
                    Spacer()
                    Button("完成") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()

                Divider()
            }

            CabinetSettingsPage {
                // 保存时间设置
                CabinetSettingsSection {
                    HStack {
                        Text("历史保留时间")
                        Spacer()
                        Picker("历史保留时间", selection: $settings.retentionPeriod) {
                            ForEach(ClipboardRetentionPeriod.allCases) { period in
                                Text(period.displayName).tag(period)
                            }
                        }
                        .pickerStyle(.menu).labelsHidden().fixedSize()
                    }
                    
                    Text("超过保留时间的剪贴板记录将在下次启动时自动清理")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("自动清理")
                }
                
                // 数据统计
                CabinetSettingsSection {
                    HStack {
                        Text("记录总数")
                        Spacer()
                        Text("\(totalCount) 条")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("占用空间")
                        Spacer()
                        Text(formatBytes(storageSize))
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("存储统计")
                }
                
                // 手动清理
                CabinetSettingsSection {
                    Button(role: .destructive) {
                        showClearOldAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("清理过期记录")
                        }
                    }
                    .disabled(settings.retentionDays == 0 || isClearing)
                    
                    Button(role: .destructive) {
                        showClearAllAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("清除所有记录")
                        }
                    }
                    .disabled(totalCount == 0 || isClearing)
                } header: {
                    Text("手动清理")
                }
                
                // 清理结果提示
                if let message = clearResultMessage {
                    CabinetSettingsSection {
                        Text(message)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .frame(width: showsHeader ? 400 : nil, height: showsHeader ? 420 : nil)
        .onAppear {
            refreshStats()
        }
        .alert("清理过期记录", isPresented: $showClearOldAlert) {
            Button("取消", role: .cancel) { }
            Button("清理", role: .destructive) {
                clearOldRecords()
            }
        } message: {
            Text("将清理 \(settings.retentionDays) 天前的剪贴板记录，此操作不可撤销。")
        }
        .alert("清除所有记录", isPresented: $showClearAllAlert) {
            Button("取消", role: .cancel) { }
            Button("清除", role: .destructive) {
                clearAllRecords()
            }
        } message: {
            Text("将清除所有 \(totalCount) 条剪贴板记录，此操作不可撤销。")
        }
    }
    
    private func refreshStats() {
        viewModel.getTotalCount { count in
            totalCount = count
        }
        viewModel.getStorageSize { size in
            storageSize = size
        }
    }
    
    private func clearOldRecords() {
        isClearing = true
        clearResultMessage = nil
        viewModel.clearOlderThan(days: settings.retentionDays) { count in
            isClearing = false
            clearResultMessage = "已清理 \(count) 条过期记录"
            refreshStats()
            // 3秒后清除提示
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                clearResultMessage = nil
            }
        }
    }
    
    private func clearAllRecords() {
        isClearing = true
        clearResultMessage = nil
        viewModel.clearAll { count in
            isClearing = false
            clearResultMessage = "已清除 \(count) 条记录"
            refreshStats()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                clearResultMessage = nil
            }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let viewModel = PagedClipboardViewModel(context: context)
    return ClipboardSettingsView(viewModel: viewModel)
}
