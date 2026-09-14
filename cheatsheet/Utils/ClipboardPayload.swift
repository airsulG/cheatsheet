import AppKit

enum ClipboardPayload {
    /// 复用历史原有格式；测试可传入命名 pasteboard，避免改动系统剪贴板。
    static func write(_ item: ClipboardItem, to board: NSPasteboard) -> Bool {
        board.clearContents()
        switch item.type ?? "text" {
        case "image":
            guard let data = item.data, let image = NSImage(data: data) else { return false }
            return board.writeObjects([image])
        case "file":
            guard let value = item.content, let url = URL(string: value), url.isFileURL else { return false }
            return board.setString(url.absoluteString, forType: .fileURL)
        case "html":
            let html = item.content ?? ""
            let plain = html.data(using: .utf8).flatMap {
                try? NSAttributedString(data: $0, options: [.documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil)
            }?.string ?? html
            let success = board.setString(html, forType: .html)
            _ = board.setString(plain, forType: .string)
            return success
        case "rtf":
            if let data = item.data {
                let success = board.setData(data, forType: .rtf)
                _ = board.setString(item.content ?? "", forType: .string)
                return success
            }
            return board.setString(item.content ?? "", forType: .string)
        case "url":
            let success = board.setString(item.content ?? "", forType: .URL)
            _ = board.setString(item.content ?? "", forType: .string)
            return success
        default: return board.setString(item.content ?? "", forType: .string)
        }
    }
}
