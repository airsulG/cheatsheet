# 13 剪贴板 contextDidSave 改为增量更新

## 0. 当前状态

- status: approved
- phase: implementing-ready
- role_next: karl-dev-execute
- plan_review_policy: auto_approved
- depends_on: 12-shelf-clipboard-fast-open.md
- parallel_safe: yes
- execution_mode: unattended
- current_goal: 让"复制一条新内容"的 contextDidSave 不再触发整页 reset；列表只增量插入新条目，老条目不抖
- next_action: 实施 §3 的增量合并
- blocker: none
- updated_at: 2026-05-25 12:55

## 1. 目标和需求

**目标行为**：

- 复制一条新内容：previewItems 顶端插入一条；不重置 generation；不重新 fetch 已有条目；不破坏 fetchOffset。
- 删除一条已有：列表移除该条目；其余不动。
- 更新一条已有（极少见，但已有路径）：列表替换该条目。
- 切走 tab 再切回：缓存仍然命中，不触发 fetch。

**不做**：

- 不引入 NSFetchedResultsController。
- 不动 task 12 已经切窄的 fetch + enrich 路径。

## 2. 当前状态和目标差

### 2.1 关键代码事实（task 12 完成后）

- `PagedClipboardViewModel.contextDidSave` 仍然是：
  ```swift
  @objc private func contextDidSave(_ notification: Notification) {
      DispatchQueue.main.async {
          self.refreshLoadedClipboardData()
      }
  }
  ```
- `refreshLoadedClipboardData()`：
  ```swift
  if !previewItems.isEmpty {
      resetPreviewAndLoadFirstPage()   // ★ 全量 reset
  }
  ```
  这条等于"每次复制 → 整页 IO + UI 重排"，即便只插入 1 条。

### 2.2 fetchOffset 漂移问题

- 当前 `loadNextPreviewPage` 用 `fetchOffset = previewOffset` 作为分页游标；
- 增量插入会让"下一页"的真实数据范围和 offset 不一致：插入 N 条后，
  `fetchOffset = previewOffset` 取出的是已经在 previewItems 中的 N 条。
- 解决：把游标改为按时间倒序的 `createdAt` 边界，`fetchOffset` 仅用于"全量重置后的分页"。
  - inserted 处理走 main 队列直接 patch，不动 offset。
  - loadNextPreviewPage 仍然按 offset 分页，但语义改为"加载比 lastItem 更老的一批"。

## 3. 方案

### 3.1 修改清单

#### A. 新增 `applyChanges(inserted:updated:deleted:)` 方法

`PagedClipboardViewModel.swift`：

```swift
private func applyChanges(insertedIDs: Set<NSManagedObjectID>,
                          updatedIDs: Set<NSManagedObjectID>,
                          deletedIDs: Set<NSManagedObjectID>) {
    // 1) 删除：直接从 previewItems 移除
    if !deletedIDs.isEmpty {
        previewItems.removeAll { deletedIDs.contains($0.id) }
        previewOffset = max(0, previewOffset - deletedIDs.count)
    }

    // 2) 插入 + 更新：从 previewContext fetch 这些 ID 的 textual 字段（按 task 12 切窄方式）
    let allIDs = insertedIDs.union(updatedIDs)
    guard !allIDs.isEmpty else { return }

    let generation = previewGeneration
    previewContext.perform { [weak self] in
        guard let self else { return }
        let req: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        req.predicate = NSPredicate(format: "SELF IN %@", allIDs)
        req.propertiesToFetch = ["id", "content", "type", "createdAt", "sourceBundleId", "sourceAppName"]
        req.returnsObjectsAsFaults = true
        req.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItem.createdAt, ascending: false)]

        let fetched: [ClipboardItem]
        do {
            fetched = try self.previewContext.fetch(req)
        } catch {
            return
        }

        let textualPreviews: [ClipboardPreviewItem] = fetched.map { item in
            // 与 loadNextPreviewPage 共用的轻量映射
            ClipboardPreviewItem(
                id: item.objectID,
                uuid: item.id,
                type: item.type ?? "text",
                contentPreview: Self.previewText(item.content, type: item.type ?? "text",
                                                 maxCharacters: self.maxPreviewCharacters),
                sourceAppName: item.sourceAppName,
                sourceAppIconData: nil,
                sourceAppIconCacheKey: nil,
                imageData: nil,
                createdAt: item.createdAt
            )
        }

        DispatchQueue.main.async {
            guard generation == self.previewGeneration else { return }

            for preview in textualPreviews {
                if let idx = self.previewItems.firstIndex(where: { $0.id == preview.id }) {
                    // updated：原地替换，保持原位置
                    self.previewItems[idx] = preview
                } else {
                    // inserted：按 createdAt 倒序找到插入位置
                    let insertAt = self.previewItems.firstIndex(where: {
                        ($0.createdAt ?? .distantPast) < (preview.createdAt ?? .distantPast)
                    }) ?? self.previewItems.count
                    self.previewItems.insert(preview, at: insertAt)
                    self.previewOffset += 1
                }
            }

            // 异步补 blob（task 12 的 enrichBlobs）
            self.enrichBlobs(forItemsWithIDs: textualPreviews.map { $0.id }, generation: generation)
        }
    }
}
```

