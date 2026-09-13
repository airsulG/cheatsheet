# 11 修复底部横条剪贴板图标与图片预览失踪

## 0. 当前状态

- status: done
- phase: implementation-complete
- role_next: none
- plan_review_policy: auto_approved
- depends_on: 10-coredata-crash-mainqueue-merge.md（done）
- parallel_safe: yes
- execution_mode: unattended
- current_goal: 让 Shelf 的剪贴板卡片重新显示来源 App 图标与图片缩略
- next_action: 等待 Karl 视觉验收（启动 App 看图标和图片是否回来）
- blocker: none
- updated_at: 2026-05-25 12:42

## 1. 目标和需求

**目标行为**：

- 底部横条（`ShelfView`）剪贴板卡片头部显示真实来源 App 图标（32×32 缩到 16×16 容器内）；
  当条目缺图标 / 图标解码失败时，回退 `app.dashed`。
- `type == "image"` 的剪贴条目内容区显示真实图片缩略；
  当 image data 缺失或解码失败 / 体积过大时，回退到现有 `<image>` 文本占位。

**不做**：

- 不改写入端（`ClipboardMonitor.checkClipboard`）。
- 不改数据模型，不做迁移。
- 不重构 preview 模型抽象，只新增 1 个字段。
- 不引入异步图片解码缓存（`SourceAppIconCache` 已有，复用即可）。
- 不修复 `previewContext.automaticallyMergesChangesFromParent` 这个空操作（task 10 follow-up）。

## 2. 当前状态和目标差

### 2.1 关键代码事实

- **A. 图标默认 100% 被裁掉**：`PagedClipboardViewModel.swift:52`
  ```swift
  private let maxSourceAppIconBytes = 64 * 1024
  ```
  实测 macOS App 图标 PNG 普遍 130KB ~ 200KB（多分辨率位图），全部 > 64KB。
  `cappedSourceAppIconData(_:maxBytes:)` 越界即返回 `nil`，`sourceAppIconView`
  就一律走 `Image(systemName: "app.dashed")` 分支。

- **B. ClipboardPreviewItem 缺图片字节**：`PagedClipboardViewModel.swift:14-32`
  ```swift
  struct ClipboardPreviewItem: Identifiable, Equatable {
      let id: NSManagedObjectID
      let uuid: UUID?
      let type: String
      let contentPreview: String
      let sourceAppName: String?
      let sourceAppIconData: Data?
      let sourceAppIconCacheKey: String?
      let createdAt: Date?
  }
  ```
  没有 `imageData`，所以 image 类型的字节根本没有从 previewContext 携带到主线程。

- **C. ShelfCard 没消费图片字节**：`ShelfView.swift:706-716`（`ClipboardShelfCard.body`）
  ```swift
  case "image":
      placeholder("<image>")
  ```
  这一段在迁移到 preview 模型之前是 `if let data = item.data, let img = NSImage(data: data) { Image(nsImage: img)...}`。
  迁移时被替换成纯文字占位但没改回。

### 2.2 数据库现状（实际抽样 cheatsheet.sqlite）

```text
最近条目：image|活动监视器|icon=38|data=38（38 字节是 CoreData external blob reference token）
external blob 大小分布：96B, 22KB, 130KB ~ 4MB（图片）；图标普遍 130KB ~ 200KB
```

写入端是健全的；问题全在读取与渲染端。

## 3. 方案

### 3.1 修改清单

1. `cheatsheet/Models/ViewModels/PagedClipboardViewModel.swift`
   - `ClipboardPreviewItem` 增加 `let imageData: Data?`
   - 新增上限常量 `maxImagePreviewBytes = 2 * 1024 * 1024`（2MB）
   - `maxSourceAppIconBytes` 从 `64 * 1024` 改为 `512 * 1024`（512KB；覆盖现有图标体积，仍能挡住极端异常值）
   - `loadNextPreviewPage` 在映射时：
     - `imageData = (type == "image") ? cappedImageData(item.data, maxBytes: maxImagePreviewBytes) : nil`
     - 其余赋值不变

