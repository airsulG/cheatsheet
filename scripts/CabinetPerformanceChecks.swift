import AppKit
import Combine
import CoreData
import SwiftUI
@testable import cheatsheet

// 保留修复前的阅读结构作为对照，不把旧结构带回正式界面。
private struct PreviousReader: View {
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { index, line in
                Text(line.isEmpty ? " " : line)
                    .font(.system(size: 14, design: CabinetContent.isMonospaced(text) ? .monospaced : .default))
                    .lineSpacing(7).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.clear).id(index)
            }
        }.frame(width: 480)
    }
}

@main struct CabinetPerformanceChecks {
    static func measure(_ action: () -> Void) -> Double {
        let start = DispatchTime.now().uptimeNanoseconds
        action()
        return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
    }
    static func stats(_ values: [Double]) -> String {
        let sorted = values.sorted()
        return String(format: "median=%.3f p95=%.3f max=%.3f ms", sorted[sorted.count / 2],
                      sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.95))], sorted.last!)
    }

    @MainActor static func main() throws {
        _ = NSApplication.shared
        let model = NSManagedObjectModel(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))!
        let container = NSPersistentContainer(name: "cheatsheet", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        let readOnly = CommandLine.arguments.count > 2
        if readOnly {
            description.url = URL(fileURLWithPath: CommandLine.arguments[2])
            description.isReadOnly = true
            description.shouldMigrateStoreAutomatically = false
            description.shouldInferMappingModelAutomatically = false
        } else { description.type = NSInMemoryStoreType }
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]
        var failure: Error?
        container.loadPersistentStores { _, error in failure = error }
        if let failure { throw failure }
        let context = container.viewContext
        if !readOnly {
            let store = CabinetStore(context: context)
            for count in [1, 73, 233, 1418] {
                let tag = try store.createTag("模拟标签 \(count)")
                let text = (0..<count).map { "第 \($0 + 1) 行：中文正文与路径示例，验证换行、选择和布局。" }.joined(separator: "\n")
                _ = try store.save(nil, title: "", body: text, tags: [tag])
            }
        }
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let vm = CabinetViewModel(context: context, pasteboard: board)
        precondition(vm.error == nil && !context.hasChanges)
        var notifications = 0
        let subscription = vm.objectWillChange.sink { notifications += 1 }
        let targets = vm.tags.map { CabinetLocation.tag($0.objectID) }
        var navigation: [Double] = []
        for index in 0..<200 where !targets.isEmpty {
            navigation.append(measure { _ = vm.navigate(targets[index % targets.count]) })
        }
        print("DATA snippets=\(vm.snippetCount) tags=\(vm.tags.count) clipboard=\(vm.clipboardCount) source=\(readOnly ? "read-only copy" : "synthetic memory")")
        if !navigation.isEmpty { print("NAVIGATION n=\(navigation.count) \(stats(navigation)) notifications_per_switch=\(Double(notifications) / Double(navigation.count))") }
        withExtendedLifetime(subscription) {}
        let candidates = try context.fetch(Command.fetchRequest()).compactMap { command -> (text: String, lines: Int)? in
            guard command.deletedAt == nil, let text = command.content, !text.isEmpty else { return nil }
            return (text, text.components(separatedBy: "\n").count)
        }
        var seen: Set<Int> = []
        for target in [1, 73, 233, 1418] {
            guard let sample = candidates.min(by: { abs($0.lines - target) < abs($1.lines - target) }),
                  seen.insert(sample.lines).inserted else { continue }
            var old: [Double] = [], native: [Double] = []
            for iteration in 0..<8 {
                let previous = autoreleasepool { measure {
                    let view = NSHostingView(rootView: PreviousReader(text: sample.text))
                    precondition(view.fittingSize.height > 0)
                } }
                let current = autoreleasepool { measure {
                    let view = CabinetReaderDocument()
                    view.update(text: sample.text, query: "", dark: true, header: AnyView(EmptyView()))
                    view.arrange(width: 536)
                    precondition(view.textView.string == sample.text && view.textView.frame.height > 0)
                } }
                // 前两轮预热字体与框架；保留后六轮的实际测量。
                if iteration >= 2 { old.append(previous); native.append(current) }
            }
            print("LAYOUT lines=\(sample.lines) characters=\(sample.text.count) previous \(stats(old)); native \(stats(native))")
        }
        precondition(!context.hasChanges && vm.error == nil)
        print("PASS: full document layout measured at 480pt text width; no database changes or system pasteboard writes")
    }
}
