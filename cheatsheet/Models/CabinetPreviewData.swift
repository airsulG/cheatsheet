import AppKit
import CoreData

enum CabinetPreviewData {
    static func insert(into context: NSManagedObjectContext) {
        guard CabinetRuntime.isPreview else { return }
        do {
            let store = CabinetStore(context: context)
            let work = try store.createGroup("工作与思考")
            let tools = try store.createGroup("开发工具")
            let design = try store.createTag("设计", group: work)
            let product = try store.createTag("产品", group: work)
            let decision = try store.createTag("决策", group: work)
            let code = try store.createTag("命令行", group: tools)
            let workspace = try store.createTag("工作区", group: tools)
            design.isPinned = true
            let samples: [(String, String, Set<Category>)] = [
                ("把需求说清楚，再开始设计", "请和我一起把一个还不够清楚的产品想法，整理成可以判断、可以设计的需求。\n\n先确认使用者在什么场景下遇到了什么问题。不要急着给功能清单，先把目标、限制和已经确认的事实列出来。\n\n一、理解目标\n我希望在其他 App 工作时，唤出面板，迅速认出并复制内容，然后继续原来的工作。\n\n二、记录边界\n保留剪贴板的完整内容。一个片段可以有多个标签，标签只是帮助查找，不代表内容的唯一归属。\n\n三、验证方案\n用真实长度差异的中文文本、相似路径、多行代码与不同比例图片检查阅读体验。\n\n最终输出需要让我清楚地判断：这次改变解决了什么，代价是什么，还有哪些问题没有证据。", [design, product]),
                ("", "请从这次讨论中提取已经确认的设计决定。\n\n保留目标、约束和选择依据，再列出仍需验证的问题。遇到相互矛盾的判断，先标出差异，不要合并成一个结论。\n\n输出应能让下次接手的人直接理解为什么这样做。", [decision, product]),
                ("查看最近的提交", "git log --oneline -12\n\ngit diff --stat\n\ngit status --short", [code]),
                ("cheatsheet · 设计素材目录", "/Users/demo/Desktop/工作区/08-App/04-cheatsheet-assets", [workspace, design]),
                ("cheatsheet · 原生工程目录", "/Users/demo/Desktop/工作区/08-App/04-cheatsheet", [workspace]),
                ("", "先找到，再继续。", []),
                ("批量处理路径", "for path in paths {\n    guard path.isFileURL else { continue }\n    print(path.lastPathComponent)\n}", [code])
            ]
            for (index, sample) in samples.enumerated() {
                let command = try store.save(nil, title: sample.0, body: sample.1, tags: sample.2)
                command.updatedAt = Date().addingTimeInterval(Double(-index * 100))
                command.isFavorite = index < 2
                command.order = Int32(index)
            }
            for (size, name) in [(NSSize(width: 640, height: 340), "宽幅配色草图"), (NSSize(width: 300, height: 460), "竖版构成参考")] {
                let image = NSImage(size: size)
                image.lockFocus()
                NSColor(calibratedRed: 0.73, green: 0.79, blue: 0.83, alpha: 1).setFill()
                NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
                NSColor(calibratedRed: 0.28, green: 0.40, blue: 0.52, alpha: 1).setFill()
                NSBezierPath(roundedRect: NSRect(x: size.width * 0.18, y: size.height * 0.18, width: size.width * 0.64, height: size.height * 0.64), xRadius: 70, yRadius: 70).fill()
                NSColor(calibratedRed: 0.84, green: 0.81, blue: 0.70, alpha: 1).setFill()
                NSBezierPath(ovalIn: NSRect(x: size.width * 0.36, y: size.height * 0.34, width: size.width * 0.28, height: size.height * 0.32)).fill()
                image.unlockFocus()
                let data = image.tiffRepresentation
                _ = try store.save(nil, title: name, body: "保留图片比例，说明放在下方。", tags: [design], image: data)
                let record = ClipboardItem(context: context, content: "", type: "image", sourceAppName: "预览")
                record.data = data
            }
            for (text, source) in [("最近复制的内容可以直接找到、复制；也能保存成独立片段继续编辑。", "备忘录"),
                                   ("/Users/demo/Desktop/工作区/08-App/04-cheatsheet/README.md", "访达"),
                                   ("git diff --stat", "终端")] {
                _ = ClipboardItem(context: context, content: text, sourceAppName: source)
            }
            try context.save()
        } catch { assertionFailure(error.localizedDescription) }
    }
}
