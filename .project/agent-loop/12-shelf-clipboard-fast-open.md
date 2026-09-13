# 12 唤醒 Shelf 后剪贴板首屏快速可见

## 0. 当前状态

- status: done
- phase: implementation-complete
- role_next: none
- plan_review_policy: auto_approved
- depends_on: 11-shelf-clipboard-icon-and-image-preview.md（done）
- parallel_safe: yes
- execution_mode: unattended
- current_goal: 唤醒 Shelf 后剪贴板首屏可见时间从几百 ms ~ 几 s 降到只感知打开动画
- next_action: 等待 Karl 体感验收
- blocker: none
- updated_at: 2026-05-25 13:05

## 8. 执行记录

### 第 1-3 轮（2026-05-25 12:55 - 13:05）

- 改文件：
  - `cheatsheet/Views/Shelf/ShelfView.swift`：
    - L20-23：`isClipboardSelected` / `isFavoritesSelected` 由 `@AppStorage("shelfLastTab")` 派生
    - 把 `onTap` / 新建分类 alert / 删除分类 alert 中赋值 `isClipboardSelected`/`isFavoritesSelected` 的位置全部替换为写 `shelfLastTabRaw`
    - 新增 `applyShelfLastTab()` 私有方法，集中"按 tab 派发数据加载"逻辑
    - `.onAppear` 调 `applyShelfLastTab()` 让首次出现就触发对应 tab 的预取
    - `.onChange(of: shelfLastTabRaw)` 替换原来的 `.onChange(of: isClipboardSelected)`，覆盖所有 tab 切换路径
  - `cheatsheet/Utils/ShelfWindowController.swift`：
    - 新增 `private var viewModel: ShelfViewModel?` 让 controller 持有 vm
    - `ensurePanel()` 创建 vm 时同步赋给 `self.viewModel`
    - `show()` 在 setFrame 之前调 `viewModel?.pagedClipboardVM.ensurePreviewFirstPageLoaded()`
  - `cheatsheet/Models/ViewModels/PagedClipboardViewModel.swift`：
    - `ClipboardPreviewItem` 新增 `withBlobs(...)` 工具方法
    - `loadNextPreviewPage` 改造：
      - `propertiesToFetch = ["id","content","type","createdAt","sourceBundleId","sourceAppName"]`
      - `returnsObjectsAsFaults = true`
      - map 阶段不再访问 `item.sourceAppIcon` / `item.data`
      - main.async 写回 previewItems 后调用 `enrichBlobs(forItemsWithIDs:generation:)`
    - 新增 `enrichBlobs(forItemsWithIDs:generation:)`：
      - 在 previewContext 用 `SELF IN ids` 一次拉回 blob 字段
      - 在 BG 队列裁字节，主队列只做 `withBlobs` 替换
      - generation 不一致时丢弃，避免和 task 切换或 reset 冲突

### 第 4 轮：验证

- diagnostics：3 个文件 No diagnostics found
- grep `item.sourceAppIcon|item.data` in PagedClipboardViewModel：仅出现在
  - `enrichBlobs` 内部（2 处，符合预期）
  - `copyItem` / `getStorageSize`（按需读取路径，与首屏无关）
- 构建：`xcodebuild ... build` → `** BUILD SUCCEEDED **`

## 9. 决策和证据

### 9.1 时序对比

修改前：

```text
t0    按热键
t0    show() → setFrame + animator (0.18s)
t180  panel 可见，但 previewItems == [] 且非剪贴板 tab
t??   用户点击"剪贴板" tag → ensurePreviewFirstPageLoaded
       previewContext.fetch(16, allFields)
       16 × external blob IO（图标 ~150KB + 图片 ~MB 级）
t?+几百ms~几s  列表第一次出现
```

修改后：

```text
t0    按热键
t0    show() 内立刻 ensurePreviewFirstPageLoaded
       previewContext.perform { fetch(16, textOnly) }
t0+5  panel 动画开始
       BG 仍在做轻量文本 fetch
t40   文本字段写回 main → previewItems 已经有 16 条文本
       enrichBlobs 异步开始拉 blob
t180  panel 完全显示 → 用户看到文本预览（图标先占位 → 几十 ms 后填回）
       图片同理：占位 → 真图
```

关键差：
1) panel 出现的同一帧用户已看到文本和占位图标。
2) 图标和图片不再阻塞首屏。
3) 关掉 panel 再开会回到上次离开的 tab。

### 9.2 跨任务一致性

- 仍然遵守 task 10 的项目长期规则：不在通知线程上动 viewContext；
  enrichBlobs 在 previewContext 私有队列上读，主队列上仅写 `previewItems`。
- task 11 的图标 + 图片渲染没回归：enrichBlobs 把字节装回 ClipboardPreviewItem
  后，ShelfCard 的判断和占位逻辑不变。
