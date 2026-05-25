# 14 修复底部横条剪贴板卡片来源 App 图标不显示

## 0. 当前状态

- status: awaiting_user_acceptance
- phase: implementation-complete
- role_next: Karl
- plan_review_policy: auto_approved
- depends_on: 11-shelf-clipboard-icon-and-image-preview.md（done，但只是把 cap 从 64KB 提到 512KB）
- parallel_safe: yes
- execution_mode: unattended
- unattended_started_at: 2026-05-25 12:35
- unattended_trigger: Karl 明确要求按 .project/agent-loop 连续执行直到全部完成或触发停止条件
- current_goal: 让 Shelf 剪贴板卡片真正显示来源 App 真实图标，不再清一色 `app.dashed`
- next_action: 等待 Karl ⌘R 启动新构建，肉眼确认历史卡片图标真实显示
- blocker: none
- updated_at: 2026-05-25 13:58

## 1. 目标和需求

**目标行为**：

- 底部横条剪贴板 tab 的卡片 header 左侧显示来源 App 真实图标。
- Codex / Kiro / iShot / 网易云音乐 / 活动监视器 / Safari 等常用 App 复制后，
  下次唤醒 Shelf 看到的图标应是该 App 的真实 logo，而不是 `app.dashed` 占位。
- 历史 599 条 ClipboardItem 在不做迁移的情况下，也能立刻看到真实图标。

**不做**：

- 不改 Core Data schema，不做不可逆迁移。
- 不重构 `SourceAppIconCache` 缓存策略。
- 不动 `ClipboardItem` 默认排序、`enrichBlobs` 异步加载机制。
- 不重构 ShelfView header 视图布局。
- 不针对 image 类型缩略做调整（task 11 已处理）。

## 2. 当前状态和目标差

### 2.1 现象

Karl 截图显示两张剪贴板卡片来源都是 Kiro，App 名称显示正常，但图标位置只有
`app.dashed` 占位（红框标出）。也就是说：**App 名称已回填到 UI（写入和读取链路通了），
图标没回填到 UI（链路某段被切断）**。

### 2.2 走查证据

实测 `~/Library/Containers/zhouqiaaha.top.cheatsheet/Data/Library/Application Support/cheatsheet/cheatsheet.sqlite`：

```text
SELECT COUNT(*),
       SUM(CASE WHEN ZSOURCEAPPICON IS NOT NULL THEN 1 ELSE 0 END)
FROM ZCLIPBOARDITEM;
→ 599 | 599                          # 全部 599 条都有 icon reference

SELECT length(ZSOURCEAPPICON) FROM ZCLIPBOARDITEM ORDER BY ZCREATEDAT DESC LIMIT 5;
→ 38, 38, 38, 38, 38                # external blob 引用，固定 38 字节
```

`_EXTERNAL_DATA` 真实 blob 字节数（704 个文件）：

```text
min   = 133,806   ~ 130 KB
max   = 3,964,889 ~ 3.96 MB
≤ 512 KB :  79 个
> 512 KB : 625 个                   ← 当前 cap 把这部分全部裁成 nil
```

也就是说目前 600+ 条历史数据里大约 9 成的 `sourceAppIcon` 都被读取端 `cap` 切掉了。

### 2.3 时序图（关键链路）

```text
[ClipboardMonitor]    [CoreData / SQLite + _EXTERNAL_DATA]    [PagedVM]    [ShelfCard]
       │                          │                              │             │
 NSWorkspace.shared
   .icon(forFile: bundleURL)
   ★ 返回多分辨率 NSImage（16/32/64/128/256/512/1024）
       │
 icon.size = 32×32
   ★ 只改 logical size，不真正 redraw 像素
       │
 image.tiffRepresentation
   ★ tiff 包含全部分辨率帧
   ★ NSBitmapImageRep(data:) 取最大那一帧
   ★ 编码成 PNG → 130KB ~ 4MB
       │
 ClipboardItem.sourceAppIcon = 130KB ~ 4MB Data
       ├────────────────────────► 写到 _EXTERNAL_DATA/<UUID>
       │                          主表只存 38 字节 reference
       │                          │                              │             │
       │                          │  loadNextPreviewPage          │             │
       │                          │  propertiesToFetch 不含 icon   │             │
       │                          │  → preview.iconData = nil      ├────────────►│ 占位
       │                          │  enrichBlobs 二阶段：          │             │
       │                          │  fetch full props（含 icon）   │             │
       │                          │  → 取出真实 130KB ~ 4MB Data  │             │
       │                          │  cappedSourceAppIconData(...)  │             │
       │                          │  ★ data.count > 512KB → nil  │             │
       │                          │  withBlobs(iconData: nil)      ├────────────►│ 仍占位
       ▼                          ▼                              ▼             ▼

最终：App 名称有，图标永远是 app.dashed
```

