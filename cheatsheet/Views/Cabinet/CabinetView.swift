import AppKit
import CoreData
import SwiftUI

struct CabinetView: View {
    @ObservedObject var model: CabinetViewModel
    @AppStorage("cabinetAppearance") private var appearance = "dark"
    @FocusState private var searchFocused: Bool
    @State private var collapsed: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "cabinetCollapsedGroups") ?? [])
    @Environment(\.colorScheme) private var colorScheme

    private var palette: CabinetPalette { CabinetPalette(dark: appearance == "dark") }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            HSplitView {
                sidebar.frame(minWidth: 162, idealWidth: 188, maxWidth: 245)
                results.frame(minWidth: 224, idealWidth: 304, maxWidth: 410)
                detail.frame(minWidth: 310, maxWidth: .infinity)
            }
        }
        .padding(.top, 28)
        .background(CabinetMaterial())
        .ignoresSafeArea(.container, edges: .top)
        .preferredColorScheme(appearance == "dark" ? .dark : .light)
        .environment(\.locale, Locale(identifier: "zh_CN"))
        .tint(Color(red: 0.38, green: 0.61, blue: 0.85))
        .frame(minWidth: 740, minHeight: 520)
        .onAppear { model.focusSearch = {
            searchFocused = false
            DispatchQueue.main.async { searchFocused = true }
        } }
        .onChange(of: collapsed) { _, value in UserDefaults.standard.set(Array(value), forKey: "cabinetCollapsedGroups") }
        .onChange(of: searchFocused) { _, value in model.searchHasFocus = value }
        .alert("未能完成操作", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("好", role: .cancel) { model.error = nil }
        } message: { Text(model.error ?? "") }
        .background {
            Group {
                Button("") { searchFocused = true }.keyboardShortcut("k", modifiers: .command)
                Button("") { if model.draft != nil { _ = model.save() } }.keyboardShortcut("s", modifiers: .command)
                Button("") { model.copy(close: true) }.keyboardShortcut(.return, modifiers: .command)
                Button("") { model.newSnippet() }.keyboardShortcut("n", modifiers: .command)
            }.hidden().accessibilityHidden(true)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 18) {
            Label("cheatsheet", systemImage: "square.on.square")
                .font(.system(size: 18, weight: .semibold)).frame(width: 156, alignment: .leading)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜索\(model.heading)的内容或标签…", text: Binding(get: { model.query }, set: { model.search($0) }))
                    .textFieldStyle(.plain).focused($searchFocused)
                    .onSubmit { model.copy(close: true) }
                    .onMoveCommand { direction in
                        if direction == .down { model.moveSelection(1) }
                        if direction == .up { model.moveSelection(-1) }
                    }
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
            Divider().padding(.horizontal, 10)
            HStack {
                Text("标签").foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Button("新建标签…") { createTag() }
                    Button("新建分组…") { createGroup() }
                } label: { Image(systemName: "plus") }.menuStyle(.borderlessButton).fixedSize()
            }.font(.system(size: 11)).padding(.horizontal, 12).padding(.top, 19).padding(.bottom, 12)
            TextField("查找标签或分组…", text: $model.tagQuery)
                .textFieldStyle(.roundedBorder).controlSize(.small).padding(.horizontal, 8).padding(.bottom, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if model.tags.contains(where: { $0.isPinned && matches($0) }) {
                        sectionLabel("置顶")
                        ForEach(model.tags.filter { $0.isPinned && matches($0) }) { tagRow($0) }
                        Divider().padding(.vertical, 5)
                    }
                    ForEach(model.groups) { group in
                        if model.tagQuery.isEmpty || (group.name ?? "").localizedStandardContains(model.tagQuery) ||
                            model.tags.contains(where: { $0.group == group && matches($0) }) {
                            HStack {
                                Button {
                                    let key = group.id?.uuidString ?? ""
                                    if collapsed.contains(key) { collapsed.remove(key) }
                                    else { collapsed.insert(key) }
                                } label: {
                                    HStack {
                                        Image(systemName: collapsed.contains(group.id?.uuidString ?? "") ? "chevron.right" : "chevron.down").font(.system(size: 8, weight: .semibold))
                                        Text(group.name ?? "").lineLimit(1)
                                        Spacer()
                                    }.foregroundStyle(.secondary)
                                }.buttonStyle(.plain)
                            }.font(.system(size: 11)).padding(.horizontal, 10).padding(.top, 8)
                                .contextMenu { groupMenu(group) }
                            if !collapsed.contains(group.id?.uuidString ?? "") || !model.tagQuery.isEmpty {
                                ForEach(model.tags.filter { $0.group == group && (matches($0) || (group.name ?? "").localizedStandardContains(model.tagQuery)) }) { tagRow($0) }
                            }
                        }
                    }
                    if model.tags.contains(where: { $0.group == nil && matches($0) }) {
                        sectionLabel("未分组")
                        ForEach(model.tags.filter { $0.group == nil && matches($0) }) { tagRow($0) }
                    }
                    if model.tags.isEmpty {
                        Text("用标签整理片段\n一个片段可以有多个标签")
                            .font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(5).padding(12)
                    }
                }.padding(.vertical, 4)
            }
            Spacer(minLength: 8)
            Divider().padding(.horizontal, 10)
            Button { model.navigate(.trash) } label: {
                Label("最近删除", systemImage: "trash").font(.system(size: 11)).foregroundStyle(.secondary)
            }.buttonStyle(.plain).padding(12)
        }.padding(.horizontal, 9)
    }

    private func place(_ title: String, icon: String, count: Int, target: CabinetLocation) -> some View {
        Button { model.navigate(target) } label: {
            HStack(spacing: 10) {
                Image(systemName: icon).frame(width: 16).foregroundStyle(.secondary)
                Text(title).font(.system(size: 12, weight: .medium))
                Spacer()
                Text("\(count)").font(.system(size: 10).monospacedDigit()).foregroundStyle(.secondary)
            }.padding(.horizontal, 12).frame(height: 36)
                .background(model.location == target ? palette.selection : .clear, in: RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title).font(.system(size: 10, weight: .medium)).foregroundStyle(.tertiary).padding(.horizontal, 12).padding(.top, 9)
    }

    private func matches(_ tag: Category) -> Bool {
        model.tagQuery.isEmpty || (tag.name ?? "").localizedStandardContains(model.tagQuery)
    }

    private func tagRow(_ tag: Category) -> some View {
        HStack(spacing: 0) {
            Button { model.navigate(.tag(tag.objectID)) } label: {
                HStack(spacing: 9) {
                    Image(systemName: "number").font(.system(size: 10)).foregroundStyle(.tertiary)
                    Text(tag.name ?? "").lineLimit(1).help(tag.name ?? "")
                    Spacer(minLength: 2)
                    Text("\(model.tagCounts[tag.objectID] ?? 0)").font(.system(size: 10).monospacedDigit()).foregroundStyle(.tertiary)
                }.padding(.horizontal, 12).frame(height: 30).contentShape(Rectangle())
            }.buttonStyle(.plain)
        }.font(.system(size: 11))
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
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(model.heading).font(.system(size: 16, weight: .semibold))
                    Text(model.location == .trash ? "\(model.deleted.count) 个可恢复项目" : "\(model.items.count) 个\(model.location == .clipboard ? "记录" : "片段")")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                if model.location != .clipboard && model.location != .trash {
                    Menu {
                        ForEach(["最近修改", "标题", "手动顺序"], id: \.self) { sort in
                            Button(sort) { model.setSort(sort) }
                        }
                    } label: { Image(systemName: "arrow.up.arrow.down").font(.system(size: 11)) }
                        .menuStyle(.borderlessButton).fixedSize().help(model.sort)
                }
            }.padding(22)
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
                    ScrollView {
                        LazyVStack(spacing: 3) {
                            ForEach(model.items) { item in
                                resultRow(item).id(item.id)
                            }
                        }.padding(9)
                    }
                    .onChange(of: model.selection) { _, id in if let id { proxy.scrollTo(id, anchor: .center) } }
                }
            }
            Divider()
            HStack {
                Text("↑ ↓  选择   ·   ↵  复制并收起")
                Spacer()
            }.font(.system(size: 10)).foregroundStyle(.secondary).padding(12)
        }.background(palette.list)
    }

    private func resultRow(_ item: CabinetItem) -> some View {
        VStack(spacing: 0) {
        Button { model.select(item.id) } label: {
            VStack(alignment: .leading, spacing: 10) {
                if let data = item.image, let image = NSImage(data: data) {
                    Image(nsImage: image).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: 145)
                        .padding(6).background(palette.input, in: RoundedRectangle(cornerRadius: 4))
                }
                Text(item.title).font(.system(size: 13, weight: item.title == CabinetContent.title(item.body) ? .regular : .medium))
                    .lineLimit(2).lineSpacing(5)
                if !item.body.isEmpty && item.body != item.title {
                    Text(excerpt(item)).font(.system(size: 11, design: CabinetContent.isMonospaced(item.body) ? .monospaced : .default))
                        .foregroundStyle(.secondary).lineLimit(3).lineSpacing(4)
                }
                if !item.tags.isEmpty {
                    CabinetTagFlow(spacing: 4) {
                        ForEach(item.tags) { tag in CabinetTagLabel(name: tag.name ?? "") }
                    }
                }
                if case .history(let record) = item {
                    HStack(spacing: 5) {
                        if let data = record.sourceAppIcon, let icon = NSImage(data: data) {
                            Image(nsImage: icon).resizable().frame(width: 13, height: 13)
                        }
                        Text(item.source)
                        if let date = record.createdAt { Text("·"); Text(date, style: .relative) }
                    }.font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(14)
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
            HStack {
                Spacer()
                Button {
                    if model.select(item.id) { model.copy(close: false) }
                } label: {
                    Label("复制", systemImage: "doc.on.doc")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(palette.input, in: RoundedRectangle(cornerRadius: 5))
                }.buttonStyle(.plain).help("复制内容，保持窗口打开")
                    .accessibilityLabel("复制：\(item.title)")
            }.padding(.horizontal, 12).padding(.bottom, 10)
        }
            .background(model.selection == item.id ? palette.selection : .clear, in: RoundedRectangle(cornerRadius: 6))
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
                    Button("移到最近删除", role: .destructive) { model.perform { try model.store.trash(c) } }
                } else if case .history(let history) = item {
                    Button("删除这条记录…", role: .destructive) { model.deleteHistory(history) }
                }
            }
    }
    private func excerpt(_ item: CabinetItem) -> String {
        if !model.query.isEmpty, let range = item.body.range(of: model.query, options: [.caseInsensitive, .diacriticInsensitive]) {
            let start = item.body.index(range.lowerBound, offsetBy: -25, limitedBy: item.body.startIndex) ?? item.body.startIndex
            return (start == item.body.startIndex ? "" : "…") + String(item.body[start...].prefix(240))
        }
        if case .snippet(let command) = item, (command.name ?? "").isEmpty,
           let newline = item.body.firstIndex(of: "\n") {
            return String(item.body[item.body.index(after: newline)...].trimmingCharacters(in: .whitespacesAndNewlines).prefix(240))
        }
        return String(item.body.prefix(240))
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
            }.padding(20)
        }
    }

    private var detail: some View {
        VStack(spacing: 0) {
            if model.draft != nil {
                CabinetEditor(model: model, palette: palette)
            } else if let item = model.selected {
                reader(item).id(item.id)
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "doc.text").font(.system(size: 32)).foregroundStyle(.tertiary)
                    Text("选择内容，查看全文").font(.system(size: 13)).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.background(palette.reader)
    }

    private func reader(_ item: CabinetItem) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(model.location == .clipboard ? "剪贴板原文" : "片段").foregroundStyle(.secondary)
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
            }.font(.system(size: 11)).buttonStyle(.borderless).padding(.horizontal, 22).frame(height: 52)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Color.clear.frame(height: 0).id("reader-top")
                        if !item.tags.isEmpty {
                            CabinetTagFlow(spacing: 6) { ForEach(item.tags) { CabinetTagLabel(name: $0.name ?? "") } }
                        }
                        if case .snippet(let c) = item, !(c.name ?? "").isEmpty {
                            Text(c.name ?? "").font(.system(size: 20, weight: .semibold)).textSelection(.enabled)
                        }
                        if let data = item.image, let image = NSImage(data: data) {
                            Image(nsImage: image).resizable().scaledToFit().frame(maxWidth: .infinity)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(item.body.components(separatedBy: "\n").enumerated()), id: \.offset) { index, line in
                            Text(line.isEmpty ? " " : line)
                                .font(.system(size: 14, design: CabinetContent.isMonospaced(item.body) ? .monospaced : .default))
                                .lineSpacing(7).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                                .background(!model.query.isEmpty && line.localizedStandardContains(model.query) ? Color.accentColor.opacity(0.13) : .clear)
                                .id(index)
                        }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(28)
                }.onChange(of: item.id, initial: true) { _, _ in
                    let lines = item.body.components(separatedBy: "\n")
                    let target = model.query.isEmpty ? 0 : lines.firstIndex { $0.localizedStandardContains(model.query) } ?? 0
                    if model.query.isEmpty { proxy.scrollTo("reader-top", anchor: .top) }
                    else { proxy.scrollTo(target, anchor: .top) }
                }.onChange(of: model.query) { _, query in
                    let target = item.body.components(separatedBy: "\n").firstIndex { $0.localizedStandardContains(query) } ?? 0
                    if query.isEmpty { proxy.scrollTo("reader-top", anchor: .top) }
                    else { proxy.scrollTo(target, anchor: .top) }
                }
            }
            Divider()
            HStack(spacing: 12) {
                Text(model.feedback).font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Button("复制") { model.copy(close: false) }
                Button("复制并收起") { model.copy(close: true) }.buttonStyle(.borderedProminent)
            }.controlSize(.large).padding(18)
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
