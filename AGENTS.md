# cheatsheet 项目 AGENTS

本文件是当前项目（macOS App `cheatsheet`）的项目级 AGENT 入口。
全局规则在 `.kiro/steering/global-agents.md`，本文件只保存项目长期规则与无人值守状态。

## 1. 项目事实

- **形态**：macOS App（SwiftUI + AppKit + CoreData），bundle id `zhouqiaaha.top.cheatsheet`
- **构建**：Xcode workspace `cheatsheet.xcodeproj`，scheme `cheatsheet`
  - 命令行构建：`xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -destination 'platform=macOS' build`
- **数据**：CoreData 模型 `cheatsheet.xcdatamodeld`；`viewContext` 为 mainQueue，`automaticallyMergesChangesFromParent = true`
- **后台写入**：`ClipboardMonitor` 与 `BackupService` 共用 `newBackgroundContext()`（私有队列）
- **Agent Loop 入口**：`.project/agent-loop/00-index.md`
- **PRODUCT.md**：当前项目尚未建立。规格信息散落在 `.project/agent-loop/` 各 task 与 `.project/context/context.md`，按 global-agents §6.4 的兼容规则处理

## 2. 长期项目规则

1. 任何 ViewModel 的 `NSManagedObjectContextDidSave` 回调，**禁止**在通知线程上直接调用 `viewContext.mergeChanges(...)`、`viewContext.fetch(...)` 或写入 `@Published` 属性。`viewContext.automaticallyMergesChangesFromParent` 已在 `Persistence.swift` 打开，回调里只能做"判断 + `DispatchQueue.main.async`"。
2. 跨上下文对象只能传 `NSManagedObjectID`；从 `userInfo` 拿到的 `NSManagedObject` 只允许做类型判断（`is ClipboardItem`），不允许读属性。
3. 后台 context 的 `save()` 自带"会触发 main 上自动合并"的语义，不要再自己手动合并。
4. Debug Scheme 默认应带 `-com.apple.CoreData.ConcurrencyDebug 1` 参数（这条是 follow-up，不阻塞当前修复）。
5. 删除文件、`git reset`、`git checkout` 必须按 global §13 的二次确认流程，禁止自动执行。
6. 备份 JSON 文件 (`cheatsheet-backup-*.json`) 在仓库根，属于运行时产物，不要 commit。

## 3. 无人值守模式入口

无人值守模式的项目级状态以下方 `UNATTENDED MODE` 哨兵块是否真实存在为准。
后续 Agent 启动时若发现该哨兵块，应按全局技能 `karl-unattended-mode` 恢复无人值守循环。

当前项目处于普通交互模式（execution_mode: interactive）。
最近一轮无人值守已主动收尾，原因是队列剩余任务全部为 `awaiting_user_acceptance`
（task 01 备份功能、task 14 图标显示等），agent 已无可自主推进任务
（karl-unattended-mode §10 第 2 项）。

恢复方式：Karl 输入"进入无人值守模式：按 .project/agent-loop 连续执行，
允许自主规划、编码、测试、提交，直到全部任务完成或触发停止条件"即可重新挂上。