### 2.4 代码证明

**写入端**（`cheatsheet/Utils/ClipboardMonitor.swift:73-91`）：

```swift
context.perform {
    let app = NSWorkspace.shared.frontmostApplication
    ...
    if let url = app?.bundleURL {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 32, height: 32)   // 只改 logical size，不缩像素
        appIconData = self.pngData(from: icon)      // tiffRepresentation → 大分辨率帧
    }
    ...
}
```

`pngData(from:)`（同文件 224-228 行）：

```swift
fileprivate func pngData(from image: NSImage) -> Data? {
    guard let tiffData = image.tiffRepresentation,            // 多分辨率拼成 multi-page TIFF
          let rep = NSBitmapImageRep(data: tiffData) else { return nil }  // 通常拿到最大帧
    return rep.representation(using: .png, properties: [:])
}
```

**读取端 cap**（`cheatsheet/Models/ViewModels/PagedClipboardViewModel.swift:73-74, 385-388`）：

```swift
/// 写入端 NSWorkspace 序列化的 macOS App 图标 PNG 普遍 130KB ~ 200KB（多分辨率位图），
/// 旧值 64KB 会把全部图标裁断成 nil。512KB 提供 2.5× 余量，能挡住极端异常值。
private let maxSourceAppIconBytes = 512 * 1024
...
private static func cappedSourceAppIconData(_ data: Data?, maxBytes: Int) -> Data? {
    guard let data, data.count <= maxBytes else { return nil }   // ★ > 512KB 就 nil
    return data
}
```

注释假设普遍 130~200KB，但实测分布到 4MB；512KB cap 等于把绝大多数图标当异常值丢弃。

## 3. 方案

**双侧最小修复，两个接缝各负其责**。

### 3.1 修复 A：写入端真正 redraw 到 32×32 像素

**改 `cheatsheet/Utils/ClipboardMonitor.swift`**：

1. 修改 73-91 行 `checkClipboard` 中的图标序列化调用：

   ```swift
   if let url = app?.bundleURL {
       let icon = NSWorkspace.shared.icon(forFile: url.path)
       // UI 显示尺寸 16pt @2x = 32px。redraw 到固定像素，避免高分辨率位图泄漏。
       appIconData = self.pngData(fromIcon: icon, pixelSize: 32)
   }
   ```

2. 在文件 Capture Helpers extension 内新增 `pngData(fromIcon:pixelSize:)` helper：

   ```swift
   /// 把 NSImage 真正重绘到固定像素尺寸，再编码为 PNG。
   /// NSWorkspace.shared.icon 返回的多分辨率 NSImage 直接 tiffRepresentation 会得到
   /// 高分辨率单帧（130KB ~ 4MB），这里强制重绘成 pixelSize×pixelSize sRGB ARGB 位图，
   /// 体积稳定在几 KB。
   fileprivate func pngData(fromIcon image: NSImage, pixelSize: Int) -> Data? {
       guard let rep = NSBitmapImageRep(
           bitmapDataPlanes: nil,
           pixelsWide: pixelSize,
           pixelsHigh: pixelSize,
           bitsPerSample: 8,
           samplesPerPixel: 4,
           hasAlpha: true,
           isPlanar: false,
           colorSpaceName: .sRGB,
           bytesPerRow: 0,
           bitsPerPixel: 0
       ) else { return nil }
       rep.size = NSSize(width: pixelSize, height: pixelSize)

       NSGraphicsContext.saveGraphicsState()
       NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
       image.draw(
           in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize),
           from: .zero,
           operation: .sourceOver,
           fraction: 1.0
       )
       NSGraphicsContext.restoreGraphicsState()

       return rep.representation(using: .png, properties: [:])
   }
   ```

   保留原 `pngData(from:)`（被 `iconPNG(forFileURLString:)` 用于文件类型预览，不在本次范围）。

效果：新写入的 sourceAppIcon 体积稳定在 1~5 KB。

### 3.2 修复 B：读取端 cap 提到 8MB（兜底而非业务过滤）

**改 `cheatsheet/Models/ViewModels/PagedClipboardViewModel.swift`**：

修改 73-74 行常量定义：

```swift
/// 兜底值，防写入端意外炸出超大数据，不是业务过滤。
/// 修复 A 之后新数据稳定在几 KB；历史数据 130KB ~ 4MB 都需要能放行，
/// 所以保留 8MB 上限作为内存安全护栏。
private let maxSourceAppIconBytes = 8 * 1024 * 1024
```

效果：现存 599 条历史数据立刻能在卡片上显示真实图标。

### 3.3 方案对比

