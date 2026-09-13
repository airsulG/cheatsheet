# 09 Shelf 打开动画顺滑度

## 0. 当前状态
- 当前阶段：done
- 当前分支：main
- 当前是否允许自动执行：允许，Karl 已确认 `ok 开始`
- 当前阻塞：none
- 下一步：等待 Karl 在真实 120Hz 屏幕上验证快捷键打开手感

## 1. 目标和需求
- 关联 EARS：底部 Shelf 面板打开体验、剪贴板卡片性能
- 用户真正想解决的问题：
  - 使用快捷键从底部拉起 Shelf 时，动画中会看到明显卡顿。
  - 卡顿表现不是水平滚动最大问题，而是从底部展开到完全展开时出现几次明显延时。
- 最终要看到的结果：
  - Shelf 使用快捷键打开时更顺滑。
  - 面板视觉上仍然从底部拉起。
  - 打开动画期间不再反复改变窗口高度触发整排卡片重排。
- 成功标准：
  - `ShelfWindowController.show()` 不再从 `0.1` 高度动画到目标高度。
  - 打开时先设置最终高度，再从屏幕底部外侧位移动画到贴底位置。
  - 关闭时同样保持高度不变，向屏幕底部外侧位移动画。
  - 移除卡片区域打开时的二次 offset/opacity 弹入动画。
  - 来源 App 图标不在 SwiftUI body 中重复 `NSImage(data:)` 解码。
- 不做什么：
  - 不修改 Core Data schema。
  - 不改变面板高度拖拽功能。
  - 不重写剪贴板分页加载。
  - 不触碰未跟踪备份 JSON。
- 已确认内容：
  - Karl 确认按推荐方案开始。
- 未确认内容：
  - none

## 2. 当前状态和目标差
- 当前系统是什么样：
  - `ShelfWindowController.show()` 先把 `NSPanel` 高度设为 `0.1`，再动画到目标高度。
  - `ShelfView` 使用 `GeometryReader` 根据窗口高度计算 `cardHeight`。
  - `ClipboardShelfCard` 根据 `cardHeight` 计算文本行数。
  - 卡片区域还有 `.offset + .opacity + spring` 二次进入动画。
  - `sourceAppIconView` 在 body 中执行 `NSImage(data:)`。
- 目标系统应该是什么样：
  - 打开/关闭动画只移动面板位置，不改变面板高度。
  - SwiftUI 只按最终高度布局。
  - 来源图标只解码一次并复用。
- 差距在哪里：
  - 当前窗口高度动画会让卡片高度和文本行数在动画过程中连续变化。
  - 当前 body 中图标解码会给打开期间的初次渲染增加主线程工作。
- 相关文件 / 函数 / 配置：
  - `cheatsheet/Utils/ShelfWindowController.swift`
  - `cheatsheet/Views/Shelf/ShelfView.swift`
  - `cheatsheet/Models/ViewModels/PagedClipboardViewModel.swift`
  - `.project/agent-loop/00-index.md`
- 已掌握证据：
  - `show()` 使用 `panel.animator().setFrame` 从高度 `0.1` 动到目标高度。
  - `ShelfView` 的卡片高度由 `GeometryReader` 每次读取窗口高度后计算。
  - `sourceAppIconView` 当前直接用 `NSImage(data:)`。

## 3. 方案
- 推荐方案：
  - 打开：将窗口设置为最终高度，但 y 放在屏幕底部外侧；orderFront 后动画 y 到屏幕底部。
  - 关闭：保持当前高度，动画 y 到屏幕底部外侧，结束后 orderOut。
  - 移除 `appeared` 驱动的卡片区域 offset/opacity/spring。
  - 给来源 App 图标增加进程内缓存，预览模型提供图标缓存 key。
- 为什么选这个方案：
  - 面板大小固定后，SwiftUI 不会在打开动画每一帧重排卡片。
  - 位移动画仍保留从底部拉起的视觉。
  - 图标缓存减少打开时和滚动时重复解码。
