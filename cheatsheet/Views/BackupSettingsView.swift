//
//  BackupSettingsView.swift
//  cheatsheet
//
//  Created by Codex on 2026/4/29.
//

import AppKit
import CoreData
import SwiftUI
import UniformTypeIdentifiers

struct BackupSettingsView: View {
    let context: NSManagedObjectContext
    let showsHeader: Bool

    @ObservedObject private var settings = BackupSettings.shared
    @Environment(\.dismiss) private var dismiss

    @State private var isWorking = false
    @State private var resultMessage: String?
    @State private var errorMessage: String?
    @State private var showImportConfirmation = false
    @State private var pendingImportURL: URL?

    init(context: NSManagedObjectContext, showsHeader: Bool = true) {
        self.context = context
        self.showsHeader = showsHeader
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsHeader {
                header

                Divider()
            }

            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("备份文件夹")
                            Spacer()
                            Button("选择文件夹") {
                                chooseBackupFolder()
                            }
                            .disabled(isWorking)
                        }

                        Text(settings.backupFolderPath ?? "尚未选择")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .textSelection(.enabled)
                    }
                } header: {
                    Text("保存位置")
                }

                Section {
                    Picker("自动导出", selection: $settings.frequency) {
                        ForEach(BackupFrequency.allCases) { frequency in
                            Text(frequency.displayName).tag(frequency)
                        }
                    }
                    .pickerStyle(.menu)

                    if let lastAutoExportAt = settings.lastAutoExportAt {
                        Text("上次自动导出：\(formatDate(lastAutoExportAt))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("自动导出会写入带时间戳的新文件，不会覆盖旧备份")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("定时导出")
                }

                Section {
                    Button {
                        exportNow()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("立即导出")
                        }
                    }
                    .disabled(settings.backupFolderPath == nil || isWorking)

                    Button {
                        chooseImportFile()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("从备份文件导入")
                        }
                    }
                    .disabled(isWorking)

                    Text("导入会追加标签、分组与片段，不会覆盖现有数据；重名时会加序号。新备份也包含无标签片段与图片。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("手动操作")
                }

                if let lastExportPath = settings.lastExportPath {
                    Section {
                        Text(lastExportPath)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    } header: {
                        Text("最近导出文件")
                    }
                }

                if let resultMessage {
                    Section {
                        Text(resultMessage)
                            .foregroundColor(.green)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: showsHeader ? 520 : nil, height: showsHeader ? 520 : nil)
        .alert("导入备份", isPresented: $showImportConfirmation) {
            Button("取消", role: .cancel) {
                pendingImportURL = nil
            }
            Button("追加导入") {
                importPendingFile()
            }
        } message: {
            Text("导入会追加标签、分组与片段，不会删除现有数据。")
        }
    }

    private var header: some View {
        HStack {
            Text("备份与恢复")
                .font(.headline)
            Spacer()
            Button("完成") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func chooseBackupFolder() {
        let panel = NSOpenPanel()
        panel.title = "选择备份文件夹"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try settings.setBackupFolder(url)
                resultMessage = "已选择备份文件夹"
                errorMessage = nil
            } catch {
                errorMessage = "保存备份文件夹失败：\(error.localizedDescription)"
                resultMessage = nil
            }
        }
    }

    private func exportNow() {
        isWorking = true
        resultMessage = nil
        errorMessage = nil

        do {
            let url = try BackupService(context: context).exportToConfiguredFolder()
            resultMessage = "已导出：\(url.lastPathComponent)"
        } catch {
            errorMessage = "导出失败：\(error.localizedDescription)"
        }

        isWorking = false
    }

    private func chooseImportFile() {
        let panel = NSOpenPanel()
        panel.title = "选择备份文件"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]

        if panel.runModal() == .OK, let url = panel.url {
            pendingImportURL = url
            showImportConfirmation = true
        }
    }

    private func importPendingFile() {
        guard let url = pendingImportURL else { return }

        isWorking = true
        resultMessage = nil
        errorMessage = nil

        do {
            let result = try BackupService(context: context).importArchive(from: url)
            resultMessage = "已导入 \(result.categoryCount) 个标签、\(result.groupCount) 个分组、\(result.commandCount) 个片段，其中 \(result.favoriteCount) 个常用"
            pendingImportURL = nil
        } catch {
            errorMessage = "导入失败：\(error.localizedDescription)"
        }

        isWorking = false
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    BackupSettingsView(context: PersistenceController.preview.container.viewContext)
}
