import AppKit
import CoreData
import SwiftUI

enum CabinetGrid {
    static let detailInset: CGFloat = 24
    static let headerHeight: CGFloat = 52
}

struct CabinetPalette {
    let dark: Bool
    var reader: Color { Color(white: dark ? 0.205 : 0.96) }
    var list: Color { dark ? Color.black.opacity(0.20) : Color.white.opacity(0.36) }
    var input: Color { dark ? Color.black.opacity(0.22) : Color.black.opacity(0.045) }
    var accent: Color { dark ? Color(red: 0.47, green: 0.66, blue: 0.59) : Color(red: 0.21, green: 0.43, blue: 0.35) }
    var selection: Color { accent.opacity(dark ? 0.20 : 0.13) }
}

struct CabinetAppIcon: View {
    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
            .resizable().scaledToFit().accessibilityHidden(true)
    }
}

struct CabinetMaterial: NSViewRepresentable {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var scheme
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = reduceTransparency ? .windowBackground : .sidebar
        let desired: NSAppearance.Name = scheme == .dark ? .darkAqua : .aqua
        DispatchQueue.main.async {
            if view.window?.appearance?.name != desired {
                view.window?.appearance = NSAppearance(named: desired)
            }
        }
    }
}

struct CabinetTagLabel: View {
    let name: String
    var body: some View {
        Text(name).font(.system(size: 10)).foregroundStyle(.secondary)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(.primary.opacity(0.09), lineWidth: 0.5))
    }
}

struct CabinetTagFlow: Layout {
    var spacing: CGFloat = 5
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? 280, subviews: subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = arrange(width: bounds.width, subviews: subviews)
        for (index, point) in layout.points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }
    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        var x: CGFloat = 0, y: CGFloat = 0, height: CGFloat = 0
        var points: [CGPoint] = []
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width { x = 0; y += height + spacing; height = 0 }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            height = max(height, size.height)
        }
        // 每行按最高标签居中，避免短按钮贴在行顶。
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var rowHeights: [CGFloat: CGFloat] = [:]
        for index in points.indices { rowHeights[points[index].y] = max(rowHeights[points[index].y] ?? 0, sizes[index].height) }
        for index in points.indices {
            points[index].y += ((rowHeights[points[index].y] ?? 0) - sizes[index].height) / 2
        }
        return (CGSize(width: width, height: y + height), points)
    }
}

struct CabinetEditor: View {
    @ObservedObject var model: CabinetViewModel
    let palette: CabinetPalette
    @State private var showTitle = false
    @State private var tagSearch = ""
    @State private var choosingTags = false
    @FocusState private var titleFocused: Bool