#### B. 改 `contextDidSave`

```swift
@objc private func contextDidSave(_ notification: Notification) {
    let userInfo = notification.userInfo
    let inserted = (userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject>) ?? []
    let updated  = (userInfo?[NSUpdatedObjectsKey]  as? Set<NSManagedObject>) ?? []
    let deleted  = (userInfo?[NSDeletedObjectsKey]  as? Set<NSManagedObject>) ?? []

    // 跨线程仅读类指针 + objectID
    let insertedIDs = Set(inserted.compactMap { $0 is ClipboardItem ? $0.objectID : nil })
    let updatedIDs  = Set(updated.compactMap  { $0 is ClipboardItem ? $0.objectID : nil })
    let deletedIDs  = Set(deleted.compactMap  { $0 is ClipboardItem ? $0.objectID : nil })

    if insertedIDs.isEmpty && updatedIDs.isEmpty && deletedIDs.isEmpty { return }

    DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        // 仅当列表已经被加载过才增量更新；空列表交给 ensurePreviewFirstPageLoaded
        guard !self.previewItems.isEmpty else { return }
        self.applyChanges(insertedIDs: insertedIDs, updatedIDs: updatedIDs, deletedIDs: deletedIDs)
    }
}
```

`refreshLoadedClipboardData()` 保留（手动清理 / 设置变化时仍然全量 reset），不被 contextDidSave 调用。

### 3.2 边界

- 跨线程读 `NSManagedObject` 仅做 `is` 类型判断和取 `objectID`（线程安全），符合 task 10 的项目长期规则。
- 当 ClipboardMonitor 的 `cleanupOldItems` 触发批量删除（每天 24:00 之后第一次启动可能上千条）：
  - `applyChanges` 接到大集合的 deletedIDs；走 in-memory 过滤一次，仍然便宜。
- updated 路径在当前 monitor 里基本不会出现（`sanitizeExistingXMLLikeItems` 启动时调一次），保留以兼容。

### 3.3 方案对比

| 方案 | 描述 | 评价 |
| --- | --- | --- |
| **A+B（采用）** | userInfo 直接 patch，不动 fetch 流程 | 改动局限在 PagedClipboardViewModel；保持 task 12 的 enrich 路径 |
| C. NSFetchedResultsController | 框架级差量 | 重构 surface 大，和现有 struct 模型不兼容 |

## 4. 验收标准

1. `xcodebuild` 成功。
2. 复制一条新文本：Shelf 已开 + 选中剪贴板，新条目从顶部出现；其他条目不闪烁、不滚动到顶部。
3. 删除一条：该条目即时消失，其他条目位置不动。
4. `grep "refreshLoadedClipboardData" cheatsheet/Models/ViewModels/PagedClipboardViewModel.swift`：
   - 仅出现在该函数定义和 `ShelfViewModel` 那条手动调用路径
   - **不再出现在 `contextDidSave` 内**

## 5. 工具、凭据和环境

- macOS 26.4.1, Xcode, Swift 5
- `xcodebuild`, `git`, `grep`

## 6. 本任务专属自循环编排

```text
第 0 轮：恢复事实
- git status
- 重读 PagedClipboardViewModel.swift（task 12 修改后）

第 1 轮：实施
- 增加 applyChanges
- 重写 contextDidSave

第 2 轮：验证
- xcodebuild
- grep contextDidSave / refreshLoadedClipboardData

第 3 轮：写回 + commit
- 更新 task §0/§7/§8/§9 + 00-index.md
- Conventional Commits 提交
```

## 7. 任务队列

- [ ] 第 1 轮：实施 applyChanges + contextDidSave 重写
- [ ] 第 2 轮：xcodebuild + grep
- [ ] 第 3 轮：写回 + commit

## 8. 执行记录

待写。

## 9. 决策和证据

待写。

## 10. 停止条件

- 增量插入会破坏分页 offset 且修法不唯一
- updated 路径有歧义需要产品决策
- 构建失败超出本任务
- Karl 输入"退出无人值守模式"
