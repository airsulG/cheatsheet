import Foundation

/// 结果卡片只保存用于辨认的短文本；全文继续由 Core Data 持有。
struct CabinetRowPreview {
    let title: String
    let excerpt: String
    let isDerivedTitle: Bool
    let isMonospaced: Bool

    init(item: CabinetItem, query: String) {
        let body = item.body
        title = item.title
        isDerivedTitle = title == CabinetContent.title(body)
        isMonospaced = CabinetContent.isMonospaced(body)
        guard !body.isEmpty && body != title else { excerpt = ""; return }
        if !query.isEmpty, let range = body.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) {
            let start = body.index(range.lowerBound, offsetBy: -25, limitedBy: body.startIndex) ?? body.startIndex
            excerpt = (start == body.startIndex ? "" : "…") + String(body[start...].prefix(240))
        } else if case .snippet(let command) = item, (command.name ?? "").isEmpty,
                  let newline = body.firstIndex(where: \.isNewline) {
            let tail = body[body.index(after: newline)...]
            excerpt = String(tail.drop(while: \.isWhitespace).prefix(240)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            excerpt = String(body.prefix(240))
        }
    }
}
