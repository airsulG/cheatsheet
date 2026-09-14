//
//  AppSettingsView.swift
//  cheatsheet
//
//  Created by Codex on 2026/6/21.
//

import CoreData
import SwiftUI

struct AppSettingsView: View {
    let context: NSManagedObjectContext

    @ObservedObject var clipboardViewModel: PagedClipboardViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSection: AppSettingsSection? = .shelf

    private let onDone: (() -> Void)?

    init(
        context: NSManagedObjectContext,
        clipboardViewModel: PagedClipboardViewModel,
        onDone: (() -> Void)? = nil
    ) {
        self.context = context
        self._clipboardViewModel = ObservedObject(wrappedValue: clipboardViewModel)
        self.onDone = onDone
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            HStack(spacing: 0) {
                sidebar

                Divider()

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 720, idealWidth: 760, minHeight: 520, idealHeight: 560)
    }

    private var header: some View {
        HStack {
            Text("设置")
                .font(.headline)

            Spacer()

            Button("完成") {
                if let onDone {
                    onDone()
                } else {
                    dismiss()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var sidebar: some View {
        List(AppSettingsSection.allCases, selection: $selectedSection) { section in
            Label(section.title, systemImage: section.systemImage)
                .tag(section)
        }
        .listStyle(.sidebar)
        .frame(width: 180)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedSection ?? .shelf {
        case .shelf:
            ShelfSettingsView()
        case .clipboard:
            ClipboardSettingsView(viewModel: clipboardViewModel, showsHeader: false)
        case .backup:
            BackupSettingsView(context: context, showsHeader: false)
        }
    }
}

private enum AppSettingsSection: String, CaseIterable, Identifiable, Hashable {
    case shelf
    case clipboard
    case backup

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shelf:
            return "资料柜"
        case .clipboard:
            return "剪贴板"
        case .backup:
            return "备份与恢复"
        }
    }

    var systemImage: String {
        switch self {
        case .shelf:
            return "sidebar.left"
        case .clipboard:
            return "doc.on.clipboard"
        case .backup:
            return "externaldrive.badge.timemachine"
        }
    }
}

private struct ShelfSettingsView: View {
    @AppStorage("cabinetAppearance") private var appearance = "dark"

    var body: some View {
        Form {
            Section {
                Picker("外观", selection: $appearance) {
                    Text("深色").tag("dark")
                    Text("浅色").tag("light")
                }
                .pickerStyle(.segmented)

                Text("在列表标题旁切换最近修改、标题或手动顺序。片段右键菜单支持上移和下移。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LabeledContent("唤出或收起", value: CabinetRuntime.isPreview ? "⌘ ⇧ ⌥ C（隔离验收）" : "⌘ ⇧ C")
                LabeledContent("搜索", value: "⌘ K")
                LabeledContent("保存", value: "⌘ S")
                LabeledContent("复制并收起", value: "⌘ ↵")
            }
        }
        .formStyle(.grouped)
        .padding(24)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let viewModel = PagedClipboardViewModel(context: context)
    return AppSettingsView(context: context, clipboardViewModel: viewModel)
}
