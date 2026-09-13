# 08 Shelf 面板拖拽调高和长内容预览

## 0. 当前状态
- 当前阶段：done
- 当前分支：main
- 当前是否允许自动执行：允许，Karl 已确认 `ok 开始`
- 当前阻塞：none
- 下一步：等待 Karl 在真实应用中拖拽上边缘验证手感和显示高度

## 1. 目标和需求
- 关联 EARS：底部 Shelf 面板、剪贴板长内容预览、卡片阅读效率
- 用户真正想解决的问题：
  - 频繁复制的内容可能是很长的提示词。
  - 当前底部面板固定高度，卡片只显示前面几句话，无法判断提示词真实作用。
- 最终要看到的结果：
  - 可以拖拽底部 Shelf 面板上边缘调整高度。
  - 调整后的高度会保存，下次打开继续使用。
  - 面板变高后，卡片本身变高，剪贴板长文本显示更多内容。
- 成功标准：
  - 上边缘有可拖拽热区，不破坏现有顶部工具区点击。
  - 拖动时 `NSPanel` 底边仍贴住屏幕底部，只向上增高或变矮。
  - 高度限制在安全范围内，避免拖到过小或遮满屏幕。
  - 卡片高度跟随面板高度增长。
  - 剪贴板文本行数跟随卡片高度增长。
  - 轻量剪贴板预览字符数提高，但仍不读取剪贴板二进制 `data`。
- 不做什么：
  - 不修改 Core Data schema。
  - 不恢复剪贴板图片/RTF/文件正文预览。
  - 不改横向卡片宽度。
  - 不触碰未跟踪备份 JSON。
- 已确认内容：
  - Karl 同意按推荐方案开始。
- 未确认内容：
  - none

## 2. 当前状态和目标差
- 当前系统是什么样：
  - `ShelfWindowController.show()` 目标高度固定为 `300`。
  - `ShelfWindowController.ensurePanel()` 初始高度固定为 `300`。
  - `ShelfView` 自身 `frame(minHeight: 300)`。
  - `ShelfView` 中卡片最大高度固定为 `380`。
  - `ClipboardShelfCard.textPreview` 固定 `lineLimit(10)`。
  - `PagedClipboardViewModel` 轻量预览最多取 `500` 字。
- 目标系统应该是什么样：
  - 面板高度有统一设置来源。
  - SwiftUI 顶部拖拽热区调用窗口控制器实时调整面板高度。
  - 卡片和文本预览根据实际面板高度显示更多内容。
- 差距在哪里：
  - 高度控制分散在窗口控制器和 SwiftUI view 中。
  - 内容行数仍固定，窗口变高后不一定显示更多文本。
- 相关文件 / 函数 / 配置：
  - `cheatsheet/Utils/ShelfWindowController.swift`
  - `cheatsheet/Views/Shelf/ShelfView.swift`
  - `cheatsheet/Models/ViewModels/PagedClipboardViewModel.swift`
  - `.project/agent-loop/00-index.md`
- 已掌握证据：
  - 代码读取确认窗口和卡片高度均有硬编码。
  - 代码读取确认剪贴板预览仍有限制行数和字符数。

## 3. 方案
- 推荐方案：
  - 新增 `ShelfPanelHeightSettings`，统一保存默认高度、最小高度、最大高度和 `UserDefaults` key。
  - `ShelfWindowController` 使用保存高度展示面板，并提供 `currentHeight()`、`resize(to:persist:)`、`resizeFromTopDrag(startHeight:translationY:persist:)`。
  - `ShelfView` 顶部叠加 8pt 拖拽热区，拖动时实时调用窗口控制器。
  - `ShelfView` 去掉卡片最大高度过低限制，让卡片高度随面板高度增长到面板上限。
  - `ClipboardShelfCard` 根据卡片高度计算文本行数。
  - `PagedClipboardViewModel` 将轻量预览字符上限从 500 提到 2000。