- 为 task 13 的增量合并铺路：`textual fetch + enrichBlobs` 这套两阶段路径
  也会被 applyChanges 复用。

### 9.3 follow-up

- AppStorage 默认值 `"clipboard"` 第一次启动会立刻预取，**首启冷盘 IO 不可避免**；
  本次只优化"已经启动后再唤醒"的体感。冷启动可以下一轮考虑后台预取或 launch 时
  预热。
- enrichBlobs 走 `SELF IN ids` 仍然会读 external blob，长列表 + 大图依然有
  IO 量，只是从"阻塞首屏"变成"异步补齐"。下一轮可以考虑只补 viewport 内可见
  条目（onAppear 触发）。

## 1. 目标和需求

**目标行为**：

- 用户按热键唤醒 Shelf：动画期间数据已经在 BG 队列开始 fetch；第一帧 panel 出现时列表骨架 + 文本预览已经可见。
- panel 关闭再开：进入用户上次离开的 tab；剪贴板内容仍然立即可见（缓存常驻）。
- 图标 / 图片：首帧显示文本和占位骨架（已有 `app.dashed` 与 `<image>` 占位），随后异步补回。

**不做**：

- 不改 contextDidSave 全量 reset 行为（task 13 处理）。
- 不改图标和图片的最终视觉（task 11 已完成的功能保持不变）。
- 不引入第三方依赖。
- 不重构 `ShelfView` 整体结构。

## 2. 当前状态和目标差

### 2.1 关键代码事实

- **A. Shelf 视图常驻但 isClipboardSelected 不常驻**：`ShelfView.swift:21`
  ```swift
  @State private var isClipboardSelected: Bool = false
  ```
  `ShelfWindowController.hide()` 是 `panel.orderOut(nil)`（仅隐藏窗口），`ensurePanel()` 只跑一次。
  但这个 `@State` 在 panel 重新显示时仍然保留——核心问题不是 state 丢失，而是**初始默认就是 false**：
  用户第一次按热键时一律落在"全部未选中"，必须再点一次"剪贴板"tag。

- **B. fetch 触发严重晚 + 全字段加载**：`PagedClipboardViewModel.swift:114-118 / 138-200`
  ```swift
  func ensurePreviewFirstPageLoaded() {
      if previewItems.isEmpty { resetPreviewAndLoadFirstPage() }
  }

  // loadNextPreviewPage 内：
  request.relationshipKeyPathsForPrefetching = []
  request.returnsObjectsAsFaults = false   // ★ 全字段加载，触发 external blob IO
  // 没有 propertiesToFetch
  ```
  16 条 × external blob IO（图标 ~150KB、图片可达 4MB） + 主线程 NSImage 解码。
  这条慢路径只有在 `isClipboardSelected` 翻 true 后才被触发。

- **C. ShelfWindowController.show() 不预取**：`ShelfWindowController.swift:53-71`
  ```swift
  func show() {
      ensurePanel()
      // setFrame + animator
  }
  ```
  完全没有调用任何 ViewModel 的预取入口；动画时间 0.18s 完全空闲。

### 2.2 时序图（修复前）

```text
t0   按热键
t0~  show() → setFrame → animator 0.18s
t180 panel 已经看见，但 previewItems == []
     用户在 panel 上看到非剪贴板 tab 默认状态
t??  用户点击"剪贴板"tag
     onChange → ensurePreviewFirstPageLoaded
     previewContext.fetch(16, allFields)  ← 几十次 external blob IO 几百 ms
t?+几百ms~几s  列表第一次出现
```

## 3. 方案

### 3.1 修改清单

#### A. 默认 tab 记忆 + ShelfView 默认进入剪贴板

`ShelfView.swift`：

- 把 `isClipboardSelected` / `isFavoritesSelected` 替换为由 `@AppStorage("shelfLastTab")` 派生的状态。
- tab 标识用一个枚举字符串：`"clipboard" | "favorites" | category-uuid`。第一次启动默认 `"clipboard"`。
- `onTap` 切 tab 时同步写回 AppStorage。

```swift
@AppStorage("shelfLastTab") private var shelfLastTabRaw: String = "clipboard"

// 派生
private var isClipboardSelected: Bool { shelfLastTabRaw == "clipboard" }
private var isFavoritesSelected: Bool { shelfLastTabRaw == "favorites" }
private var selectedCategoryId: UUID? {
    guard !isClipboardSelected, !isFavoritesSelected else { return nil }
    return UUID(uuidString: shelfLastTabRaw)
}
```

切 tab 改为修改 `shelfLastTabRaw`。`onChange(of: isClipboardSelected)` 改为
`onChange(of: shelfLastTabRaw)`，仍然在变成 clipboard 时调 `ensurePreviewFirstPageLoaded`。

#### B. 唤醒就预取

`ShelfWindowController.swift`：