2. `cheatsheet/Views/Shelf/ShelfView.swift`
   - `ClipboardShelfCard` 的 `case "image":` 改为：
     ```swift
     case "image":
         if let data = item.imageData, let img = NSImage(data: data) {
             Image(nsImage: img)
                 .resizable()
                 .scaledToFit()
                 .frame(maxWidth: .infinity, maxHeight: .infinity)
         } else {
             placeholder("<image>")
         }
     ```

### 3.2 方案对比

| 方案 | 描述 | 评价 |
| --- | --- | --- |
| **A. 渲染端最小修复 + 阈值合理化（采用）** | 加 `imageData` 字段、放宽图标阈值、卡片正确渲染 | 改 ~15 行；不动写入端 / 数据模型；老数据立即恢复 |
| B. 写入端预处理 32×32 PNG + 老数据迁移 | 治本，体积小，但要写迁移脚本 | 改写入路径 + 一次性迁移；超出本任务范围 |
| C. 异步解码 + 全局图片缓存 | 性能更好，但需要重构卡片渲染 | 太大，独立任务 |

B/C 列入 follow-up。

### 3.3 边界

- 单条 image data 上限 2MB：超过则 fallback `<image>`。理由：当前预览面板一次最多 16 条，
  16 × 2MB = 32MB，量级可控；典型截图 2~4MB，超出的极端大图直接 fallback 用户体验不变差。
- 图标上限 512KB：实测最大 ~200KB，512KB 提供 2.5× 余量。
- 不解码到固定尺寸：`SourceAppIconCache` 已经在主线程做 `NSImage(data:)`，
  系统会自动选择合适分辨率位图渲染；这次不动。

## 4. 验收标准

1. `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -destination 'platform=macOS' build` 成功。
2. App 启动后底部横条剪贴板卡片：
   - 来源 App 图标显示出来（不再清一色 `app.dashed`）；
   - image 类型条目显示真实图片缩略；
   - 缺数据 / 体积超限时回退到 `app.dashed` 与 `<image>`。
3. grep `placeholder("<image>")` 仅剩一处（兜底分支），没有顶层无脑占位。
4. 复制图片再写入，新增条目卡片即时出现图片缩略（auto-merge → contextDidSave → 主队列 reset 预览）。

## 5. 工具、凭据和环境

- macOS 26.4.1, Xcode, Swift 5
- `xcodebuild`, `git`, `grep`
- 不需要外部凭据。

## 6. 本任务专属自循环编排

```text
第 0 轮：恢复事实
- git status 确认工作区
- 读 task §3、当前 PagedClipboardViewModel.swift / ShelfView.swift

第 1 轮：实施修复
- ClipboardPreviewItem 加 imageData 字段
- 加 maxImagePreviewBytes / cappedImageData
- 调整 maxSourceAppIconBytes
- ClipboardShelfCard image case 真渲染

第 2 轮：验证
- xcodebuild build
- grep placeholder("<image>") 与 app.dashed
- 把构建结果写回 §8、§9

第 3 轮：写回 + 提交
- 更新 00-index.md（task 11 状态）
- 更新本 task §0、§8、§9
- git add + commit（Conventional Commits）

第 4 轮：决定继续或停止
- 之后再无 ready/approved task → 按 unattended 规则收尾，退出无人值守
```

## 7. 任务队列

- [ ] 第 1 轮：改 PagedClipboardViewModel.swift（ClipboardPreviewItem + 阈值 + 映射）
- [ ] 第 1 轮：改 ShelfView.swift（ClipboardShelfCard image case）
- [ ] 第 2 轮：xcodebuild
- [ ] 第 2 轮：grep 同源
- [ ] 第 3 轮：写回 + commit
- [ ] 第 4 轮：决定退出无人值守

## 8. 执行记录

### 第 1 轮（2026-05-25 12:39 - 12:41）