    private var draft: Binding<CabinetDraft> {
        Binding(get: { model.draft ?? CabinetDraft() }, set: { model.draft = $0 })
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(model.draft?.commandID == nil ? "新建片段" : "片段")
                if let id = model.draft?.commandID,
                   let command = try? model.context.existingObject(with: id) as? Command {
                    Button {
                        model.perform { command.toggleFavorite(); try model.context.save() }
                    } label: { Image(systemName: command.isFavorite ? "star.fill" : "star") }
                        .buttonStyle(.borderless).help(command.isFavorite ? "取消常用" : "设为常用")
                }
                Spacer()
                if let id = model.draft?.commandID,
                   let item = try? model.context.existingObject(with: id) as? Command, item.originID != nil {
                    Button("返回剪贴板") { model.navigate(.clipboard) }.buttonStyle(.borderless)
                }
                Text(model.saveStatus.hasPrefix("保存失败") ? "保存失败" : (model.dirty ? "待保存" : (model.saveStatus.isEmpty ? "可直接编辑" : model.saveStatus)))
                    .foregroundStyle(model.saveStatus.hasPrefix("保存失败") ? .red : .secondary)
                    .lineLimit(1)
            }.font(.system(size: 11)).foregroundStyle(.secondary).padding(.horizontal, CabinetGrid.detailInset).frame(height: CabinetGrid.headerHeight)
            Divider()
            VStack(alignment: .leading, spacing: 17) {
                HStack(alignment: .top) {
                    CabinetTagFlow(spacing: 6) {
                        ForEach(model.tags.filter { model.draft?.tags.contains($0.objectID) == true }) { tag in
                            Button {
                                model.draft?.tags.remove(tag.objectID)
                                model.autosave()
                            } label: {
                                HStack(spacing: 5) {
                                    Text(tag.name ?? "")
                                    Image(systemName: "xmark").font(.system(size: 8))
                                }.font(.system(size: 10)).foregroundStyle(.secondary)
                                    .padding(.horizontal, 7).padding(.vertical, 5)
                                    .background(palette.input, in: RoundedRectangle(cornerRadius: 4))
                            }.buttonStyle(.plain).help("移除标签 \(tag.name ?? "")")
                        }
                        Button("＋ 添加标签") { choosingTags = true }.font(.system(size: 10)).buttonStyle(.plain).foregroundStyle(.secondary)
                            .popover(isPresented: $choosingTags) { tagPicker }
                    }
                    Menu {
                        Button(showTitle ? "使用正文首行作为标题" : "添加自定义标题") {
                            showTitle.toggle()
                            if !showTitle { model.draft?.title = "" }
                            model.autosave()
                        }
                        Button("添加图片…") { addImage() }
                        if model.draft?.image != nil { Button("移除图片") { model.draft?.image = nil; model.autosave() } }
                    } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).fixedSize()
                }
                if showTitle || !(model.draft?.title.isEmpty ?? true) {
                    TextField("自定义标题（可选）", text: draft.title)
                        .font(.system(size: 16, weight: .medium)).textFieldStyle(.plain)
                        .focused($titleFocused)
                }
                if let data = model.draft?.image, let image = NSImage(data: data) {
                    Image(nsImage: image).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: 170)
                }
                CabinetTextEditor(text: draft.body, session: model.editorSession, focusRequest: model.editorFocusRequest,
                                  query: model.query, onBlur: { model.autosave(session: $0) })
                    .overlay(alignment: .topLeading) {
                        if model.draft?.body.isEmpty ?? true {
                            Text("直接写下内容，首行会成为标题…")
                                .font(.system(size: 14)).foregroundStyle(.tertiary).padding(.top, 5)
                                .allowsHitTesting(false)
                        }
                    }
                HStack {
                    Text("\(model.draft?.body.count ?? 0) 字符")
                    Spacer()
                    Text("离开输入框自动保存")
                }.font(.system(size: 10)).foregroundStyle(.tertiary)
            }.padding(CabinetGrid.detailInset).frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            HStack(spacing: 10) {
                Text(model.feedback).font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Button("复制") { model.copy(close: false) }
                Button("复制并收起") { model.copy(close: true) }.buttonStyle(.borderedProminent)
            }.controlSize(.large).padding(.horizontal, CabinetGrid.detailInset).padding(.vertical, 18)
        }.onAppear { showTitle = !(model.draft?.title.isEmpty ?? true) }
            .onChange(of: model.editorSession) { _, _ in showTitle = !(model.draft?.title.isEmpty ?? true) }
            .onChange(of: titleFocused) { _, focused in if !focused { model.autosave() } }
            .onChange(of: choosingTags) { _, open in if !open { model.autosave() } }
    }

    private var tagPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("查找或新建标签…", text: $tagSearch).textFieldStyle(.roundedBorder)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(model.tags.filter { tagSearch.isEmpty || ($0.name ?? "").localizedStandardContains(tagSearch) }) { tag in
                        Button {
                            if model.draft?.tags.contains(tag.objectID) == true { model.draft?.tags.remove(tag.objectID) }
                            else { model.draft?.tags.insert(tag.objectID) }
                        } label: {
                            HStack {
                                Image(systemName: model.draft?.tags.contains(tag.objectID) == true ? "checkmark.square.fill" : "square")
                                Text(tag.name ?? "").lineLimit(2)
                                Spacer()
                            }.padding(6).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                }
            }.frame(maxHeight: 240)
            if !tagSearch.trimmingCharacters(in: .whitespaces).isEmpty {
                Button("新建“\(tagSearch)”并添加") {
                    model.perform {
                        let tag = try model.store.createTag(tagSearch)
                        model.draft?.tags.insert(tag.objectID)
                        tagSearch = ""
                    }
                }
            }
            Button("完成") { choosingTags = false }.frame(maxWidth: .infinity, alignment: .trailing)
        }.font(.system(size: 12)).padding(15).frame(width: 265)
    }

    private func addImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            model.perform {
                let data = try Data(contentsOf: url)
                guard NSImage(data: data) != nil else { throw CabinetError.invalid("无法读取这张图片") }
                model.draft?.image = data
                model.autosave()
            }
        }
    }
}

