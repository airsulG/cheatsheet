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
    @AppStorage("cabinetAppearance") private var appearance = "dark"

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
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(spacing: 0) {
                header
                Divider()
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(CabinetPalette(dark: appearance == "dark").reader)
        }
        .padding(.top, 28)
        .background(CabinetMaterial())
        .ignoresSafeArea(.container, edges: .top)
        .preferredColorScheme(appearance == "dark" ? .dark : .light)
        .environment(\.locale, Locale(identifier: "zh_CN"))
        .tint(CabinetPalette(dark: appearance == "dark").accent)
        .accentColor(CabinetPalette(dark: appearance == "dark").accent)
        .frame(minWidth: 720, idealWidth: 780, minHeight: 540, idealHeight: 600)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 7) {
                Text((selectedSection ?? .shelf).title)
                    .font(.system(size: 15, weight: .semibold))
                Text((selectedSection ?? .shelf).summary)
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()

            Button("完成") {
                if let onDone {
                    onDone()
                } else {
                    dismiss()
                }
            }
            .buttonStyle(.bordered).controlSize(.small)
        }
        .padding(.horizontal, CabinetGrid.detailInset).frame(height: 88)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label { Text("cheatsheet") } icon: { CabinetAppIcon().frame(width: 24, height: 24) }
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 12).frame(height: 72)
            Text("设置").font(.system(size: 10)).foregroundStyle(.tertiary)
                .padding(.horizontal, 12).padding(.bottom, 6)
            ForEach(AppSettingsSection.allCases) { section in
                Button { selectedSection = section } label: {
                    HStack(spacing: 10) {
                        Image(systemName: section.systemImage).frame(width: 18)
                        Text(section.title)
                    }
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12).frame(height: 36)
                        .background(selectedSection == section ? CabinetPalette(dark: appearance == "dark").selection : .clear,
                                    in: RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 12).frame(width: 176)
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

    var summary: String {
        switch self {
        case .shelf: return "外观与日常操作"
        case .clipboard: return "保留历史，管理本机存储"
        case .backup: return "保存资料副本，或从备份追加导入"
        }
    }
}

private struct ShelfSettingsView: View {
    @AppStorage("cabinetAppearance") private var appearance = "dark"

    var body: some View {
        CabinetSettingsPage {
            CabinetSettingsSection {
                HStack {
                    Text("外观")
                    Spacer()
                    Picker("外观", selection: $appearance) {
                        Text("深色").tag("dark")
                        Text("浅色").tag("light")
                    }.pickerStyle(.segmented).labelsHidden().fixedSize()
                }
            } header: { Text("外观") }
            CabinetSettingsSection {
                Text("在列表标题旁切换最近修改、标题或手动顺序。片段右键菜单支持上移和下移。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("单击片段即可编辑，离开输入框时自动保存，右上角显示保存结果。剪贴板原文只读，可先保存为片段再编辑。双击卡片复制，搜索时用方向键选择内容。")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            } header: { Text("浏览与复制") }
            CabinetSettingsSection {
                shortcut("唤出或收起", keys: CabinetRuntime.isPreview ? "⌘ ⇧ ⌥ C" : "⌘ ⇧ C")
                shortcut("搜索", keys: "⌘ K")
                shortcut("保存", keys: "⌘ S")
                shortcut("复制并收起", keys: "⌘ ↵")
            } header: { Text("键盘操作") }
        }
    }

    private func shortcut(_ title: String, keys: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(keys).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
        }
    }
}

/// 设置各页共用资料柜的字号、行距、轻边框和阅读底色。
struct CabinetSettingsPage<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) { content }
                .frame(maxWidth: .infinity, alignment: .leading).padding(CabinetGrid.detailInset)
        }
        .font(.system(size: 12)).controlSize(.regular)
        .buttonStyle(.bordered)
    }
}

struct CabinetSettingsSection<Content: View, Header: View>: View {
    let content: Content
    let header: Header
    init(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> Header) {
        self.content = content(); self.header = header()
    }
    init(@ViewBuilder content: () -> Content) where Header == EmptyView {
        self.content = content(); self.header = EmptyView()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header.font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 16) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.primary.opacity(0.09), lineWidth: 0.5))
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let viewModel = PagedClipboardViewModel(context: context)
    return AppSettingsView(context: context, clipboardViewModel: viewModel)
}
