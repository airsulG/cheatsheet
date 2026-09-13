# 10 修复 CoreData 主队列合并崩溃

## 0. 当前状态

- status: done
- phase: implementation-complete
- role_next: none
- plan_review_policy: auto_approved（无人值守模式 + 已写完计划与 §8 自循环编排）
- depends_on: none
- parallel_safe: no（本任务直接改运行时数据合并路径，与 02–09 已 done 的 Shelf 任务串行处理更安全）
- execution_mode: unattended
- unattended_started_at: 2026-05-25 12:35
- unattended_trigger: Karl 明确要求进入无人值守模式
- current_goal: 移除 ShelfViewModel/ClipboardHistoryViewModel 在通知线程上的 viewContext 跨线程写入，让 viewContext.automaticallyMergesChangesFromParent 独占主队列合并
- next_action: 等待 Karl 长跑验收（30 分钟高频复制粘贴）
- blocker: none
- updated_at: 2026-05-25 12:34

## 1. 目标和需求

cheatsheet App 在长时间运行后随机 SIGABRT，最近一次 crash report (2026-05-25 12:02:54) 栈顶为：

```text
-[NSManagedObjectContext _processRecentChanges:]
  -> _postRefreshedObjectsNotificationAndClearList
       -> _createAndPostChangeNotification:..wasMerge:1
            -> -[NSMutableDictionary addEntriesFromDictionary:]
                 -> -[__NSDictionaryM setObject:forKey:]: object cannot be nil
                    NSInvalidArgumentException
```

进程已经活了 ~9 小时 38 分（procLaunch 02:24:20 → captureTime 12:02:54），符合长尾累积型并发 bug。

**目标行为**：

- 后台 context（`ClipboardMonitor` / `BackupService` 共用 `newBackgroundContext()`）的 `save()` 触发 `NSManagedObjectContextDidSave` 后，主队列 `viewContext` 由 `automaticallyMergesChangesFromParent` 独占合并；UI ViewModel 只在主队列上做 fetch / 写 `@Published`。
- 长时间高频复制粘贴 + 启动时一次性 `cleanupOldItems` + `sanitizeExistingXMLLikeItems` 不再触发 `_postRefreshedObjectsNotificationAndClearList` 路径上的 `setObject:forKey: nil`。

**不做**：

- 不动 `Persistence.swift`（auto-merge 已开启即可）。
- 不动 `ClipboardMonitor` 与 `BackupService` 的 BG context 写入路径。
- 不改 CoreData 模型与 schema。
- 不引入 `NSFetchedResultsController` 或 SwiftUI `@FetchRequest` 重构（性能问题，独立任务）。
- 不删除 `ClipboardHistoryViewModel`（它是否仍被任何视图引用尚未核实，本任务只把它从崩溃路径里摘出来）。

## 2. 当前状态和目标差

### 2.1 关键代码事实

- **A. auto-merge 已开启**：`Persistence.swift:97`
  ```swift
  container.viewContext.automaticallyMergesChangesFromParent = true
  ```

- **B. BG context 高频 save**：`cheatsheetApp.swift:14-30` + `ClipboardMonitor.swift:74-103, 115-138, 141-165`
  - `checkClipboard()` 每秒检查、每次新内容 `save()`
  - 启动时还会跑 `cleanupOldItems()` + `sanitizeExistingXMLLikeItems()` 两次额外 save，前者最多删数万条

- **C. `ShelfViewModel.contextDidSave(_:)` 在 BG 队列直接动 viewContext**：`cheatsheet/Models/ViewModels/ShelfViewModel.swift:46-69`
  ```swift
  @objc private func contextDidSave(_ noti: Notification) {
      // 在主 Actor 上合并更改并刷新（viewContext 为 mainQueueConcurrencyType）
      viewContext.mergeChanges(fromContextDidSave: noti)   // ★ 错：此刻是 BG 私有队列
      ...
      pagedClipboardVM.refreshLoadedClipboardData()         // ★ 写 @Published 数组
      categoryVM.fetchCategories()                           // ★ 主线程 ObservableObject 写入
      fetchFavorites()
      if let cat = selectedCategory {
          commandVM.fetchCommands(for: cat)                  // ★ 主线程 fetch + @Published
      }
  }
  ```
  注释里说"在主 Actor 上"是错误的 mental model：`@objc` selector 不会因为类标了 `@MainActor` 就跳到主线程；`NotificationCenter` 同步派发在发布者所在线程，即 BG 私有队列。

