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
            return "横条"
        case .clipboard:
            return "剪贴板"
        case .backup:
            return "备份与恢复"
        }
    }

    var systemImage: String {
        switch self {
        case .shelf:
            return "rectangle.bottomthird.inset.filled"
        case .clipboard:
            return "doc.on.clipboard"
        case .backup:
            return "externaldrive.badge.timemachine"
        }
    }
}

private struct ShelfSettingsView: View {
    @AppStorage(ShelfCardSortSettings.storageKey)
    private var sortModeRaw: String = ShelfCardSortSettings.defaultMode.rawValue

    private var sortModeBinding: Binding<String> {
        Binding(
            get: { sortModeRaw },
            set: { newValue in
                sortModeRaw = newValue
                ShelfCardSortSettings.mode = ShelfCardSortMode(rawValue: newValue) ?? ShelfCardSortSettings.defaultMode
            }
        )
    }

    var body: some View {
        Form {
            Section {
                Picker("命令排序", selection: sortModeBinding) {
                    ForEach(ShelfCardSortMode.allCases) { mode in
                        Label(mode.label, systemImage: mode.systemImage)
                            .tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                Text("按标题排序是默认模式；切换为手动排序后，可以在横条里拖拽命令卡片调整顺序。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
