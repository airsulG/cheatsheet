import AppKit
import CoreData
import SwiftUI
@testable import cheatsheet

/// 相同夹具比较网格和编辑器的首次布局成本，不代表屏幕首帧或 GPU 帧率。
@main struct CabinetMotionBenchmark {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let model = NSManagedObjectModel(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))!
        let container = NSPersistentContainer(name: "cheatsheet", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in precondition(error == nil) }
        let store = CabinetStore(context: container.viewContext)
        let tags = try (0..<4).map { try store.createTag("模拟标签 \($0)") }
        for index in 0..<80 {
            _ = try store.save(nil, title: "片段 \(index)",
                body: String(repeating: "正文与路径，仅用于布局测量。\n", count: index == 0 ? 200 : 8), tags: [tags[index % 4]])
        }
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let vm = CabinetViewModel(context: container.viewContext, pasteboard: board)
        if let destination = ProcessInfo.processInfo.environment["CHEATSHEET_RENDER_SETTINGS"] {
            let directory = URL(fileURLWithPath: destination, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let bundle = Bundle(url: URL(fileURLWithPath: CommandLine.arguments[1]).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent())!
            CabinetSoundPlayer.shared.prepare(bundle: bundle)
            let clipboard = PagedClipboardViewModel(context: container.viewContext)
            for size in [NSSize(width: 780, height: 600), NSSize(width: 720, height: 540)] {
                let host = NSHostingView(rootView: AppSettingsView(context: container.viewContext, clipboardViewModel: clipboard))
                host.frame = NSRect(origin: .zero, size: size)
                host.layoutSubtreeIfNeeded()
                let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let png = bitmap.representation(using: .png, properties: [:])!
                try png.write(to: directory.appendingPathComponent("settings-\(Int(size.width)).png"))
            }
            print("Rendered native settings components only; not a desktop screenshot or motion recording")
            return
        }
        let id = vm.items.first!.id
        func measure(_ action: () -> Void) -> Double {
            let start = DispatchTime.now().uptimeNanoseconds
            action()
            return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
        }
        func report(_ label: String, _ samples: [Double]) {
            let sorted = samples.sorted()
            print(String(format: "%@ median=%.3f max=%.3f ms n=%d", label, sorted[sorted.count / 2], sorted.last!, sorted.count))
        }
        for editing in [false, true] {
            if editing { vm.openDetail(id) }
            var samples: [Double] = []
            for iteration in 0..<12 {
                let duration = autoreleasepool { measure {
                    let host = NSHostingView(rootView: CabinetView(model: vm))
                    host.frame = NSRect(x: 0, y: 0, width: 1140, height: 740)
                    host.layoutSubtreeIfNeeded()
                    precondition(host.subviews.count > 0)
                } }
                if iteration >= 2 { samples.append(duration) }
            }
            report(editing ? "EDITOR_LAYOUT" : "GRID_LAYOUT", samples)
        }
        var samples: [Double] = []
        for index in 0..<200 {
            samples.append(measure { vm.navigate(.tag(tags[index % 4].objectID)) })
        }
        report("NAVIGATION", samples)
    }
}