- 不选哪些方案：
  - 不先做 Instruments，因为代码里已有明确的高度动画重排证据，可以先做最小修复。
  - 不删除玻璃背景，因为用户当前指出的是打开动画卡顿，先改最直接原因。
  - 不改横向滚动结构，因为这不是当前最大问题。
- 接驳点：
  - `ShelfWindowController.show()` / `hide()`
  - `ShelfView` 卡片区域动画修饰符
  - `ClipboardPreviewItem` 和 `ClipboardShelfCard.sourceAppIconView`
- 风险和边界：
  - 窗口在屏幕外侧起始位置需要保持宽度和高度正确。
  - 图标缓存 key 要在后台生成，避免把哈希成本搬到 body 中。

## 4. 验收标准
- 必须满足的结果：
  - 快捷键打开 Shelf 时不再通过高度变化展开。
  - 视觉上仍从底部拉起。
  - 高度拖拽保存功能不受影响。
  - App 图标继续显示。
- 必须通过的测试：
  - `git diff --check`
  - `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -configuration Debug build`
- 必须产出的截图 / 报告 / 日志：
  - 本轮不强制截图；真实手感需要 Karl 本机试用确认。
- 用户可见的完成表现：
  - 快捷键拉起时卡顿减少，展开过程更像整片面板平滑上滑。

## 5. 工具、凭据和环境
- 可用命令：
  - `rg`
  - `sed`
  - `git diff --check`
  - `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -configuration Debug build`
- 可用测试方式：
  - 本地 macOS Debug 构建。
- 可用账号、token、key、登录态或外部服务：
  - none
- 凭据用途：
  - none
- 凭据读取方式：
  - none
- 使用边界：
  - 不提交，除非用户明确要求。
  - 不部署。
- 禁止动作：
  - 不删除文件。
  - 不回滚用户已有未提交改动。
  - 不触碰未跟踪备份 JSON。

## 6. 本任务专属自循环编排
- 为什么这个任务适合自循环：
  - 根因已缩小到打开动画链路，改动范围集中且可构建验证。
- 本任务的循环阶段：
  - 记录任务。
  - 修改窗口打开/关闭动画。
  - 移除卡片二次弹入动画。
  - 增加图标缓存。
  - 构建验证。
  - 写回记录。
- 每一轮从哪里开始：
  - 从 `ShelfWindowController.show()` 和 `ShelfView` 打开期间的动画修饰符开始。
- 每一轮怎么选择下一项工作：
  - 先改高度动画，再减少 body 重复工作。
- 每一轮允许自主执行哪些动作：
  - 修改 Swift 文件和 agent-loop 文档。
  - 运行本地构建验证。
- 每一轮必须做哪些验证：
  - `git diff --check`
  - `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -configuration Debug build`
- 每一轮必须写回哪些记录：
  - 修改文件、验证命令、验证结果、剩余风险。
- 什么情况下自动进入下一轮：
  - 构建失败且错误明确时继续修复。
- 什么情况下必须停止：
  - 需要改窗口结构为全新实现。
  - 构建失败且存在多个合理修复方向。
- 这个编排为什么适合当前任务：
  - 打开卡顿来自动画链路，按动画链路逐段减少重排最直接。

## 7. 任务队列
- [x] 创建 agent-loop 任务文档
- [x] 改打开动画为固定高度位移动画
- [x] 改关闭动画为固定高度位移动画
- [x] 移除卡片区域二次弹入动画
- [x] 增加来源 App 图标缓存
- [x] 运行本地验证
- [x] 写回执行记录和索引状态

## 8. 执行记录
- 时间：2026-05-20 12:25 CST
- 做了什么：创建本任务文档，固定本轮优化范围。
- 修改文件：
  - `.project/agent-loop/09-shelf-open-animation-smoothness.md`