- 改文件：
  - `cheatsheet/Models/ViewModels/PagedClipboardViewModel.swift`
    - L26-28：`ClipboardPreviewItem` 增加 `imageData: Data?` 字段
    - L52-58：`maxSourceAppIconBytes` 从 `64 * 1024` 改为 `512 * 1024`；新增
      `maxImagePreviewBytes = 2 * 1024 * 1024`
    - `loadNextPreviewPage` 映射处：补 `let type` 局部变量，`imageData` 仅在
      `type == "image"` 时通过 `cappedImageData` 携带
    - 新增 `cappedImageData(_:maxBytes:)` 私有静态方法
  - `cheatsheet/Views/Shelf/ShelfView.swift`
    - `ClipboardShelfCard.body` 的 `case "image":` 改为
      `if let data = item.imageData, let img = NSImage(data: data) { Image(nsImage: img)... } else { placeholder("<image>") }`

### 第 2 轮（2026-05-25 12:41 - 12:42）

- diagnostics：两个文件 `No diagnostics found`
- grep 同源：
  - `placeholder("<image>")` 仅剩 `ShelfView.swift:715` 一处（兜底分支）
- 构建：`xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -destination 'platform=macOS' -configuration Debug build`
  → `** BUILD SUCCEEDED **`，0 error

## 9. 决策和证据

### 9.1 阈值校准依据

```text
图标 PNG 实测分布（cheatsheet.sqlite 的 _EXTERNAL_DATA 抽样）：
  - 96B（异常 / 已 sanitize）
  - 22KB（小型 App icon）
  - 130KB ~ 200KB+（绝大多数）

旧阈值 64KB 命中率：~0%（除 22KB 外几乎全部被裁断）
新阈值 512KB：覆盖目前所见全部图标，提供 2.5× 余量

图片 data PNG 实测最大值：~4MB
新阈值 2MB：覆盖典型截图（1280×800 PNG ~ 1~3MB），
            极端大图回退到 <image> 占位。
```

### 9.2 修改前后对照

`PagedClipboardViewModel.loadNextPreviewPage` 映射部分：

修改前（image 字节没被带过来）：

```swift
return ClipboardPreviewItem(
    id: item.objectID,
    uuid: item.id,
    type: item.type ?? "text",
    contentPreview: ...,
    sourceAppName: item.sourceAppName,
    sourceAppIconData: iconData,              // ★ 全 nil（64KB 裁掉）
    sourceAppIconCacheKey: ...,
    createdAt: item.createdAt
    // ★ 没有 imageData
)
```

修改后：

```swift
let type = item.type ?? "text"
let iconData = Self.cappedSourceAppIconData(item.sourceAppIcon, maxBytes: maxSourceAppIconBytes)
let imageData: Data? = (type == "image")
    ? Self.cappedImageData(item.data, maxBytes: maxImagePreviewBytes)
    : nil
return ClipboardPreviewItem(
    ...
    sourceAppIconData: iconData,              // ★ 实际命中
    ...
    imageData: imageData,                     // ★ 新字段
    ...
)
```

`ShelfView.ClipboardShelfCard.body` 的 image case：

修改前：

```swift
case "image":
    placeholder("<image>")                    // ★ 永远占位
```

修改后：

```swift
case "image":
    if let data = item.imageData, let img = NSImage(data: data) {
        Image(nsImage: img)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
        placeholder("<image>")                // ★ 仅兜底
    }
```

### 9.3 follow-up（不在本任务范围）

1. 写入端用 NSImage 解码图标到 32×32 PNG（< 8KB）治本，且配合一次性数据迁移压缩老条目。
2. 异步图片解码 + 全局图片缓存（`SourceAppIconCache` 模式扩展到大图）。
3. `previewContext.automaticallyMergesChangesFromParent = true` 是空操作（task 10 follow-up）。

## 10. 停止条件

- 构建失败且根因不在本次修复范围内
- 图片 / 图标渲染需要异步解码或缓存才能稳定（独立任务）
- Karl 输入"退出无人值守模式"