- **D. `ClipboardHistoryViewModel.contextDidSave(_:)` 线程对了，但又手动合并了一次**：`cheatsheet/Models/ViewModels/ClipboardHistoryViewModel.swift:33-46`
  ```swift
  viewContext.perform {                                          // ← 线程对
      self.viewContext.mergeChanges(fromContextDidSave: notification)  // ★ 与 auto-merge 重叠
      self.fetchItems()
  }
  ```

- **E. `PagedClipboardViewModel.contextDidSave(_:)` 是正确样板**：`cheatsheet/Models/ViewModels/PagedClipboardViewModel.swift:71-74`
  ```swift
  @objc private func contextDidSave(_ notification: Notification) {
      DispatchQueue.main.async {
          self.refreshLoadedClipboardData()
      }
  }
  ```

### 2.2 时序根因（来自上一轮 dev-trace）

```text
[BG-Queue]                              [Main-Queue]
bgContext.save()
   │
   │ NotificationCenter 同步派发
   │
   ├─► ShelfViewModel.contextDidSave  ← 仍在 BG 队列
   │     viewContext.mergeChanges(...)         ← 越界写 viewContext 内部跟踪集
   │     categoryVM.fetchCategories()          ← 越界 fetch
   │     pagedClipboardVM.refreshLoadedClipboardData()
   │
   │                                       同时
   │                                       viewContext.automaticallyMergesChangesFromParent
   │                                       触发 main 上自动合并，写同一组跟踪集
   │
   │                                       下一拍 main runloop drain：
   │                                       _processRecentChanges → _postRefreshedObjectsNotificationAndClearList
   │                                       → addEntriesFromDictionary → setObject:forKey: nil
   │                                       → NSInvalidArgumentException → abort()
```

## 3. 方案

### 3.1 最小修复

让 `automaticallyMergesChangesFromParent` 独占合并；监听者只在主队列上做"判断 + UI 刷新"。

#### 3.1.1 ShelfViewModel.contextDidSave(_:)

```swift
@objc private func contextDidSave(_ noti: Notification) {
    // 1) 自我反馈防护：只关心其他 context 的 save
    guard let saved = noti.object as? NSManagedObjectContext, saved !== viewContext else { return }

    // 2) 跨线程仅读 NSManagedObject 的类指针（is 判断），不读属性
    let userInfo = noti.userInfo
    let inserted = (userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject>) ?? []
    let updated  = (userInfo?[NSUpdatedObjectsKey]  as? Set<NSManagedObject>) ?? []
    let deleted  = (userInfo?[NSDeletedObjectsKey]  as? Set<NSManagedObject>) ?? []
    let hasClipboardChanges = inserted.union(updated).union(deleted).contains { $0 is ClipboardItem }

    // 3) 所有 viewContext.fetch / @Published 写入回主队列
    //    auto-merge 已经在 Persistence.swift 打开，不再手动 mergeChanges
    DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        if hasClipboardChanges {
            self.pagedClipboardVM.refreshLoadedClipboardData()
        }
        self.categoryVM.fetchCategories()
        self.fetchFavorites()
        if let cat = self.selectedCategory {
            self.commandVM.fetchCommands(for: cat)
        }
    }
}
```

#### 3.1.2 ClipboardHistoryViewModel.contextDidSave(_:)

```swift
@objc private func contextDidSave(_ notification: Notification) {
    guard let context = notification.object as? NSManagedObjectContext,
          context !== viewContext else { return }

    // 不再手动 mergeChanges；auto-merge 完成后只重新 fetch
    DispatchQueue.main.async { [weak self] in
        self?.fetchItems()
    }
}
```

### 3.2 方案对比

| 方案 | 描述 | 评价 |
| --- | --- | --- |
| **A. 收拢到 auto-merge + 主队列 UI 刷新（采用）** | 删手动 mergeChanges，UI 改主队列 | 改动 ≤ 20 行，落在 ViewModel 边界。 |
| B. 关闭 auto-merge，全部手动 mergeChanges + viewContext.perform | 退回手动模型 | 改动面更大；ClipboardMonitor 多 context 协作需要额外协议；风险更高。 |
| C. 给 viewContext 套 `actor`/`@MainActor` 包装 | Swift 原生并发 | 现有 `@objc` selector 与 NotificationCenter 桥接不友好，且改 surface 太大。 |

### 3.3 同源扫描计划

执行后再 grep 一次：

- `mergeChanges(fromContextDidSave:` 应只剩 0 处（修复后）
- `NSManagedObjectContextDidSave` 的 observer 应保留 3 处：`ShelfViewModel`、`ClipboardHistoryViewModel`、`PagedClipboardViewModel`
- 这 3 处的回调主体都要等价于"判断 + DispatchQueue.main.async"或"viewContext.perform { fetch only }"

## 4. 验收标准

