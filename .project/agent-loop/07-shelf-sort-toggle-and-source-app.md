# 07 Shelf 排序切换和来源 App 展示

## 0. 当前状态
- 当前阶段：done
- 当前分支：main
- 当前是否允许自动执行：允许，本轮用户已确认“那先改这个部分”
- 当前阻塞：none
- 下一步：等待用户试用排序切换和剪贴板来源展示效果

## 1. 目标和需求
- 关联 EARS：底部 Shelf 工具区交互、剪贴板卡片来源展示、剪贴板轻量加载性能
- 用户真正想解决的问题：
  - 排序入口现在是图标菜单，状态另放一个文字胶囊，操作和状态分离。
  - 剪贴板轻量加载后速度变快，但卡片看不到复制来源 App 图标，App 名称也不够清楚。
- 最终要看到的结果：
  - 排序入口是一个文字按钮，按钮文字直接显示当前模式，并在“手动排序”和“标题排序”之间切换。
  - 剪贴板卡片 header 显示来源 App 图标、App 名称和类型标签。
- 成功标准：
  - 删除排序二级菜单、Picker 和额外“标题排序”状态胶囊。
  - 点击排序文字按钮可以切换模式，并沿用现有排序逻辑。
  - `ClipboardPreviewItem` 带回受大小限制的来源 App 图标数据，但不读取剪贴板正文 `data`。
  - 剪贴板卡片 header 在有图标时显示 App 图标，在无图标或图标异常时显示占位图标。
- 不做什么：
  - 不修改排序算法。
  - 不修改 Core Data schema。
  - 不加载剪贴板图片、RTF 或文件正文数据。
  - 不触碰未跟踪备份 JSON。
- 已确认内容：
  - 用户确认先改排序按钮和剪贴板来源 App 展示。
- 未确认内容：
  - none

## 2. 当前状态和目标差
- 当前系统是什么样：
  - `ShelfView.swift` 右侧工具区显示 `sortMenu`，标题排序时额外显示 `sortStatusChip`。
  - `sortMenu` 使用 `Menu + Picker`。
  - `ClipboardPreviewItem` 只有 `sourceAppName`，没有来源图标数据。
  - `ClipboardShelfCard` header 只显示类型标签和 App 名称。
- 目标系统应该是什么样：
  - 排序按钮本身同时表达当前状态和下一次点击动作。
  - 剪贴板轻量预览只额外读取小 App 图标，继续避免读取大正文数据。
- 差距在哪里：
  - 排序交互层级过深。
  - 来源图标没有从轻量预览模型传到 UI。
- 相关文件 / 函数 / 配置：
  - `cheatsheet/Views/Shelf/ShelfView.swift`
  - `cheatsheet/Models/ViewModels/PagedClipboardViewModel.swift`
  - `.project/agent-loop/00-index.md`
- 已掌握证据：
  - 代码读取确认 `sortStatusChip`、`sortMenu`、`sortModeBinding` 只在 `ShelfView.swift` 中使用。
  - 代码读取确认 `ClipboardPreviewItem` 当前只有 `sourceAppName`。

## 3. 方案
- 推荐方案：
  - 用 `sortToggleButton` 替代 `sortMenu` 和 `sortStatusChip`。
  - `ClipboardPreviewItem` 增加 `sourceAppIconData`。
  - 后台分页读取 `sourceAppIcon`，只保留不超过 64KB 的图标数据。
  - `ClipboardShelfCard` header 改成来源图标、App 名称、类型标签。
- 为什么选这个方案：
  - 两种排序模式不需要二级菜单。
  - 来源 App 图标通常很小，读取它不会重新引入剪贴板正文大数据卡顿。
  - 64KB 上限可以挡住异常图标数据。
- 不选哪些方案：
  - 不恢复完整 `ClipboardItem` 卡片渲染，因为会重新触发大字段读取。
  - 不新增独立状态胶囊，因为用户明确指出状态和操作应该合在一起。
- 接驳点：
  - 使用现有 `ShelfCardSortSettings` 和 `shelfCardSortModeRaw`。
  - 使用现有 `ClipboardItem.sourceAppIcon` 字段。
- 风险和边界：
  - 如果历史数据里的图标格式不是 `NSImage` 可解析格式，则显示占位图标。
  - 如果未来来源图标明显变大，应继续只在后台读取，并保持大小上限。

## 4. 验收标准
- 必须满足的结果：
  - Shelf 右侧只出现一个排序文字按钮。
  - 排序按钮文字为“手动排序”或“标题排序”，点击直接切换。
  - 剪贴板卡片 header 显示来源 App 图标和 App 名称。
- 必须通过的测试：
  - `git diff --check`
  - `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -configuration Debug build`
- 必须产出的截图 / 报告 / 日志：
  - 本轮不强制截图；以构建日志和 diff 检查为准。
- 用户可见的完成表现：
  - 排序交互少一层，状态不再分裂。
  - 剪贴板卡片能看出来源 App。

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
  - 不部署。
  - 不提交，除非用户明确要求。
- 禁止动作：
  - 不删除备份 JSON。
  - 不回滚用户已有改动。

## 6. 本任务专属自循环编排
- 为什么这个任务适合自循环：
  - 两个 UI 问题都已有明确代码位置，改动范围小，可以按“修改一处、验证一处”的方式推进。
- 本任务的循环阶段：
  - 读取现有实现。
  - 写入任务记录。
  - 修改排序入口。
  - 修改来源 App 预览模型和卡片 header。
  - 运行构建验证。
  - 写回任务记录。
