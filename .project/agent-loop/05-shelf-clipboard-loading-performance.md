# 05 底部横条剪贴板加载性能优化

## 0. 当前状态
- 当前阶段：done
- 当前分支：main
- 当前是否允许自动执行：Karl 已确认 `ok 开始`
- 当前阻塞：none
- 下一步：等待 Karl 真实交互验收；后续如仍卡顿，再对全屏剪贴板页和图片缩略图做第二轮优化

## 1. 目标和需求
- 关联 EARS：本项目暂无 `.project/EARS/EARS.md`
- 用户真正想解决的问题：
  - 切换不同剪贴卡片列表时不够瞬时。
  - 点击剪贴板后像是一次性加载大量剪贴板内容，导致 app 卡死。
- 最终要看到的结果：
  - 底部横条点击剪贴板标签后先立即响应，列表内容按页加载。
  - 横条卡片先显示轻量文本预览，不在首屏一次性读取图片、文件数据或 app 图标二进制。
  - 滚到末尾附近才加载下一页，同一时间只允许一个加载请求。
- 成功标准：
  - 横条剪贴板不再直接渲染 `[ClipboardItem]`。
  - 横条使用轻量 `ClipboardPreviewItem`。
  - 首屏 pageSize 小于原来的 30。
  - 复制和删除仍能工作。
  - `git diff --check` 通过。
  - `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -configuration Debug build` 通过。
- 不做什么：
  - 本轮不重写全屏 `ClipboardHistoryView`。
  - 本轮不修改 Core Data schema。
  - 本轮不清理或删除真实剪贴板历史。
  - 本轮不触碰本地备份 JSON。
- 已确认内容：Karl 已同意开始修改。
- 未确认内容：none

## 2. 当前状态和目标差
- 当前系统是什么样：
  - `ShelfWindowController` 把主线程 `viewContext` 传给横条。
  - `PagedClipboardViewModel.items` 是 `[ClipboardItem]`。
  - `loadNextPage()` 使用主线程 context 的 `perform`，仍可能阻塞 UI。
  - `ShelfView` 在 `body` 中直接过滤剪贴板对象。
  - `ClipboardShelfCard.onAppear` 会访问 `item.data` 和 `item.sourceAppIcon`。
  - 最后一张卡片 `onAppear` 立即触发下一页加载。
- 目标系统应该是什么样：
  - 横条使用轻量预览数据，不直接持有和渲染 Core Data 对象。
  - 数据读取在后台 context 完成，回主线程只发布小数组。
  - 二进制数据只在复制等真实需要时读取。
  - 加载更多由阈值控制，而不是首屏最后一张出现就连续拉页。
- 差距在哪里：
  - 当前数据对象太重，主线程读取和 SwiftUI 渲染耦合太紧。
- 相关文件 / 函数 / 配置：
  - `cheatsheet/Models/ViewModels/PagedClipboardViewModel.swift`
  - `cheatsheet/Views/Shelf/ShelfView.swift`
  - `cheatsheet/Utils/ShelfWindowController.swift`
  - `cheatsheet/Persistence.swift`
- 已掌握证据：
  - 真实库剪贴板约 435 条，其中 text 407 条、image 28 条。
  - `sourceAppIcon` 在 text 项中最大约 103KB。
  - 当前真实库读统计时原库被 app 锁住，只读副本统计成功。

## 3. 方案
- 推荐方案：
  - 保留现有 `items: [ClipboardItem]` 给全屏剪贴板页继续使用。
  - 在 `PagedClipboardViewModel` 增加 `previewItems: [ClipboardPreviewItem]` 和横条专用分页方法。
  - 横条改用 `previewItems` 渲染，不再在卡片出现时读取 `item.data` / `item.sourceAppIcon`。
  - 复制和删除通过 `objectID` 在 context 中解析真实对象后执行。
- 为什么选这个方案：
  - 改动范围集中，能先解决横条卡死问题。
  - 不影响全屏剪贴板页的既有行为，减少回归风险。
- 不选哪些方案：
  - 不直接把所有剪贴板逻辑改成 `NSFetchedResultsController`，范围过大。
  - 不修改 Core Data 模型加 preview 字段，当前可以通过 fetch properties 解决。
  - 不用 `equatable()` 作为主要修复，因为根因是主线程重数据读取。
- 接驳点：
  - `ShelfView` 的剪贴板分支。
  - `ClipboardShelfCard` 的输入模型。
  - `PagedClipboardViewModel` 的分页、复制、删除。
- 风险和边界：
  - 本轮横条不展示 app 图标缩略图，以换取首开顺滑。
  - 如果后续仍需图片缩略图，应另做后台缩略图缓存。

## 4. 验收标准
- 必须满足的结果：
  - 点击剪贴板标签不会同步拉取大量二进制字段。
  - 横条剪贴板列表可以继续复制、删除和滚动加载更多。
  - 切换到收藏或分类不触发剪贴板重载。
- 必须通过的测试：
  - `git diff --check`
  - `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -configuration Debug build`
- 必须产出的截图 / 报告 / 日志：本轮无截图要求。
- 用户可见的完成表现：
  - 点击剪贴板标签更快显示，滚动时再补下一页。

## 5. 工具、凭据和环境
- 可用命令：
  - `git diff --check`
  - `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -configuration Debug build`
  - 只读 `sqlite3` 副本统计
- 可用测试方式：当前 scheme 可构建；test action 未配置。
- 可用账号、token、key、登录态或外部服务：无。
- 凭据用途：无。
- 凭据读取方式：无。
- 使用边界：不提交、不删除、不回滚已有未提交改动。
- 禁止动作：不删除真实剪贴板历史；不删除本地备份 JSON。