1. **构建**：`xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -destination 'platform=macOS' build` 成功。
2. **代码契约**：
   - `ShelfViewModel.contextDidSave(_:)` 内不出现 `viewContext.mergeChanges`、`viewContext.fetch`、直接写 `@Published`。
   - `ClipboardHistoryViewModel.contextDidSave(_:)` 同上。
   - `PagedClipboardViewModel.contextDidSave(_:)` 维持 `DispatchQueue.main.async`。
3. **同源扫描**：`grep -n "mergeChanges(fromContextDidSave" cheatsheet -r` 返回 0 行。
4. **运行时（人工 follow-up，不阻塞当前 task 关闭）**：开 `-com.apple.CoreData.ConcurrencyDebug 1` 跑 30 分钟剪贴板高频写入，不再触发 `_postRefreshedObjectsNotificationAndClearList` → `setObject:forKey:` nil。

## 5. 工具、凭据和环境

- macOS 26.4.1，Xcode（支持 Swift 5/6）
- 命令：`xcodebuild`, `git`, `grep`
- 不需要外部凭据 / 网络资源。

## 6. 本任务专属自循环编排

```text
第 0 轮：恢复事实
- git status 确认工作区
- 读取 AGENTS.md UNATTENDED MODE 哨兵块、本 task §3 方案
- 确认 ShelfViewModel.swift / ClipboardHistoryViewModel.swift / PagedClipboardViewModel.swift / Persistence.swift 当前内容

第 1 轮：实施修复
- 改 ShelfViewModel.contextDidSave(_:)
- 改 ClipboardHistoryViewModel.contextDidSave(_:)
- 不动其他逻辑

第 2 轮：验证
- 构建：xcodebuild ... build
- grep 同源问题：mergeChanges(fromContextDidSave / NSManagedObjectContextDidSave / viewContext.fetch
- 把构建输出摘要、grep 结果写回 §8、§9

第 3 轮：写回 + 提交
- 更新 00-index.md（task 10 状态、execution_mode）
- 更新本 task §0、§8、§9
- git add 仅本任务相关文件 + 文档
- git commit，Conventional Commits

第 4 轮：决定继续或停止
- 没有其他 ready/approved task → 按 unattended 规则收尾，退出无人值守模式
```

## 7. 任务队列

- [ ] 第 1 轮：改 ShelfViewModel.contextDidSave(_:)（ShelfViewModel.swift:46-69）
- [ ] 第 1 轮：改 ClipboardHistoryViewModel.contextDidSave(_:)（ClipboardHistoryViewModel.swift:33-46）
- [ ] 第 2 轮：xcodebuild build
- [ ] 第 2 轮：同源 grep
- [ ] 第 3 轮：写回 task §8/§9 + 00-index
- [ ] 第 3 轮：commit
- [ ] 第 4 轮：决定退出无人值守

## 8. 执行记录

### 第 1 轮（2026-05-25 12:30 - 12:32）

- 改文件：
  - `cheatsheet/Models/ViewModels/ShelfViewModel.swift:46-82` —— `contextDidSave(_:)` 改为
    `guard 自己 save 跳过` + `userInfo` 跨线程只做 `is ClipboardItem` 类型判断 +
    `DispatchQueue.main.async` 收拢 `pagedClipboardVM.refreshLoadedClipboardData()` /
    `categoryVM.fetchCategories()` / `fetchFavorites()` / `commandVM.fetchCommands(for:)`。
    去掉 `viewContext.mergeChanges(fromContextDidSave: noti)`。
  - `cheatsheet/Models/ViewModels/ClipboardHistoryViewModel.swift:35-47` ——
    `contextDidSave(_:)` 删除 `viewContext.perform { mergeChanges + fetchItems }`，
    改为 `DispatchQueue.main.async { fetchItems() }`。

### 第 2 轮（2026-05-25 12:32 - 12:33）

- diagnostics：两个文件 `No diagnostics found`。
- 同源 grep（`cheatsheet/**/*.swift` 范围）：
  - `mergeChanges(fromContextDidSave` -> 0 行
  - `NSManagedObjectContextDidSave` observer -> 仅剩 `ShelfViewModel`、`ClipboardHistoryViewModel`、
    `PagedClipboardViewModel` 三处，均为"判断 + DispatchQueue.main.async"模式
  - `automaticallyMergesChangesFromParent` -> `Persistence.swift:97`（viewContext，符合预期）
    + `PagedClipboardViewModel.swift:59`（previewContext，与本任务无关，列入 follow-up）
- 构建：`xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -destination 'platform=macOS' -configuration Debug build`
  -> `** BUILD SUCCEEDED **`，0 error。

## 9. 决策和证据

### 9.1 修改前后对照

**ShelfViewModel.contextDidSave(_:)**

