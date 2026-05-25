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

<<<<<<<<<<<<<<<<<<<< UNATTENDED MODE <<<<<<<<<<<<<<<<<<<<
# 无人值守模式

当前项目处于无人值守自主执行模式。

通用执行规则、打洞流程、状态语义、停止条件参照全局技能：
`/Users/zhouqi/.codex/skills/karl-unattended-mode/SKILL.md`

后续 Agent 必须以本哨兵块的存在 + `00-index.md` 的 `execution_mode: unattended` 双重确认，
判断当前项目是否处于无人值守状态。

## 当前无人值守任务可验收工作清单

本节是当前项目独有的真实工作清单，不是抽象质量标准。
进入模式时由 Agent 根据 PRODUCT.md / 00-index.md / 当前候选 task 生成；
退出模式时随哨兵块一起移除。

清单格式：

```text
- [ ] 交付项：具体要做成什么
      验收方式：用什么真实操作、命令、MCP 请求、界面路径或数据结果证明完成
      证据写回：结果写回哪个 task、00-index 或 PRODUCT 位置
```

### 当前剩余项

本轮 unattended 已完成 task 10 / 11 / 12 / 13 / 14（commit `45a82b5` / `72d6bc9` /
`1e890b4` / `c97d8bd` / `3eef0e2` / 待补 task 14 commit），
全部代码层面交付到位且 `xcodebuild` 通过。剩余只有需要 Karl 真实操作验收的部分：

- [ ] **本轮代码改动的真实界面验收**（awaiting_user_acceptance）
      验收方式：
      1. 在 Xcode 里 ⌘R 启动 cheatsheet
      2. 长跑 30 分钟 + 频繁复制粘贴：不应再出现长跑后 SIGABRT（task 10）
      3. 唤醒 Shelf：来源 App 图标和图片缩略真实显示（task 11）
      4. 重启后第一次唤醒：剪贴板 tab 默认选中，文本预览第一帧可见（task 12）
      5. 复制新内容时其他条目不闪烁、不抖动（task 13）
      6. **task 14 图标显示**：唤醒 Shelf 进入剪贴板 tab，历史卡片应显示
         真实 App 图标（Codex / Kiro / Safari / iShot 等都不再清一色 `app.dashed`）；
         复制新条目后，sandbox `_EXTERNAL_DATA/` 下新增 blob 文件应在 ~2 KB 量级
      证据写回：
      - 视觉验收结果 → 由 Karl 在对话里反馈
      - 如有回归 → Karl 给出现象后由后续 Agent 进入 karl-dev-debug

- [ ] **task 01 备份功能验收**（awaiting_user_acceptance）
      验收方式：
      1. 在 cheatsheet 里打开"备份与恢复"窗口选择文件夹
      2. 执行一次手动导出 → 检查目标文件夹是否生成 JSON
      3. 在备份窗口选择该 JSON → 执行手动导入 → 检查分类 / 命令 / 收藏是否恢复
      证据写回：
      - 验收结果 → task 01 §8 执行记录
      - 如发现导出 / 导入回归 → 进入 karl-dev-debug

按 `karl-unattended-mode` 第 4 步本轮终态判定：
当前所有剩余项都是 `awaiting_user_acceptance`，已触发 (b) 主动收尾退出条件。
但 Karl 未给出新任务且未明确退出指令，本哨兵块按 Karl 上一轮决定保留挂起。
下一个 Agent 进来时应按技能 §13.2 重新核对：是否需要主动退出。

退出方式：
Karl 明确输入"退出无人值守模式"后，Agent 应移除本哨兵块，并把 `execution_mode` 改回 `interactive`。
<<<<<<<<<<<<<<<<<<<< END UNATTENDED MODE <<<<<<<<<<<<<<<<<<<<