## 6. 本任务专属自循环编排
- 为什么这个任务适合自循环：性能问题已定位到横条剪贴板加载链路，修改范围集中。
- 本任务的循环阶段：固定证据 -> 轻量模型 -> 后台分页 -> 横条替换 -> 构建验证 -> 写回记录。
- 每一轮从哪里开始：从 `PagedClipboardViewModel` 和 `ShelfView` 的剪贴板分支开始。
- 每一轮怎么选择下一项工作：先保留旧接口，再新增横条专用轻量接口，最后替换横条视图。
- 每一轮允许自主执行哪些动作：编辑 Swift、运行构建、更新 agent-loop。
- 每一轮必须做哪些验证：`git diff --check` 和 Debug build。
- 每一轮必须写回哪些记录：修改文件、验证结果、剩余风险。
- 什么情况下自动进入下一轮：构建失败且错误明确时继续修复。
- 什么情况下必须停止：需要改 Core Data schema、删除真实数据、重写全屏剪贴板页。
- 这个编排为什么适合当前任务：先把横条从重对象列表中拆出来，能最小化风险并直接改善用户提到的首开卡死。

## 7. 任务队列
- [x] 创建 agent-loop 任务文档
- [x] 增加轻量剪贴板预览模型和后台分页读取
- [x] 增加通过 objectID 复制和删除的方法
- [x] 替换横条剪贴板分支为轻量预览渲染
- [x] 调整横条加载更多触发条件
- [x] 运行构建验证
- [x] 写回执行记录

## 8. 执行记录
- 时间：2026-05-20 11:41 Asia/Shanghai
- 做了什么：创建本任务文档，固定本轮只优化底部横条剪贴板加载。
- 修改文件：
  - `.project/agent-loop/05-shelf-clipboard-loading-performance.md`
- 运行命令：
  - `date '+%Y-%m-%d %H:%M %Z'`
  - `sed -n '1,180p' .project/agent-loop/00-index.md`
  - `git status --short`
- 实际输出：确认当前分支为 `main`，存在前序未提交改动和未跟踪备份 JSON。
- 结果：准备进入代码修改。
- 下一步：修改 `PagedClipboardViewModel` 与 `ShelfView`。

- 时间：2026-05-20 11:45 Asia/Shanghai
- 做了什么：
  - 在 `PagedClipboardViewModel` 增加 `ClipboardPreviewItem` 和横条专用 `previewItems`。
  - 横条首屏 pageSize 从旧 `items` 的 30 改为预览路径的 16。
  - 预览读取使用 private queue context，读取完成后只把轻量结构回传给 SwiftUI。
  - 横条卡片不再直接持有 `ClipboardItem`，也不再在 `onAppear` 里读取 `data` / `sourceAppIcon`。
  - 横条复制和删除改为通过 `objectID` 解析真实 `ClipboardItem` 后执行。
  - 加载更多改成距离末尾 4 张以内才触发。
- 修改文件：
  - `cheatsheet/Models/ViewModels/PagedClipboardViewModel.swift`
  - `cheatsheet/Models/ViewModels/ShelfViewModel.swift`
  - `cheatsheet/Views/Shelf/ShelfView.swift`
  - `.project/agent-loop/05-shelf-clipboard-loading-performance.md`
  - `.project/agent-loop/00-index.md`
- 运行命令：
  - `git diff --check`
  - `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -configuration Debug build`
- 实际输出：
  - `git diff --check` 无输出。
  - Debug build 输出 `** BUILD SUCCEEDED **`。
  - 构建仍有既有 Preview `@State` 和旧式 `onChange` warning，和本次性能改动无关。
- 结果：本轮横条剪贴板加载性能优化完成。
- 下一步：等待 Karl 在真实应用里验证点击剪贴板和切换列表是否更跟手。

## 9. 决策和证据
- 决策：本轮只优化底部横条，不重写全屏剪贴板页。
- 原因：Karl 当前卡死反馈发生在底部复制弹窗和剪贴板标签切换。
- 证据：`ShelfView` 当前直接渲染 `viewModel.pagedClipboardVM.items`，并在卡片 `onAppear` 读取二进制字段。
- 影响：风险更小，可以先把最明显卡顿路径拆开。

- 决策：横条预览不显示真实图片缩略图和 app 图标。
- 原因：图片数据和 app 图标是首开卡顿风险最高的字段；本轮优先保证点击和切换顺滑。
- 证据：真实库中 `sourceAppIcon` 最大约 103KB，旧卡片 `onAppear` 会读取 `item.data` 和 `item.sourceAppIcon`。
- 影响：图片项在横条中显示 `<image>` 占位；复制时仍按真实对象复制。

- 决策：保留全屏 `ClipboardHistoryView` 的旧 `items` 接口。
- 原因：全屏页不是本轮最明显的卡死入口，保留旧接口可以降低回归风险。
- 证据：`ClipboardHistoryView` 仍通过 `viewModel.items` 和 `loadNextPage()` 工作。
- 影响：后续如果全屏页也卡顿，应另开一轮把全屏页也迁移到轻量预览或专用 fetched-results 路径。

## 10. 停止条件
- 需要用户确认的情况：需要改 Core Data schema；需要删除或迁移真实剪贴板历史；需要重写全屏剪贴板页。
- 高风险动作：删除文件、回滚未提交改动、清空剪贴板历史。
- 工具或凭据缺失：无。
- 测试失败且存在多个合理修复方向：暂停说明。
- 需求边界变化：如果要做完整剪贴板存储重构，另开任务。