修改前（关键越界点）：

```swift
@objc private func contextDidSave(_ noti: Notification) {
    // 在主 Actor 上合并更改并刷新（viewContext 为 mainQueueConcurrencyType）
    viewContext.mergeChanges(fromContextDidSave: noti)   // ★ 在 BG 队列动 viewContext

    let allObjects = ...
    let hasClipboardChanges = allObjects.contains { $0 is ClipboardItem }
    if hasClipboardChanges {
        pagedClipboardVM.refreshLoadedClipboardData()    // ★ 跨线程 @Published
    }
    categoryVM.fetchCategories()                          // ★ 跨线程 fetch + @Published
    fetchFavorites()
    if let cat = selectedCategory {
        commandVM.fetchCommands(for: cat)                 // ★ 同上
    }
}
```

修改后（auto-merge 独占合并 + UI 刷新回主队列）：

```swift
@objc private func contextDidSave(_ noti: Notification) {
    guard let saved = noti.object as? NSManagedObjectContext, saved !== viewContext else { return }

    let userInfo = noti.userInfo
    let inserted = (userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject>) ?? []
    let updated  = (userInfo?[NSUpdatedObjectsKey]  as? Set<NSManagedObject>) ?? []
    let deleted  = (userInfo?[NSDeletedObjectsKey]  as? Set<NSManagedObject>) ?? []
    let hasClipboardChanges = inserted.union(updated).union(deleted).contains { $0 is ClipboardItem }

    DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        if hasClipboardChanges {
            self.pagedClipboardVM.refreshLoadedClipboardData()
        }
        self.categoryVM.fetchCategories()
        self.fetchFavorites()
        if let cat = self.selectedCategory {
            self.commandVM.fetchCommands(for: cat)
        }
    }
}
```

**ClipboardHistoryViewModel.contextDidSave(_:)**

修改前：`viewContext.perform { mergeChanges + fetchItems }` —— 线程对了但和 auto-merge 重叠。
修改后：`DispatchQueue.main.async { fetchItems() }` —— 不再手动 mergeChanges。

### 9.2 与 crash report 的对照

```text
Last Exception Backtrace（2026-05-25 12:02:54）：
  -[NSManagedObjectContext _processRecentChanges:]
    -> _postRefreshedObjectsNotificationAndClearList
         -> _createAndPostChangeNotification:..wasMerge:1
              -> -[NSMutableDictionary addEntriesFromDictionary:]
                   -> -[__NSDictionaryM setObject:forKey:]: object cannot be nil
                      NSInvalidArgumentException

进程存活 ~9h38m，长尾累积型并发 bug。
```

修改前的 ShelfViewModel `viewContext.mergeChanges(...)` 在 BG 队列上写 viewContext 的内部
跟踪集（NSMutableSet/NSMutableDictionary）；同时 main 队列上的
`automaticallyMergesChangesFromParent` 也在写同一组集合。两条总线没有锁保护，下一拍 main
runloop drain 时 `_postRefreshedObjectsNotificationAndClearList` 在组装 userInfo 字典时
取到 nil → 抛 NSInvalidArgumentException → main 没 catch → SIGABRT。

修改后：

1. 不再有"BG 队列写 viewContext"的越界路径。
2. auto-merge 独占主队列合并；ViewModel 只在 `DispatchQueue.main.async` 闭包里访问 viewContext。
3. 跨线程读 `NSManagedObject` 仅做类指针判断（`is ClipboardItem`），不读属性。

### 9.3 follow-up（不在本任务范围）

1. `PagedClipboardViewModel.previewContext` 设了 `automaticallyMergesChangesFromParent = true`，
   但它和主 viewContext 之间没有 parent/child 关系（只共享 coordinator），这一行是空操作。
   下一轮可换成显式 `mergeChanges(fromContextDidSave:)` 或改为 parent/child。
2. Debug Scheme 默认参数加 `-com.apple.CoreData.ConcurrencyDebug 1`，防止以后再有人写出
   "BG 队列直接动 viewContext"的回归。
3. `ClipboardHistoryViewModel` 是否还有视图引用，可以下一轮 grep 一次确认；不用则可以删除。
4. 长跑测试（30 分钟高频复制粘贴 + 启动时 sanitize）由人工验收，不在本任务关闭条件内。

## 10. 停止条件

- 构建失败且根因不在本次修复范围内
- 修改 `ShelfViewModel` 时发现 `selectedCategory`、`favorites` 等状态依赖 BG 队列结果，需要扩大改造
- grep 出额外 BG 队列写 viewContext 的位置且修法不唯一
- crash 在新构建上 30 分钟测试中复现且根因不同
- Karl 输入"退出无人值守模式"
