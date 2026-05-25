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
后续 Agent 启动时若发现该哨兵块，应按块内规则恢复无人值守循环。

<<<<<<<<<<<<<<<<<<<< UNATTENDED MODE <<<<<<<<<<<<<<<<<<<<
# 无人值守模式

当前项目处于无人值守自主执行模式。

在会话当中的记忆和规则容易丢失，因此本区块是当前模式的项目级事实来源。
后续 Agent 必须以本区块为准，根据推荐流程自主、自动、持续调用技能推进，
执行编码、测试验收，并交付可验证结果。

当 Karl 不在线时，Agent 应按 `.project/agent-loop/` 连续执行：

1. 可自主补规格、补 dev-plan、编码、测试、写回文档、原子提交。
2. 当前任务完成后，自动选择下一个 `ready` / `approved` / `implementing` 任务继续。
3. 没有可执行任务但当前阶段缺规格或缺计划时，先补规格或计划。
4. 每轮都必须写回 task、`00-index.md`，必要时写回 `PRODUCT.md`。
5. 每完成一个稳定里程碑，使用 Conventional Commits 做原子提交。
6. 只有触发停止条件、全部任务完成、或 Karl 明确退出模式时，才停止连续执行。

无人值守模式下，普通 `plan_review_policy: Karl_review` 不应阻止继续推进。
Agent 写完 dev-plan 后，如果没有触发停止条件，应把本任务推进为 `approved`
并继续进入 `karl-dev-execute`。如果为了完成当前目标必须扩大修改范围，Agent
可以继续，但必须在 task 中记录原因、影响文件和验证方式。只有计划涉及部署、
不可逆迁移、永久删除、生产配置、凭据缺失、需求边界变化或多个合理修法时，
才必须停下并写回 `blocked`。

## 无人值守执行循环

无人值守模式的执行循环是一个任务调度算法，不是固定 PDCA。

每一轮必须按下面顺序推进：

```text
第 0 步：恢复事实
- 读取 AGENTS.md，确认 UNATTENDED MODE 哨兵块存在。
- 读取 .project/agent-loop/00-index.md。
- 读取当前候选 task。
- 用 git status 确认真实工作区。

第 1 步：选择任务
- 优先继续 status=implementing 的任务。
- 其次选择 status=approved 的任务。
- 其次选择 status=plan_review 且 plan_review_policy=auto_approved 的任务。
- 其次选择 status=ready 且依赖完成的任务。
- 如果没有可执行任务但当前阶段缺 task，转入 karl-spec-task-compile。
- 如果规格不清，转入 karl-spec-discover 或 karl-spec-final-shape。

第 2 步：判断角色
- task 缺少明确目标、范围、验收标准 -> karl-spec-discover / karl-spec-final-shape。
- task 有阶段目标但缺少 agent-loop 骨架 -> karl-spec-task-compile。
- task 有骨架但缺少仓库实现计划 -> karl-dev-plan。
- task 已 approved 且 §8 自循环编排存在 -> karl-dev-execute。
- 发现具体 bug -> karl-dev-debug。
- 发现异步、状态、重试、缓存、流式或多阶段数据污染 -> karl-dev-trace。

第 2.5 步：无人值守计划审核
- dev-plan 写完后，如果没有触发停止条件，应把 status 改为 approved。
- 如果 task 的 §8 本任务专属自循环编排已经写入，继续进入 karl-dev-execute。
- 如果计划需要扩大修改范围，记录原因、影响文件和验证方式后继续。
- 如果计划需要高风险动作、改变产品边界或存在多个合理方案，写回 blocked 并停止。

第 3 步：执行一轮最小闭环
- 围绕当前 task 的目标执行必要修改；需要扩大修改范围时，先在 task 记录原因。
- 完成一个能验证的真实增量。
- 运行和风险匹配的测试或构建。
- 把结果写回 task 和 00-index。
- 完成稳定里程碑后做原子 commit。

第 4 步：决定继续或停止
- 未触发停止条件，回到第 1 步继续。
- 触发停止条件，写回 blocked 状态并汇报。
- 所有任务 done，写回 execution_mode: interactive，并移除 AGENTS.md 哨兵块。
```

## 当前无人值守任务可验收工作清单

- [ ] **首屏延迟治理 task 12**（task `12-shelf-clipboard-fast-open.md`）
      验收方式：
      1. `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -destination 'platform=macOS' build` 成功
      2. `ShelfWindowController.show()` 路径上能看到对 `pagedClipboardVM.ensurePreviewFirstPageLoaded()` 的调用，让数据加载与 panel 出现并行
      3. `ShelfView` 的 `isClipboardSelected` / `isFavoritesSelected` 改为由 `@AppStorage` 派生，关掉 panel 再开会回到上次的 tab
      4. `loadNextPreviewPage` 用 `propertiesToFetch` + `returnsObjectsAsFaults = true` 切窄 fetch，map 阶段不访问 `sourceAppIcon`/`data`；图标和图片通过 `enrichBlobs` 异步在 BG 补回
      证据写回：
      - 改动文件 + 行号 -> task §9
      - 构建命令输出摘要 -> task §8
      - 用 grep 确认 `sourceAppIcon` 与 `item.data` 仅在 enrich 路径上被访问 -> task §9

- [ ] **增量合并 task 13**（task `13-shelf-clipboard-incremental-update.md`）
      验收方式：
      1. `xcodebuild` 成功
      2. `PagedClipboardViewModel.contextDidSave` 不再无脑调用 `refreshLoadedClipboardData()`；改为读取 `userInfo` 的 inserted/updated/deleted，分别对 `previewItems` 做 patch
      3. 复制一条新内容时 Shelf 已经打开且选中剪贴板，新条目顶端出现，老条目不闪烁、滚动位置不抖
      4. 删除一条时该条目即时消失；其他条目不动
      证据写回：
      - 改动文件 + 行号 -> task §9
      - 构建命令输出摘要 -> task §8
      - 与 task 12 的 fetch 切窄路径如何衔接（增量插入条目也走 textual + enrich 两阶段）-> task §9

- [ ] **commit**
      验收方式：
      1. `git diff --name-only --cached` 只包含本次修复涉及的文件 + task 文档 + 00-index.md
      2. commit message 使用 Conventional Commits（`perf:` 或 `fix:` 前缀），中文正文说明根因和影响
      证据写回：
      - commit hash + 标题 -> task §8

无人值守模式仍然禁止：

1. 部署、发布、修改线上配置。
2. 数据库不可逆迁移或生产数据重写。
3. 永久删除、重置分支、回滚用户改动、强推。
4. 修改外部账号权限、发送第三方消息、创建外部 PR。
5. 在凭据缺失、需求边界变化、测试失败且有多个合理修法时继续硬跑。

退出方式：
Karl 明确输入"退出无人值守模式"后，Agent 应移除本区块，并把 `execution_mode` 改回 `interactive`。
<<<<<<<<<<<<<<<<<<<< END UNATTENDED MODE <<<<<<<<<<<<<<<<<<<<