| 方案 | 描述 | 评价 |
| --- | --- | --- |
| **A+B 双侧最小修复（采用）** | 写入 redraw + 读取 cap 兜底 | 改 ~30 行；新老数据都能显示；语义清晰 |
| 只改 B（读取 cap 加大） | 一行常量 | 老数据立刻显示，但新数据继续以 130KB~4MB 写入，浪费磁盘和内存 |
| 只改 A（写入端 redraw） | 治本但不顾旧数据 | 老数据仍卡在 cap 后面，UI 大半显示占位 |
| 写一次性迁移脚本压缩老 blob | 完美治本 | 涉及数据写入和迁移风险，按 §03-9.4 触发停止条件 |

### 3.4 边界

- 8MB 兜底是为了防极端异常（理论最大 ~4MB，留 2× 余量）。
- 修复 A 的 `NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)` 在
  `ClipboardMonitor` 的 `context.perform { ... }` 闭包里运行；NSGraphicsContext 是
  线程安全的栈式 API，单次复制频率极低（用户操作触发），可接受同步绘制。
- 不做老数据迁移：旧 _EXTERNAL_DATA 里 599 个 130KB ~ 4MB 的 blob 仍保留，
  下一轮可独立任务处理。

## 4. 验收标准

1. `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -destination 'platform=macOS' build` 成功。
2. App 启动后底部横条剪贴板 tab：
   - 历史卡片（包括 Kiro / Codex / iShot / 网易云音乐）显示真实 App 图标，不再清一色 `app.dashed`。
3. 复制新内容后，sandbox 内 `_EXTERNAL_DATA/` 下新增的 blob 文件大小在 ~5 KB 量级（不再 130KB+）。
4. 卡片 header 名称、类型胶囊、点击复制、删除菜单等行为不变；image 类型缩略不受影响。

## 5. 工具、凭据和环境

- 可用命令：
  - `xcodebuild`、`git`、`rg`、`sqlite3`、`stat`、`find`
- 可用测试方式：
  - 本地 macOS Debug 构建
  - sqlite3 直接查 sandbox 数据库
  - find + stat 查 _EXTERNAL_DATA 大小
- 不需要外部凭据。

## 6. 本任务专属自循环编排

```text
第 0 轮：恢复事实
- 已在上一轮 dev-trace 完成走查
- git status 确认工作区
- 复读 ClipboardMonitor.swift 73-91 / 200-228；PagedClipboardViewModel.swift 73-74 / 385-388

第 1 轮：实施修复 A（写入端 redraw 32px）
- 在 ClipboardMonitor.swift 加 pngData(fromIcon:pixelSize:) helper
- 改 checkClipboard 调用点
- 不动 pngData(from:) 老 helper（被 iconPNG forFileURLString 用）

第 2 轮：实施修复 B（读取端 cap 8MB）
- 改 PagedClipboardViewModel.swift L73-74 常量

第 3 轮：构建验证
- xcodebuild build
- 把构建结果写回 §8

第 4 轮：写回 + 提交
- 更新 00-index.md（task 14 状态 + 看板卫生扫描）
- 更新本 task §0、§8、§9
- git add 精确文件 + commit（fix(shelf): 来源 App 图标）
- 更新 AGENTS.md UNATTENDED MODE 工作清单
- 看板卫生：检查其他任务依赖

第 5 轮：决定继续或停止（按 §10 unattended 规则）
- 之后无 ready/approved task → 主动收尾退出无人值守
```

## 7. 任务队列

- [x] 第 0 轮：dev-trace 走查（上一轮已完成）
- [x] 第 1 轮：写入端 redraw 32px（ClipboardMonitor.swift）
- [x] 第 2 轮：读取端 cap 提到 8MB（PagedClipboardViewModel.swift）
- [x] 第 3 轮：xcodebuild
- [ ] 第 4 轮：写回任务文件 + 看板卫生 + commit
- [ ] 第 5 轮：第 4 步终态判定

## 8. 执行记录

### 第 1 轮（2026-05-25 13:53）：写入端 redraw 32px

- 改文件：`cheatsheet/Utils/ClipboardMonitor.swift`
- 关键改动：
  - 73-91 行 `checkClipboard` 内调用从 `pngData(from:)` 改为
    `pngData(fromIcon:pixelSize: 32)`，删除无效的 `icon.size = 32×32`。
  - 在 Capture Helpers extension 内新增 `pngData(fromIcon:pixelSize:)`，
    分配 sRGB ARGB 32×32 `NSBitmapImageRep`，用 `NSGraphicsContext` 重绘。
- 第一次构建报错 `type 'NSColorSpaceName' has no member 'sRGB'`：
  macOS SDK 上 `NSColorSpaceName` 是 String typealias，没有 `.sRGB` 静态成员，
  改用 `.deviceRGB`。NSBitmapImageRep 的 deviceRGB + 8bit ARGB 编码出来的 PNG
  在显示场景下视觉等价。