- `ensurePanel()` 时让 controller 持有 `vm: ShelfViewModel` 的引用（已有 hosting，但只暴露 view；这里让 controller 直接持有 vm）。
- `show()` 内部，在 `setFrame` 之前调 `vm.pagedClipboardVM.ensurePreviewFirstPageLoaded()`。
- 这条预取**只看 isEmpty**，不会触发重复 fetch；后续在用户点击 tab 时也会被这条 guard 短路。

#### C. fetch 切窄 + 异步补 blob

`PagedClipboardViewModel.swift`：

- `loadNextPreviewPage` 改造：
  - 设置 `request.propertiesToFetch = ["id", "content", "type", "createdAt", "sourceBundleId", "sourceAppName"]`
  - 改 `request.returnsObjectsAsFaults = true`（避免一次性物化）
  - map 时**不访问** `item.sourceAppIcon` / `item.data`：`sourceAppIconData = nil`、`imageData = nil`、`sourceAppIconCacheKey = nil`
  - main.async 写回 `previewItems` 后，立即调用新增的 `enrichBlobs(forItemsWithIDs:generation:)`
- 新增 `enrichBlobs`：
  - 在 `previewContext.perform` 里，按 ID 一次性 `fetch` 拿出当前页的 `sourceAppIcon`、`data`（这次允许 external blob 加载）
  - 在主队列把 `previewItems` 中对应 ID 的条目用 `with(blobs:)` 替换；`generation` 不一致时丢弃
  - 增量地把图标 + image 字节填回，触发 SwiftUI 局部刷新

### 3.2 边界

- enrich 阶段如果 ID 不在主队列 `previewItems` 中（用户切换了 generation），直接丢弃，不报错。
- enrich 期间用户切到其他 tab：图片/图标不影响，下次切回剪贴板照常显示。
- 当前 fetch 只读取索引 + 文本字段，size ≪ 全字段，预期一次 < 10ms（即便 16 条 + faults）。
- AppStorage key `shelfLastTab` 是首次新增字段；旧用户读出空字符串时 fallback 到 `"clipboard"`。

### 3.3 方案对比

| 方案 | 描述 | 评价 |
| --- | --- | --- |
| **A+B+C 组合（采用）** | 预取 + 默认 tab + fetch 切窄 + 异步 enrich | 改动 ~3 个文件，每个 < 80 行；体感和数据量级都改善 |
| D. 引入 NSFetchedResultsController | 推送式 + 自动差量 | 重构 surface 大；并和现有 preview struct 模型不兼容 |
| E. 全量缓存常驻（永不清空） | hide 不清，永久内存 | 仍然不能解决"首次启动慢"；并且 task 13 的增量合并是必备 |

D 排除（太大）。E 等于 task 13 的部分功能。

## 4. 验收标准

1. `xcodebuild` 成功。
2. 关闭 App 后重启、再唤醒 Shelf：剪贴板 tab 默认选中；panel 出现的同一帧已经能看到文本预览（图标和图片随后补上）。
3. 切到其他 tag 再切回剪贴板：仍然瞬时显示。
4. `grep "item\\.sourceAppIcon\\|item\\.data" cheatsheet/Models/ViewModels/PagedClipboardViewModel.swift`：仅出现在 `enrichBlobs` 内。
5. 关闭面板再开：进入上次离开的 tab。

## 5. 工具、凭据和环境

- macOS 26.4.1, Xcode, Swift 5
- `xcodebuild`, `git`, `grep`

## 6. 本任务专属自循环编排

```text
第 0 轮：恢复事实
- git status
- 读 ShelfView.swift / ShelfWindowController.swift / PagedClipboardViewModel.swift

第 1 轮：A 默认 tab 记忆
- ShelfView 状态改造
- 顶部 tag 选中态接到 AppStorage

第 2 轮：B 唤醒预取
- ShelfWindowController 持有 vm
- show() 调 ensurePreviewFirstPageLoaded

第 3 轮：C fetch 切窄 + enrichBlobs
- propertiesToFetch + returnsObjectsAsFaults=true
- enrichBlobs 实现
- ClipboardPreviewItem 增加 with(blobs:) 工具

第 4 轮：验证
- xcodebuild
- grep 确认 item.sourceAppIcon / item.data 只在 enrichBlobs 里

第 5 轮：写回 + commit
- 更新 task §0/§7/§8/§9 + 00-index.md
- Conventional Commits 提交
```

## 7. 任务队列

- [ ] 第 1 轮：ShelfView AppStorage 改造
- [ ] 第 2 轮：ShelfWindowController.show 预取
- [ ] 第 3 轮：fetch 切窄 + enrichBlobs
- [ ] 第 4 轮：xcodebuild + grep
- [ ] 第 5 轮：写回 + commit

## 10. 停止条件

- AppStorage 切换后 SwiftUI 状态绑定有问题且修法不唯一
- enrichBlobs 引入新的并发问题
- 构建失败且根因超出本任务
- Karl 输入"退出无人值守模式"