- 为什么选这个方案：
  - 贴底 `NSPanel` 不适合直接用系统 resize；手写顶部拖拽可以保证底边不动。
  - 高度统一存储后，窗口动画、SwiftUI 布局和下次打开能使用同一个值。
  - 行数和字符数同时放宽，才能让变高的卡片真正显示更多提示词内容。
- 不选哪些方案：
  - 不启用普通窗口 resize，因为会破坏贴底弹出体验。
  - 不用滚动展开单张卡片，因为用户想快速横向扫卡片，而不是每张卡再进入二级阅读。
  - 不读取完整剪贴板二进制内容，因为会重新引入上一轮性能风险。
- 接驳点：
  - `ShelfWindowController` 控制 `NSPanel` frame。
  - `ShelfView` 用 `GeometryReader` 计算 `cardHeight`。
  - `ClipboardShelfCard` 用 `cardHeight` 计算文本行数。
- 风险和边界：
  - 拖拽热区需要足够薄，避免挡住顶部按钮。
  - 预览字符上限提高会增加每页文本读取量，但仍只读字符串，首屏 16 条以内风险可控。

## 4. 验收标准
- 必须满足的结果：
  - 拖动面板顶部边缘可以调整高度。
  - 松手后高度保存。
  - 重新打开面板后使用上次高度。
  - 卡片内容区域随面板高度增加。
  - 长文本剪贴板卡片显示更多行。
- 必须通过的测试：
  - `git diff --check`
  - `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -configuration Debug build`
- 必须产出的截图 / 报告 / 日志：
  - 本轮不强制截图；以构建和代码证据为准。
- 用户可见的完成表现：
  - 面板可以像抽屉一样从上边缘拉高，长提示词更容易判断用途。

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
  - 需求已确认，改动集中在窗口控制、布局计算和预览长度三个点。
- 本任务的循环阶段：
  - 固定任务记录。
  - 统一面板高度设置。
  - 增加顶部拖拽热区。
  - 调整卡片高度和文本行数。
  - 调整轻量预览字符上限。
  - 构建验证。
  - 写回记录。
- 每一轮从哪里开始：
  - 从 `ShelfWindowController` 和 `ShelfView` 的高度控制开始。
- 每一轮怎么选择下一项工作：
  - 先打通面板高度，再让卡片内容消费这个高度。
- 每一轮允许自主执行哪些动作：
  - 修改 Swift 文件和 agent-loop 文档。
  - 运行本地构建验证。
- 每一轮必须做哪些验证：
  - `git diff --check`
  - `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -configuration Debug build`
- 每一轮必须写回哪些记录：
  - 修改文件、验证命令、验证结果、剩余风险。
- 什么情况下自动进入下一轮：
  - 构建失败且错误点明确时继续修复。
- 什么情况下必须停止：
  - 需要改 Core Data schema。
  - 需要删除本地数据。
  - 构建失败且存在多个合理修复方向。
- 这个编排为什么适合当前任务：
  - 这个任务不是单个按钮，而是“窗口高度 -> 卡片高度 -> 内容显示量”的链路修复，必须按链路顺序推进。

## 7. 任务队列
- [x] 创建 agent-loop 任务文档
- [x] 增加面板高度设置和持久化
- [x] 增加顶部拖拽热区
- [x] 调整卡片高度限制
- [x] 调整剪贴板文本预览行数和字符数
- [x] 运行本地验证
- [x] 写回执行记录和索引状态

## 8. 执行记录
- 时间：2026-05-20 12:13 CST
- 做了什么：创建本任务文档，固定本轮实现范围。
- 修改文件：
  - `.project/agent-loop/08-shelf-resizable-height.md`
- 运行命令：
  - `date '+%Y-%m-%d %H:%M %Z'`
  - `git branch --show-current && git status --short`
  - `sed -n '1,150p' cheatsheet/Utils/ShelfWindowController.swift`
  - `sed -n '1,120p;620,710p;800,860p' cheatsheet/Views/Shelf/ShelfView.swift`
  - `sed -n '1,90p;130,175p' cheatsheet/Models/ViewModels/PagedClipboardViewModel.swift`