- 运行命令：
  - `date '+%Y-%m-%d %H:%M %Z'`
  - `git branch --show-current && git status --short`
  - `sed -n '1,130p' cheatsheet/Utils/ShelfWindowController.swift`
  - `sed -n '1,310p;668,766p' cheatsheet/Views/Shelf/ShelfView.swift`
  - `sed -n '1,90p' .project/agent-loop/00-index.md`
- 实际输出：确认分支为 `main`；确认前序未提交改动存在；确认打开动画仍在改变窗口高度，卡片区域仍有二次弹入动画。
- 结果：准备进入代码修改。
- 下一步：修改窗口动画和图标缓存。

- 时间：2026-05-20 12:27 CST
- 做了什么：
  - `ShelfWindowController.show()` 改为先设置最终高度，然后从屏幕底部外侧向上移动到贴底位置。
  - `ShelfWindowController.hide()` 改为保持当前高度，向屏幕底部外侧移动后隐藏。
  - 移除 `ShelfView` 卡片区域的 `appeared`、`offset`、`opacity` 和 spring 二次进入动画。
  - 给 `ClipboardPreviewItem` 增加 `sourceAppIconCacheKey`。
  - 在后台预览生成时按图标数据生成缓存 key。
  - 新增 `SourceAppIconCache`，让来源 App 图标只在第一次需要时从 `Data` 解码为 `NSImage`，之后复用缓存。
- 修改文件：
  - `cheatsheet/Utils/ShelfWindowController.swift`
  - `cheatsheet/Views/Shelf/ShelfView.swift`
  - `cheatsheet/Models/ViewModels/PagedClipboardViewModel.swift`
  - `.project/agent-loop/09-shelf-open-animation-smoothness.md`
  - `.project/agent-loop/00-index.md`
- 运行命令：
  - `git diff --check`
  - `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -configuration Debug build`
- 实际输出：
  - `git diff --check` 无输出，表示通过。
  - 第一次构建失败，原因是 `page.map` 多行闭包需要显式 `return ClipboardPreviewItem(...)`。
  - 修复后重新构建，输出 `** BUILD SUCCEEDED **`。
  - 构建仍有既有警告：`CategorySidebarView` Preview 的 `@State` 警告、部分旧 `onChange(of:perform:)` 弃用警告、AppIntents metadata skipped。
- 结果：代码修改和本地构建验证完成。
- 下一步：等待真实 UI 手感验证。

## 9. 决策和证据
- 决策：打开/关闭动画从改变高度改为改变 y 坐标。
- 原因：高度变化会触发 SwiftUI 每帧重新计算卡片高度和文本行数。
- 证据：`ShelfWindowController.show()` 从高度 0.1 动到目标高度；`ShelfView` 通过 `GeometryReader` 计算 `cardHeight`。
- 影响：打开时窗口先按最终高度布局，再整体位移进入屏幕。

- 决策：移除卡片区域二次弹入动画。
- 原因：窗口动画和内容 spring 动画叠加，会增加打开期间的视觉和布局工作。
- 证据：`ShelfView` 卡片区域使用 `.offset(y: appeared ? 0 : 20)`、`.opacity(...)`、`.animation(...)`。
- 影响：Shelf 打开时以面板整体动画为主。

- 决策：来源 App 图标增加缓存 key 和 `NSCache`。
- 原因：打开期间 SwiftUI body 可能多次求值，直接 `NSImage(data:)` 会重复解码。
- 证据：`sourceAppIconView` 原来在 body 中直接对 `item.sourceAppIconData` 执行 `NSImage(data:)`。
- 影响：图标数据仍来自轻量预览，但每个相同图标只解码一次。

## 10. 停止条件
- 需要用户确认的情况：
  - 需要改为完全自定义窗口层。
  - 需要牺牲现有贴底行为。
- 高风险动作：
  - 删除文件、回滚分支、修改数据库结构。
- 工具或凭据缺失：
  - none
- 测试失败且存在多个合理修复方向：
  - 暂停说明。
- 需求边界变化：
  - 如果要做系统级性能分析和 Instruments 采样，另开任务。
