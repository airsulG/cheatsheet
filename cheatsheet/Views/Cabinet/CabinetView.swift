import AppKit
import CoreData
import SwiftUI

struct CabinetView: View {
    @ObservedObject var model: CabinetViewModel
    var onCardClick: ((NSManagedObjectID) -> Void)?
    @AppStorage("cabinetAppearance") private var appearance = "dark"
    @State private var collapsed: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "cabinetCollapsedGroups") ?? [])
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var palette: CabinetPalette { CabinetPalette(dark: appearance == "dark") }

    private enum SidebarGrid {
        static let inset: CGFloat = 12
        static let icon: CGFloat = 16
        static let gap: CGFloat = 10
        static let accessory: CGFloat = 24
        static let textInset = inset + icon + gap
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            HStack(spacing: 0) {
                sidebar.frame(width: 188)
                Divider()
                GeometryReader { geometry in
                    ZStack(alignment: .trailing) {
                        results
                        if model.isDetailPresented {
                            detail.frame(width: min(460, max(340, geometry.size.width * 0.5)))
                                .background(palette.reader)
                                .overlay(alignment: .leading) {
                                    Rectangle().fill(Color.primary.opacity(0.12)).frame(width: 1)
                                        .allowsHitTesting(false)
                                }
                                .shadow(color: .black.opacity(0.16), radius: 16, x: -6)
                                .transition(reduceMotion ? .opacity : .move(edge: .trailing))
                                .zIndex(1)
                        }
                    }.clipped()
                        .animation(model.detailUsesMotion ? .timingCurve(0.23, 1, 0.32, 1, duration: 0.2) : nil,
                                   value: model.isDetailPresented)
                        .onChange(of: geometry.size.width, initial: true) { _, width in
                            model.gridColumnCount = max(1, Int((width - 48 + 12) / (210 + 12)))
                        }
                }
            }
        }
        .padding(.top, 28)
        .background(CabinetMaterial())
        .ignoresSafeArea(.container, edges: .top)
        .preferredColorScheme(appearance == "dark" ? .dark : .light)
        .environment(\.locale, Locale(identifier: "zh_CN"))
        .tint(palette.accent)
        .accentColor(palette.accent)
        .frame(minWidth: 740, minHeight: 520)
        .overlay(alignment: .top) {
            if let message = model.toastMessage {
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(palette.accent)
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .background(palette.reader, in: Capsule())
                    .overlay(Capsule().stroke(palette.accent.opacity(0.5), lineWidth: 1))
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
                    .padding(.top, 84).allowsHitTesting(false)
                    .accessibilityLabel(message)
            }
        }
        .onChange(of: collapsed) { _, value in UserDefaults.standard.set(Array(value), forKey: "cabinetCollapsedGroups") }
        .alert("未能完成操作", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("好", role: .cancel) { model.error = nil }
        } message: { Text(model.error ?? "") }
        .background {
            Group {
                Button("") { model.focusSearch?() }.keyboardShortcut("k", modifiers: .command)
                Button("") { if model.draft != nil { _ = model.save() } }.keyboardShortcut("s", modifiers: .command)
                Button("") { model.copy(close: true) }.keyboardShortcut(.return, modifiers: .command)
                Button("") { model.newSnippet() }.keyboardShortcut("n", modifiers: .command)
            }.hidden().accessibilityHidden(true)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 18) {
            Label { Text("cheatsheet") } icon: { CabinetAppIcon().frame(width: 28, height: 28) }
                .font(.system(size: 18, weight: .semibold)).frame(width: 156, alignment: .leading)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                CabinetSearchField(model: model).frame(height: 20)
                if !model.query.isEmpty {
                    Button { model.search("") } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain)
                } else { Text("⌘ K").font(.system(size: 11)).foregroundStyle(.tertiary) }
            }
            .padding(10).background(palette.input, in: RoundedRectangle(cornerRadius: 7))
            Button("新建片段") { model.newSnippet() }
                .buttonStyle(.bordered).controlSize(.large)
            Menu {
                Button(appearance == "dark" ? "切换浅色" : "切换深色") { appearance = appearance == "dark" ? "light" : "dark" }
                Divider()
                Button("新建标签…") { createTag() }
                Button("新建分组…") { createGroup() }
                Menu("导入 JSON 到标签") {
                    ForEach(model.tags) { tag in Button(tag.name ?? "") { openImport(tag) } }
                }
                Button("最近删除") { model.navigate(.trash) }
                Divider()
                Button("设置与备份…") {
                    AppSettingsWindowController.shared.present(context: model.context,
                        clipboardViewModel: PagedClipboardViewModel(context: model.context))
                }
            } label: { Image(systemName: "slider.horizontal.3").frame(width: 18) }
                .menuStyle(.borderlessButton).fixedSize().help("外观、导入与设置")
        }
        .padding(.horizontal, 22).frame(height: 68)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 4) {
                place("剪贴板", icon: "clipboard", count: model.clipboardCount, target: .clipboard)
                place("全部资料", icon: "square.stack", count: model.snippetCount, target: .all)
                place("常用", icon: "star", count: model.favoriteCount, target: .favorites)
            }.padding(.top, 18).padding(.bottom, 20)
            Divider().padding(.horizontal, SidebarGrid.inset)
            HStack(spacing: SidebarGrid.gap) {
                Text("标签").foregroundStyle(.secondary)
                Spacer()
                Button { createTag() } label: {
                    Image(systemName: "plus").font(.system(size: 11, weight: .medium))
                        .frame(width: SidebarGrid.accessory, height: 24).contentShape(Rectangle())
                }.buttonStyle(.plain).help("新建标签").accessibilityLabel("新建标签")
            }.font(.system(size: 11)).frame(height: 30)
                .padding(.leading, SidebarGrid.textInset).padding(.trailing, SidebarGrid.inset)
                .padding(.top, 12).padding(.bottom, 6)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if model.tags.contains(where: { $0.isPinned }) {
                        sectionLabel("置顶")
                        ForEach(model.tags.filter { $0.isPinned }) { tagRow($0) }
                        Divider().padding(.horizontal, SidebarGrid.inset).padding(.vertical, 5)
                    }
                    ForEach(model.groups) { group in
                        Button {
                            let key = group.id?.uuidString ?? ""
                            if collapsed.contains(key) { collapsed.remove(key) }
                            else { collapsed.insert(key) }
                        } label: {
                            HStack(spacing: SidebarGrid.gap) {
                                Image(systemName: collapsed.contains(group.id?.uuidString ?? "") ? "chevron.right" : "chevron.down")
                                    .font(.system(size: 8, weight: .semibold)).frame(width: SidebarGrid.icon)
                                Text(group.name ?? "").lineLimit(1)
                                Spacer(minLength: 0)
                            }.foregroundStyle(.secondary).padding(.horizontal, SidebarGrid.inset)
                                .frame(height: 28).contentShape(Rectangle())
                        }.buttonStyle(.plain).font(.system(size: 12)).padding(.top, 4)
                            .contextMenu { groupMenu(group) }
                        if !collapsed.contains(group.id?.uuidString ?? "") {
                            ForEach(model.tags.filter { $0.group == group }) { tagRow($0) }
                        }
                    }
                    if model.tags.contains(where: { $0.group == nil }) {
                        sectionLabel("未分组")
                        ForEach(model.tags.filter { $0.group == nil }) { tagRow($0) }
                    }
                    if model.tags.isEmpty {
                        Text("用标签整理片段\n一个片段可以有多个标签")
                            .font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(5).padding(12)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
            }
            Spacer(minLength: 8)
            Divider().padding(.horizontal, SidebarGrid.inset)
            Button { model.navigate(.trash) } label: {
                HStack(spacing: SidebarGrid.gap) {
                    Image(systemName: "trash").frame(width: SidebarGrid.icon)
                    Text("最近删除")
                    Spacer(minLength: 0)
                }.font(.system(size: 11)).foregroundStyle(.secondary)
                    .padding(.horizontal, SidebarGrid.inset).frame(height: CabinetGrid.footerHeight).contentShape(Rectangle())
            }.buttonStyle(.plain)
        }.padding(.horizontal, 9)
    }

    private func place(_ title: String, icon: String, count: Int, target: CabinetLocation) -> some View {
        Button { model.navigate(target) } label: {
            HStack(spacing: SidebarGrid.gap) {
                Image(systemName: icon).frame(width: SidebarGrid.icon).foregroundStyle(.secondary)
                Text(title).font(.system(size: 12, weight: .medium))
                Spacer()
                Text("\(count)").font(.system(size: 10).monospacedDigit()).foregroundStyle(.secondary)
                    .frame(width: SidebarGrid.accessory)
            }.padding(.horizontal, SidebarGrid.inset).frame(height: 36)
                .background(model.location == target ? palette.selection : .clear, in: RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title).font(.system(size: 10, weight: .medium)).foregroundStyle(.tertiary)
            .padding(.leading, SidebarGrid.textInset).padding(.trailing, SidebarGrid.inset).padding(.top, 9)
    }

    private func tagRow(_ tag: Category) -> some View {
        HStack(spacing: 0) {
            Button { model.navigate(.tag(tag.objectID)) } label: {
                HStack(spacing: SidebarGrid.gap) {
                    Image(systemName: "number").font(.system(size: 10)).foregroundStyle(.tertiary).frame(width: SidebarGrid.icon)
                    Text(tag.name ?? "").lineLimit(1).help(tag.name ?? "")
                    Spacer(minLength: 2)
                    Text("\(model.tagCounts[tag.objectID] ?? 0)").font(.system(size: 10).monospacedDigit()).foregroundStyle(.tertiary)
                        .frame(width: SidebarGrid.accessory)
                }.padding(.horizontal, SidebarGrid.inset).frame(height: 30).contentShape(Rectangle())
            }.buttonStyle(.plain)
        }.font(.system(size: 13))
            .background(model.location == .tag(tag.objectID) ? palette.selection : .clear, in: RoundedRectangle(cornerRadius: 5))
            .contextMenu { tagMenu(tag) }
    }

    @ViewBuilder private func tagMenu(_ tag: Category) -> some View {
        Button(tag.isPinned ? "取消置顶" : "置顶") { model.perform { tag.isPinned.toggle(); try model.context.save() } }
        Button("编辑标签名称…") { rename(tag, name: tag.name ?? "") }
        Menu("添加到分组") {
            Button("未分组") { model.perform { try model.store.move(tag, to: nil) } }
            ForEach(model.groups) { group in
                Button(group.name ?? "") { model.perform { try model.store.move(tag, to: group) } }
            }
            Divider()
            Button("新建分组并加入…") { createGroup(moving: tag) }
        }
        Button("在标签中新建片段") { if model.navigate(.tag(tag.objectID)) { model.newSnippet() } }
        Button("导入 JSON…") { openImport(tag) }
        Divider()
        Button("删除标签", role: .destructive) { model.perform { try model.store.trash(tag) } }
    }
    @ViewBuilder private func groupMenu(_ group: TagGroup) -> some View {
        Button("在分组中新建标签…") { createTag(group: group) }
        Button("编辑分组名称…") { rename(group, name: group.name ?? "") }
        Button("删除分组", role: .destructive) { model.perform { try model.store.trash(group) } }
    }

    private var results: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                Text(model.heading).font(.system(size: 16, weight: .semibold)).lineLimit(1)
                Text("（\(model.location == .trash ? model.deleted.count : model.items.count)）")
                    .font(.system(size: 14)).foregroundStyle(.secondary).fixedSize()
                Spacer()
                if model.location != .clipboard && model.location != .trash {
                    Menu {
                        ForEach(["最近修改", "标题", "手动顺序"], id: \.self) { sort in
                            Button(sort) { model.setSort(sort) }
                        }
                    } label: { Image(systemName: "arrow.up.arrow.down").font(.system(size: 11)) }
                        .menuStyle(.borderlessButton).fixedSize().help(model.sort)
                }
            }.padding(.horizontal, CabinetGrid.detailInset).frame(height: CabinetGrid.headerHeight)
            Divider()
            if model.location == .trash { trashList }
            else if model.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass").font(.system(size: 25)).foregroundStyle(.tertiary)
                    Text(model.query.isEmpty ? "还没有内容" : "没有找到匹配内容").font(.system(size: 12)).foregroundStyle(.secondary)
                    if !model.query.isEmpty { Button("清除搜索") { model.search("") } }
                    else if model.location != .clipboard { Button("新建片段") { model.newSnippet() } }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    GeometryReader { viewport in
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 12)], spacing: 12) {
                                ForEach(model.items) { item in
                                    resultRow(item).id(item.id)
                                }
                            }
                            .padding(CabinetGrid.detailInset)
                            .frame(minHeight: viewport.size.height, alignment: .top)
                            .background {
                                Color.clear.contentShape(Rectangle()).onTapGesture {
                                    if model.isDetailPresented { model.closeDetail(animated: true) }
                                }
                            }
                        }
                    }
                    .onChange(of: model.selectionScrollRequest) { _, _ in
                        if let id = model.selection { proxy.scrollTo(id) }
                    }
                }
            }
            Divider()
            HStack {
                Text("单击编辑 · 双击复制")
                Spacer()
                Text("方向键选择 · ↵ 复制并收起")
            }.font(.system(size: 10)).foregroundStyle(.secondary)
                .padding(.horizontal, CabinetGrid.detailInset).frame(height: CabinetGrid.footerHeight)
        }.background(palette.list)
    }

    private func resultRow(_ item: CabinetItem) -> some View {
        let preview = model.rowPreview(for: item)
        let tags = item.tags
        let rowHelp: String
        if case .snippet = item { rowHelp = "单击片段直接编辑，双击复制" }
        else { rowHelp = "单击查看原文，双击复制" }
        return Button {
            if let onCardClick { onCardClick(item.id) }
            else { model.toggleDetail(item.id, animated: true) }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                if let data = item.image, let image = NSImage(data: data) {
                    Image(nsImage: image).resizable().scaledToFit().frame(maxWidth: .infinity).frame(height: 64)
                        .padding(6).background(palette.input, in: RoundedRectangle(cornerRadius: 4))
                }
                Text(preview.title).font(.system(size: 13, weight: preview.isDerivedTitle ? .regular : .medium))
                    .lineLimit(2).lineSpacing(5)
                if !preview.excerpt.isEmpty {
                    Text(preview.excerpt).font(.system(size: 11, design: preview.isMonospaced ? .monospaced : .default))
                        .foregroundStyle(.secondary).lineLimit(item.image == nil ? 6 : 1).lineSpacing(4)
                }
                Spacer(minLength: 0)
                if !tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(tags.prefix(2))) { tag in CabinetTagLabel(name: tag.name ?? "").lineLimit(1) }
                        if tags.count > 2 { Text("+\(tags.count - 2)").font(.system(size: 10)).foregroundStyle(.secondary) }
                    }
                }
                if case .history(let record) = item {
                    CabinetClipboardSource(record: record)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(14).frame(height: 200)
                .contentShape(Rectangle())
        }.buttonStyle(.plain).help(rowHelp)
            .accessibilityLabel("片段：\(preview.title)")
            .background(model.selection == item.id ? palette.selection : palette.reader.opacity(0.44), in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(model.selection == item.id ? Color.accentColor.opacity(0.48) : Color.primary.opacity(0.12), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .contextMenu {
                Button("复制") { if model.select(item.id) { model.copy(close: false) } }
                Button("复制并收起") { if model.select(item.id) { model.copy(close: true) } }
                if case .snippet(let c) = item {
                    if c.originID != nil {
                        Button("返回剪贴板") { model.navigate(.clipboard) }
                    }
                    Button("编辑") { if model.select(item.id) { model.edit() } }
                    Button(c.isFavorite ? "取消常用" : "设为常用") { model.perform { c.toggleFavorite(); try model.context.save() } }
                    Button("上移") { model.move(item, offset: -1) }
                    Button("下移") { model.move(item, offset: 1) }
                    Button("移到最近删除", role: .destructive) {
                        guard model.allowLeaving() else { return }
                        model.perform { try model.store.trash(c) }
                    }
                } else if case .history(let history) = item {
                    Button("删除这条记录…", role: .destructive) { model.deleteHistory(history) }
                }
            }
    }
    private var trashList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 15) {
                Text("删除标签不会删除片段；删除分组会将标签移到未分组。").font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(5)
                ForEach(model.deleted, id: \.objectID) { object in
                    HStack {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            Text((object as? Command)?.displayTitle ?? object.value(forKey: "name") as? String ?? "")
                                .font(.system(size: 12)).lineLimit(2)
                            Text(object is Category ? "标签" : object is TagGroup ? "分组" : "片段").font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("恢复") { model.perform { try model.store.restore(object) } }.controlSize(.small)
                    }
                }
            }.padding(CabinetGrid.detailInset)
        }
    }

    private var detail: some View {
        VStack(spacing: 0) {
            if model.draft != nil {
                CabinetEditor(model: model, palette: palette)
            } else if let item = model.selected {
                reader(item)
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "doc.text").font(.system(size: 32)).foregroundStyle(.tertiary)
                    Text("选择内容，查看全文").font(.system(size: 13)).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func reader(_ item: CabinetItem) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(model.location == .clipboard ? "剪贴板原文" : "片段").foregroundStyle(.secondary)
                Button { model.closeDetail(animated: true) } label: { Image(systemName: "sidebar.right") }
                    .help("收起面板（Esc）").accessibilityLabel("收起编辑面板")
                Spacer()
                if case .snippet(let c) = item {
                    if c.originID != nil { Button("返回剪贴板") { model.navigate(.clipboard) } }
                    Button { model.perform { c.toggleFavorite(); try model.context.save() } } label: {
                        Image(systemName: c.isFavorite ? "star.fill" : "star")
                    }.help(c.isFavorite ? "取消常用" : "设为常用")
                    Button("编辑") { model.edit() }
                } else {
                    Button(model.collectionLabel) { model.collect() }
                }
            }.font(.system(size: 11)).buttonStyle(.borderless).padding(.horizontal, CabinetGrid.detailInset).frame(height: CabinetGrid.headerHeight)
            Divider()
            CabinetReader(itemID: item.id, text: item.body, query: model.query,
                          dark: appearance == "dark", header: AnyView(
                    VStack(alignment: .leading, spacing: 20) {
                        if case .history(let record) = item { CabinetClipboardSource(record: record) }
                        if !item.tags.isEmpty {
                            CabinetTagFlow(spacing: 6) { ForEach(item.tags) { CabinetTagLabel(name: $0.name ?? "") } }
                        }
                        if case .snippet(let c) = item, !(c.name ?? "").isEmpty {
                            Text(c.name ?? "").font(.system(size: 20, weight: .semibold)).textSelection(.enabled)
                        }
                        if let data = item.image, let image = NSImage(data: data) {
                            Image(nsImage: image).resizable().scaledToFit().frame(maxWidth: .infinity)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
            ))
            Divider()
            HStack(spacing: 12) {
                Text(model.feedback).font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Button("复制") { model.copy(close: false) }
                Button("复制并收起") { model.copy(close: true) }.buttonStyle(.borderedProminent)
            }.controlSize(.large).padding(.horizontal, CabinetGrid.detailInset).frame(height: CabinetGrid.footerHeight)
        }
    }

    private func prompt(_ title: String, initial: String = "", action: (String) throws -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")
        let field = NSTextField(string: initial)
        field.frame = NSRect(x: 0, y: 0, width: 280, height: 26)
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        if alert.runModal() == .alertFirstButtonReturn { model.perform { try action(field.stringValue) } }
    }
    private func createTag(group: TagGroup? = nil) {
        prompt("新建标签") { _ = try model.store.createTag($0, group: group) }
    }
    private func createGroup(moving tag: Category? = nil) {
        prompt("新建分组") {
            let group = try model.store.createGroup($0)
            if let tag { try model.store.move(tag, to: group) }
        }
    }
    private func rename(_ object: NSManagedObject, name: String) {
        prompt("编辑名称", initial: name) { try model.store.rename(object, to: $0) }
    }
    private func openImport(_ tag: Category) {
        guard model.allowLeaving() else { return }
        ImportPanelWindowController.shared.present(category: tag, commandViewModel: CommandViewModel(context: model.context))
    }
}