struct CabinetTextEditor: NSViewRepresentable {
    @Binding var text: String
    var session = UUID()
    var focusRequest = 0
    var query = ""
    var onBlur: (UUID) -> Void = { _ in }
    @Environment(\.colorScheme) private var scheme
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = CabinetEditableTextView.scrollableTextView()
        let view = scroll.documentView as! NSTextView
        view.delegate = context.coordinator
        view.isRichText = false
        view.allowsUndo = true
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.drawsBackground = false
        scroll.drawsBackground = false
        view.textContainerInset = NSSize(width: 0, height: 5)
        view.textContainer?.lineFragmentPadding = 0
        view.string = text
        view.font = .systemFont(ofSize: 14)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 7
        view.defaultParagraphStyle = paragraph
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]
        view.textContainer?.widthTracksTextView = true
        view.setAccessibilityLabel("片段正文")
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        let view = scroll.documentView as! NSTextView
        let changedSession = context.coordinator.session != session
        if changedSession {
            context.coordinator.session = session
            view.undoManager?.removeAllActions()
        }
        let changedText = context.coordinator.text != text
        if view.string != text && !view.hasMarkedText() { view.string = text }
        if let editable = view as? CabinetEditableTextView {
            editable.onBlur = { [weak coordinator = context.coordinator, weak view] in
                guard let coordinator, let view, !view.hasMarkedText() else { return }
                coordinator.parent.text = view.string
                coordinator.parent.onBlur(coordinator.parent.session)
            }
        }
        if changedSession { view.setSelectedRange(NSRange(location: 0, length: 0)); view.scrollRangeToVisible(NSRange(location: 0, length: 0)) }
        if changedSession || changedText || context.coordinator.query != query, !view.hasMarkedText() {
            let changedQuery = context.coordinator.query != query
            context.coordinator.query = query
            context.coordinator.text = text
            let matches = CabinetReaderDocument.matchRanges(in: text, query: query)
            view.layoutManager?.removeTemporaryAttribute(.backgroundColor, forCharacterRange: NSRange(location: 0, length: (text as NSString).length))
            for match in matches {
                view.layoutManager?.addTemporaryAttribute(.backgroundColor, value: NSColor.controlAccentColor.withAlphaComponent(0.2), forCharacterRange: match)
            }
            if (changedSession || changedQuery), let match = matches.first {
                let expected = session
                DispatchQueue.main.async { [weak coordinator = context.coordinator, weak view] in
                    guard coordinator?.session == expected, coordinator?.query == query, let view,
                          NSMaxRange(match) <= (view.string as NSString).length else { return }
                    view.scrollRangeToVisible(match)
                }
            }
        }
        if context.coordinator.focusRequest != focusRequest {
            context.coordinator.focusRequest = focusRequest
            let expected = session
            DispatchQueue.main.async { [weak coordinator = context.coordinator, weak view] in
                guard coordinator?.session == expected, let view else { return }
                view.window?.makeFirstResponder(view)
            }
        }
        view.textColor = scheme == .dark ? .init(white: 0.91, alpha: 1) : .init(white: 0.12, alpha: 1)
        view.insertionPointColor = view.textColor ?? .labelColor
        let font = CabinetContent.isMonospaced(text) ? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular) : NSFont.systemFont(ofSize: 14)
        if view.font != font { view.font = font }
    }
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CabinetTextEditor
        var session: UUID?
        var focusRequest = 0
        var query = ""
        var text = ""
        init(_ parent: CabinetTextEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView, !view.hasMarkedText() else { return }
            parent.text = view.string
        }
        func textDidEndEditing(_ notification: Notification) {
            guard let view = notification.object as? NSTextView, !view.hasMarkedText() else { return }
            parent.text = view.string
            parent.onBlur(parent.session)
        }
    }
}

final class CabinetEditableTextView: NSTextView {
    var onBlur: (() -> Void)?
    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned { onBlur?() }
        return resigned
    }
}