- 实际输出：确认分支为 `main`；确认已有多项前序未提交改动；确认窗口高度、卡片高度、文本行数和预览字符数存在固定限制。
- 结果：准备进入代码修改。
- 下一步：修改窗口控制器和 Shelf view。

- 时间：2026-05-20 12:16 CST
- 做了什么：
  - 新增 `ShelfPanelHeightSettings`，统一保存默认高度 300、最小高度 260、最大高度 680 和 `UserDefaults` key。
  - `ShelfWindowController.show()` 改为使用保存高度展示面板。
  - `ShelfWindowController` 增加 `currentHeight()`、`resize(to:persist:)`、`resizeFromTopDrag(startHeight:translationY:persist:)`。
  - `ShelfView` 顶部增加 10pt 拖拽热区，拖动时实时调整面板高度，松手时保存高度。
  - `ShelfView` 卡片最大高度从原固定 380 放宽到跟随面板高度。
  - 命令/收藏卡片摘要改为按卡片高度截取更多字符和行数。
  - 剪贴板卡片文本 `lineLimit` 改为按卡片高度计算，最高 34 行。
  - 轻量剪贴板预览字符上限从 500 提高到 2000。
- 修改文件：
  - `cheatsheet/Utils/ShelfWindowController.swift`
  - `cheatsheet/Views/Shelf/ShelfView.swift`
  - `cheatsheet/Models/ViewModels/PagedClipboardViewModel.swift`
  - `.project/agent-loop/08-shelf-resizable-height.md`
  - `.project/agent-loop/00-index.md`
- 运行命令：
  - `git diff --check`
  - `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -configuration Debug build`
- 实际输出：
  - `git diff --check` 无输出，表示通过。
  - `xcodebuild` 输出 `** BUILD SUCCEEDED **`。
  - 构建仍有既有警告：`CategorySidebarView` Preview 的 `@State` 警告、部分旧 `onChange(of:perform:)` 弃用警告、AppIntents metadata skipped。
- 结果：代码修改和本地构建验证完成。
- 下一步：等待真实 UI 手感验证。

## 9. 决策和证据
- 决策：用手写顶部拖拽热区调整 `NSPanel` 高度。
- 原因：Shelf 是贴底浮动面板，必须保持底边固定。
- 证据：`ShelfWindowController.show()` 每次用 `screen.frame.minY` 作为 y 坐标贴底展示。
- 影响：拖拽时只改变高度和顶部位置，不改变底部 y 坐标。

- 决策：高度保存到 `UserDefaults`。
- 原因：用户调整高度后，下次打开应继续使用。
- 证据：当前高度硬编码为 300，没有持久化入口。
- 影响：新增统一高度设置结构。

- 决策：长内容预览同时调整文本上限和可见行数。
- 原因：只拉高卡片但预览仍固定 500 字或 10 行，用户仍然看不到更多提示词内容。
- 证据：`PagedClipboardViewModel.maxPreviewCharacters` 原为 500；`ClipboardShelfCard.textPreview` 原为 `lineLimit(10)`。
- 影响：剪贴板文本预览最多取 2000 字，卡片变高时最多显示 34 行。

- 决策：命令/收藏摘要也随卡片高度显示更多。
- 原因：用户的提示词既可能来自剪贴板，也可能来自收藏或分类里的命令卡片。
- 证据：`ShelfView` 中命令/收藏卡片都通过 `adaptiveSubtitle` 生成摘要。
- 影响：`adaptiveSubtitle` 根据 `cardHeight` 调整目标字符数和行数。

## 10. 停止条件
- 需要用户确认的情况：
  - 需要引入全新窗口管理架构。
  - 需要改变 Shelf 展示位置。
- 高风险动作：
  - 删除文件、回滚分支、修改数据库结构。
- 工具或凭据缺失：
  - none
- 测试失败且存在多个合理修复方向：
  - 暂停说明。
- 需求边界变化：
  - 如果要把卡片改成单张展开阅读模式，另开任务。
