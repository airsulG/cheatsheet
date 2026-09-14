import AppKit
import SwiftUI

/// 原生 field editor 持有焦点与输入法组合文本；搜索结果刷新不重建输入状态。
struct CabinetSearchField: NSViewRepresentable {
    @ObservedObject var model: CabinetViewModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBezeled = false
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 13)
        field.textColor = .labelColor
        field.delegate = context.coordinator
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        model.focusSearch = { [weak field] in
            guard let field, let window = field.window else { return }
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(field)
        }
        DispatchQueue.main.async { [weak model] in model?.focusSearch?() }
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        let placeholder = "搜索\(model.heading)的内容或标签…"
        field.placeholderString = placeholder
        field.setAccessibilityLabel(placeholder)
        // 拼音尚未上屏时不写 stringValue，不移动光标，不用中间拼音刷新结果。
        guard (field.currentEditor() as? NSTextView)?.hasMarkedText() != true else { return }
        if field.stringValue != model.query { field.stringValue = model.query }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        let model: CabinetViewModel
        init(model: CabinetViewModel) { self.model = model }

        func controlTextDidBeginEditing(_ notification: Notification) { model.searchHasFocus = true }
        func controlTextDidEndEditing(_ notification: Notification) { model.searchHasFocus = false }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField,
                  (field.currentEditor() as? NSTextView)?.hasMarkedText() != true else { return }
            model.search(field.stringValue)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard !textView.hasMarkedText() else { return false }
            switch selector {
            case #selector(NSResponder.moveDown(_:)): model.moveSelection(1)
            case #selector(NSResponder.moveUp(_:)): model.moveSelection(-1)
            case #selector(NSResponder.insertNewline(_:)): model.copy(close: true)
            default: return false
            }
            return true
        }
    }
}
