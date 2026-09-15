import AppKit
import CoreData
import SwiftUI

/// 元信息、图片和正文共用一个滚动区；正文只保留一个可跨行选择的文本控件。
struct CabinetReader: NSViewRepresentable {
    let itemID: NSManagedObjectID
    let text: String
    let query: String
    let dark: Bool
    let header: AnyView

    func makeNSView(context: Context) -> CabinetReaderScrollView { CabinetReaderScrollView() }

    func updateNSView(_ view: CabinetReaderScrollView, context: Context) {
        view.update(itemID: itemID, text: text, query: query, dark: dark, header: header)
    }
}

final class CabinetReaderScrollView: NSScrollView {
    let content = CabinetReaderDocument()
    private var itemID: NSManagedObjectID?
    private var query = ""
    private var pendingScroll = false

    init() {
        super.init(frame: .zero)
        drawsBackground = false
        hasVerticalScroller = true
        autohidesScrollers = true
        documentView = content
        content.autoresizingMask = [.width]
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(itemID: NSManagedObjectID, text: String, query: String, dark: Bool, header: AnyView) {
        let changedItem = self.itemID != itemID
        pendingScroll = pendingScroll || changedItem || self.query != query
        self.itemID = itemID
        self.query = query
        appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        content.update(text: text, query: query, dark: dark, header: header)
        if changedItem { content.textView.setSelectedRange(NSRange(location: 0, length: 0)) }
        needsLayout = true
    }

    override func layout() {
        super.layout()
        content.arrange(width: contentSize.width)
        guard pendingScroll else { return }
        pendingScroll = false
        if let match = content.matches.first {
            content.textView.scrollRangeToVisible(match)
        } else {
            contentView.scroll(to: .zero)
            reflectScrolledClipView(contentView)
        }
    }
}

final class CabinetReaderDocument: NSView {
    let textView = NSTextView(frame: .zero)
    private let headerView = NSHostingView(rootView: AnyView(EmptyView()))
    private var header = AnyView(EmptyView())
    private var text: String?
    private var query = ""
    private var dark: Bool?
    private var layoutWidth: CGFloat = 0
    private var needsTextLayout = true
    private var needsHeaderLayout = true
    private var textHeight: CGFloat = 0
    private var headerHeight: CGFloat = 0
    private(set) var matches: [NSRange] = []
    override var isFlipped: Bool { true }

    init() {
        super.init(frame: .zero)
        headerView.sizingOptions = [.intrinsicContentSize]
        addSubview(headerView)
        addSubview(textView)
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.heightTracksTextView = false
        textView.setAccessibilityLabel("片段全文")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(text: String, query: String, dark: Bool, header: AnyView) {
        let changedText = self.text != text
        let changedQuery = self.query != query
        let changedAppearance = self.dark != dark
        self.header = AnyView(header.environment(\.colorScheme, dark ? .dark : .light)
            .environment(\.locale, Locale(identifier: "zh_CN")))
        needsHeaderLayout = true

        if changedText {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 7
            paragraph.paragraphSpacing = 4
            let font = CabinetContent.isMonospaced(text)
                ? NSFont.monospacedSystemFont(ofSize: 14, weight: .regular) : NSFont.systemFont(ofSize: 14)
            textView.textStorage?.setAttributedString(NSAttributedString(string: text,
                attributes: [.font: font, .paragraphStyle: paragraph, .foregroundColor: NSColor.labelColor]))
            needsTextLayout = true
        }
        if changedText || changedQuery {
            matches = Self.matchRanges(in: text, query: query)
        }
        if changedText || changedQuery || changedAppearance, let storage = textView.textStorage {
            storage.beginEditing()
            storage.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: storage.length))
            let palette = CabinetPalette(dark: dark)
            for range in matches {
                storage.addAttribute(.backgroundColor, value: NSColor(palette.accent).withAlphaComponent(0.22), range: range)
            }
            storage.endEditing()
        }
        self.text = text
        self.query = query
        self.dark = dark
    }

    static func matchRanges(in text: String, query: String) -> [NSRange] {
        guard !query.isEmpty else { return [] }
        var result: [NSRange] = []
        var start = text.startIndex
        while start < text.endIndex,
              let range = text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive],
                                     range: start..<text.endIndex, locale: .current) {
            guard !range.isEmpty else { break }
            result.append(NSRange(range, in: text))
            start = range.upperBound
        }
        return result
    }

    func arrange(width: CGFloat) {
        let inset = CabinetGrid.detailInset
        guard width > inset * 2 else { return }
        let available = width - inset * 2
        let changedWidth = layoutWidth != width
        if changedWidth || needsHeaderLayout {
            headerView.rootView = AnyView(header.frame(width: available, alignment: .leading))
            headerHeight = ceil(headerView.fittingSize.height)
            headerView.frame = NSRect(x: inset, y: inset, width: available, height: headerHeight)
            needsHeaderLayout = false
        }
        if changedWidth || needsTextLayout, let container = textView.textContainer, let manager = textView.layoutManager {
            container.containerSize = NSSize(width: available, height: .greatestFiniteMagnitude)
            manager.ensureLayout(for: container)
            textHeight = textView.string.isEmpty ? 0 : ceil(manager.usedRect(for: container).height)
            needsTextLayout = false
        }
        let textY = inset + headerHeight + (headerHeight > 0 && textHeight > 0 ? 20 : 0)
        textView.frame = NSRect(x: inset, y: textY, width: available, height: textHeight)
        setFrameSize(NSSize(width: width, height: textY + textHeight + 28))
        layoutWidth = width
    }
}