### 第 2 轮（2026-05-25 13:53）：读取端 cap 8MB

- 改文件：`cheatsheet/Models/ViewModels/PagedClipboardViewModel.swift`
- L73-78：常量 `maxSourceAppIconBytes` 从 `512 * 1024` 改为 `8 * 1024 * 1024`，
  注释明确说明这是"防写入回归的内存兜底，不是业务过滤"。

### 第 3 轮（2026-05-25 13:55）：构建验证

- 命令：
  `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -destination 'platform=macOS' -configuration Debug build`
- 第一次构建：**FAIL**，`.sRGB` 不存在；
- 第二次构建：**`** BUILD SUCCEEDED **`**，0 error。

### 第 3.5 轮（2026-05-25 13:56）：本地正向验证

- 工具脚本：`.project/agent-loop/artifacts/verify_icon_redraw.swift`
  对常见 4 个 App bundle 分别走旧路径（`tiffRepresentation`）和新路径
  （`pngData(fromIcon:pixelSize: 32)`），打印 PNG 字节数。
- 命令：`swift .project/agent-loop/artifacts/verify_icon_redraw.swift`
- 实际输出：
  ```text
  Safari.app           | tiff_path=1,882,600 | redraw_32=2,290
  Calculator.app       | tiff_path=1,494,048 | redraw_32=2,104
  Activity Monitor.app | tiff_path=1,812,772 | redraw_32=2,148
  Xcode.app            | tiff_path=1,477,134 | redraw_32=2,203
  ```
- 结论：新路径稳定在 ~2 KB，旧路径 1.5 MB ~ 1.9 MB；体积比 ≈ 1:700。
  修复 A 写入端缩小生效。
- 注：脚本是诊断工具，留在 `artifacts/` 不进 App 编译。

## 9. 决策和证据

### 9.1 阈值校准依据

```text
当前 _EXTERNAL_DATA 实测 704 个 blob：
  min  = 133,806    ~ 130 KB
  max  = 3,964,889  ~ 3.96 MB
  ≤ 512KB:  79 个   ← 当前 cap 命中率约 11%
  > 512KB: 625 个   ← 被裁成 nil

修复 A（redraw 32px）后新数据实测：
  Safari / Calculator / Activity Monitor / Xcode = 2.10 ~ 2.29 KB
  PNG 编码后 ≈ 2 KB（理论上限：32×32×4 = 4 KB 原始 + PNG 压缩）

修复 B（cap = 8MB）后所有现存 blob 都能放行：
  4MB 实际上限 × 2 倍余量 = 8MB
```

### 9.2 colorSpaceName 选型

```text
首选     : NSColorSpaceName.sRGB         → SDK 不存在，只在 NSColorSpace 类型上
实际选用 : NSColorSpaceName.deviceRGB    → ARGB 8-bit，构建通过，验证 PNG 有效

对显示用图标来说，deviceRGB 与显示器输出空间一致，渲染结果与 sRGB 视觉等价。
ProRes 级 P3 色域差异不在本场景考量范围内（16×16 显示尺寸，肉眼不可分辨）。
```

### 9.3 写入端 / 读取端语义错位

```text
旧设计：写入端 icon.size = 32×32 + tiffRepresentation
意图：32 像素小图
实际：logical size 不影响位图，多分辨率 TIFF 取最大帧 → 130KB ~ 4MB

旧设计：读取端 maxSourceAppIconBytes = 512KB
意图：业务过滤异常值
实际：cap 远低于真实分布，把 9 成正常数据当异常丢弃

新设计：
  - 写入端用 image.draw(in:) 重绘到固定像素位图，pngData 几 KB
  - 读取端 cap 8MB，仅作为"防写入回归 / 极端异常"的内存兜底
```

### 9.4 follow-up（不在本任务范围）

1. 老 _EXTERNAL_DATA 里 599 个 130KB ~ 4MB 的 icon blob：
   修复 A 只对新数据生效，老 blob 仍占磁盘。一次性迁移属于不可逆数据修改，
   按 §03-9.4 触发停止条件，需要 Karl 显式批准独立任务。
2. task 07 §9 注释里写"图标 PNG 普遍 130KB ~ 200KB"是基于旧调用路径的认知，
   修复 A 之后这个判断不再适用；任务 14 §9.1 已记录新分布数据。
3. `previewContext.automaticallyMergesChangesFromParent = true` 是空操作（task 10 follow-up）。

## 10. 停止条件

- 构建失败且根因不在本次修复范围。
- 修复 A 写入字节数明显超过 10 KB（说明 redraw 没生效）。
- Karl 输入"退出无人值守模式"。