- 每一轮从哪里开始：
  - 从 `ShelfView.swift` 和 `PagedClipboardViewModel.swift` 的真实代码开始。
- 每一轮怎么选择下一项工作：
  - 先改不影响数据读取的排序 UI，再改预览模型和卡片展示。
- 每一轮允许自主执行哪些动作：
  - 修改 SwiftUI view、轻量预览模型、agent-loop 文档。
  - 运行本地构建和 diff 检查。
- 每一轮必须做哪些验证：
  - `git diff --check`
  - `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -configuration Debug build`
- 每一轮必须写回哪些记录：
  - 修改文件、验证命令、验证结果、剩余风险。
- 什么情况下自动进入下一轮：
  - 构建通过且没有新的产品边界问题。
- 什么情况下必须停止：
  - 构建失败且出现多个合理修复方向。
  - 发现必须改 schema 或读取剪贴板大数据。
- 这个编排为什么适合当前任务：
  - 当前任务是明确的局部交互修复，不需要重新拆产品阶段。

## 7. 任务队列
- [x] 读取排序入口和剪贴板卡片代码
- [x] 写入 07 agent-loop 任务和索引
- [x] 替换排序菜单和状态胶囊为文字切换按钮
- [x] 在轻量剪贴板预览中带回受限来源 App 图标
- [x] 更新剪贴板卡片 header
- [x] 运行本地验证
- [x] 写回执行记录和索引状态

## 8. 执行记录
- 时间：2026-05-20 12:08 CST
- 做了什么：创建本任务文件，准备修改代码
- 修改文件：
  - `.project/agent-loop/07-shelf-sort-toggle-and-source-app.md`
- 运行命令：
  - `git branch --show-current`
  - `sed -n '1,220p' .project/agent-loop/00-index.md`
  - `sed -n '1,220p' cheatsheet/Models/ViewModels/PagedClipboardViewModel.swift`
  - `sed -n '420,740p' cheatsheet/Views/Shelf/ShelfView.swift`
  - `rg -n "sortStatusChip|sortMenu|sortModeBinding|systemImage|label" cheatsheet/Views/Shelf/ShelfView.swift cheatsheet/Models/ViewModels/ShelfViewModel.swift`
- 实际输出：确认分支为 `main`；确认排序菜单和状态胶囊位置；确认轻量预览模型缺少来源图标字段
- 结果：可以按本任务范围修改
- 下一步：修改代码

- 时间：2026-05-20 12:09 CST
- 做了什么：
  - 删除 `ShelfView.swift` 中的 `sortMenu`、`sortModeBinding` 和 `sortStatusChip`。
  - 新增 `sortToggleButton`，按钮文字直接显示当前排序模式，点击后在“手动排序”和“标题排序”之间切换。
  - 给 `ClipboardPreviewItem` 增加 `sourceAppIconData`。
  - 后台预览分页读取 `sourceAppIcon`，但只保留不超过 64KB 的图标数据。
  - 剪贴板卡片 header 改成来源 App 图标、App 名称、类型标签。
- 修改文件：
  - `cheatsheet/Views/Shelf/ShelfView.swift`
  - `cheatsheet/Models/ViewModels/PagedClipboardViewModel.swift`
  - `.project/agent-loop/07-shelf-sort-toggle-and-source-app.md`
  - `.project/agent-loop/00-index.md`
- 运行命令：
  - `git diff --check`
  - `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -configuration Debug build`
- 实际输出：
  - `git diff --check` 无输出，表示通过。
  - `xcodebuild` 输出 `** BUILD SUCCEEDED **`。
  - 构建仍有既有警告：`CategorySidebarView` Preview 的 `@State` 警告，以及部分旧 `onChange(of:perform:)` 弃用警告。
- 结果：本任务代码修改和本地构建验证完成。
- 下一步：等待用户试用真实 UI。

## 9. 决策和证据
- 决策：排序入口改为文字切换按钮，不保留菜单和状态胶囊。
- 原因：只有两个模式，文字按钮能同时表达状态和操作入口。
- 证据：`ShelfView.swift` 中 `sortMenu` 使用 `Menu + Picker`，标题排序时又额外显示 `sortStatusChip`。
- 影响：删除 `sortModeBinding`、`sortMenu`、`sortStatusChip`，新增 `sortToggleButton`。

- 决策：轻量预览只带来源 App 小图标，不带剪贴板正文 `data`。
- 原因：用户要恢复来源信息，同时保留上一轮性能优化。
- 证据：`PagedClipboardViewModel.swift` 中 `ClipboardPreviewItem` 只有 `sourceAppName`；剪贴板复制正文仍通过点击时按 objectID 读取真实对象。
- 影响：新增 `sourceAppIconData` 和 64KB 上限。

- 决策：无图标或图标无法解析时显示系统占位图标。
- 原因：历史数据或异常数据可能无法被 `NSImage(data:)` 解析，卡片仍应保持稳定布局。
- 证据：`ShelfView.swift` 的 `sourceAppIconView` 同时处理真实图标和占位图标。
- 影响：来源区域不会因为缺图标而空掉。

## 10. 停止条件
- 需要用户确认的情况：
  - 需要改 Core Data schema。
  - 需要重新设计剪贴板加载架构。
- 高风险动作：
  - 删除文件、回滚分支、修改数据库结构。
- 工具或凭据缺失：
  - none
- 测试失败且存在多个合理修复方向：
  - 停止并说明失败点。
- 需求边界变化：
  - 如果排序按钮需要图标加文字或更多模式，停止重新确认。
