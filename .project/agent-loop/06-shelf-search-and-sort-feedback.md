# 06 底部横条搜索和排序状态反馈

## 0. 当前状态
- 当前阶段：done
- 当前分支：main
- 当前是否允许自动执行：Karl 已确认 `ok 开始`
- 当前阻塞：none
- 下一步：等待 Karl 真实交互验收

## 1. 目标和需求
- 关联 EARS：本项目暂无 `.project/EARS/EARS.md`
- 用户真正想解决的问题：底部横条已经有搜索、排序、拖拽和多列表，但当前模式不够清楚，搜索也不够像高频快速入口。
- 最终要看到的结果：
  - 点击搜索后输入框自动获得焦点。
  - 搜索展开时能明确看到当前搜索范围。
  - Esc 可以关闭搜索并清空搜索词。
  - 标题排序模式有轻量可见提示，避免用户误以为拖拽失效。
- 成功标准：
  - 搜索按钮支持 Command-F。
  - 搜索展开后自动聚焦输入框。
  - 搜索展开状态显示当前搜索范围。
  - 标题排序模式显示轻量状态提示。
  - 手动排序模式不增加多余常驻文字。
  - `git diff --check` 通过。
  - `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -configuration Debug build` 通过。
- 不做什么：
  - 不改搜索匹配算法。
  - 不改排序持久化逻辑。
  - 不改剪贴板轻量分页架构。
  - 不新增全局快捷键系统。
- 已确认内容：Karl 已同意开始修改。
- 未确认内容：none

## 2. 当前状态和目标差
- 当前系统是什么样：
  - 搜索按钮点击后展开 `TextField`，但没有自动聚焦。
  - 搜索输入框只有 placeholder，当前搜索范围不够稳定可见。
  - 排序按钮只显示图标，标题排序下禁用拖拽但缺少可见解释。
- 目标系统应该是什么样：
  - 搜索是一个快速入口，打开后可以直接输入。
  - 搜索中能看见当前范围，例如“剪贴板”“收藏”“当前分类名”。
  - 标题排序模式有小状态标签提示。
- 差距在哪里：状态藏在图标和 placeholder 里，不够直观。
- 相关文件 / 函数 / 配置：
  - `cheatsheet/Views/Shelf/ShelfView.swift`
- 已掌握证据：
  - `ShelfView.headerBar` 中搜索框位于 `isSearching` 分支。
  - `sortMenu` 只有图标 label 和 `.help(currentSortMode.label)`。

## 3. 方案
- 推荐方案：
  - 在 `ShelfView` 增加 `@FocusState` 管理搜索焦点。
  - 抽出 `openSearch()` 和 `closeSearch()`。
  - 搜索输入框前增加当前范围小胶囊。
  - 标题排序时在工具区显示“标题排序”小胶囊。
  - 搜索按钮加 Command-F 快捷键，关闭按钮加 Esc 快捷键。
- 为什么选这个方案：改动集中在一个视图里，能直接提升操作感，不碰底层数据。
- 不选哪些方案：
  - 不做全局命令系统，范围太大。
  - 不常驻显示手动排序标签，避免工具区变吵。
  - 不新增复杂搜索结果页。
- 接驳点：
  - `ShelfView.headerBar`
  - `ShelfView.sortMenu`
  - `searchText` / `isSearching`
- 风险和边界：
  - macOS SwiftUI `FocusState` 在旧系统表现可能略有差异；构建可验证语法，真实焦点需要运行体验确认。

## 4. 验收标准
- 必须满足的结果：
  - 搜索打开后自动聚焦。
  - 搜索展开时显示范围。
  - 标题排序时显示状态提示。
  - 搜索关闭会清空搜索词并同步 `viewModel.searchText`。
- 必须通过的测试：
  - `git diff --check`
  - `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -configuration Debug build`
- 必须产出的截图 / 报告 / 日志：本轮无截图要求。
- 用户可见的完成表现：搜索和排序模式更容易被理解。

## 5. 工具、凭据和环境
- 可用命令：
  - `git diff --check`
  - `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -configuration Debug build`
- 可用测试方式：当前 scheme 可构建；test action 未配置。
- 可用账号、token、key、登录态或外部服务：无。
- 凭据用途：无。
- 凭据读取方式：无。
- 使用边界：不提交、不删除、不回滚已有未提交改动。
- 禁止动作：不删除本地备份 JSON。

## 6. 本任务专属自循环编排
- 为什么这个任务适合自循环：范围集中在 `ShelfView` 的搜索和排序状态。
- 本任务的循环阶段：固定任务 -> 抽状态 helper -> 修改搜索交互 -> 修改排序状态提示 -> 构建验证 -> 写回记录。
- 每一轮从哪里开始：从 `ShelfView.headerBar` 开始。
- 每一轮怎么选择下一项工作：先保证搜索快速可用，再补状态提示。
- 每一轮允许自主执行哪些动作：编辑 Swift、运行构建、更新 agent-loop。
- 每一轮必须做哪些验证：`git diff --check` 和 Debug build。
- 每一轮必须写回哪些记录：修改文件、验证结果、剩余风险。
- 什么情况下自动进入下一轮：构建失败且错误明确时继续修复。
- 什么情况下必须停止：需要引入全局快捷键系统、改搜索算法、改数据模型。
- 这个编排为什么适合当前任务：用户已经确认先做搜索和排序状态体验，单文件改动能快速闭环。

## 7. 任务队列
- [x] 创建 agent-loop 任务文档
- [x] 增加搜索焦点状态和 open / close helper
- [x] 搜索框显示当前搜索范围并支持 Esc 关闭
- [x] 搜索按钮支持 Command-F
- [x] 标题排序模式显示轻量状态提示
- [x] 运行构建验证
- [x] 写回执行记录

## 8. 执行记录
- 时间：2026-05-20 11:49 Asia/Shanghai
- 做了什么：创建本任务文档，固定本轮只优化搜索和排序状态反馈。
- 修改文件：
  - `.project/agent-loop/06-shelf-search-and-sort-feedback.md`
- 运行命令：
  - `date '+%Y-%m-%d %H:%M %Z'`
  - `sed -n '1,180p' .project/agent-loop/00-index.md`
  - `git status --short`
  - `nl -ba cheatsheet/Views/Shelf/ShelfView.swift | sed -n '1,540p'`
- 实际输出：确认当前搜索和排序入口都在 `ShelfView.headerBar`。
- 结果：准备修改 `ShelfView.swift`。
- 下一步：实现搜索焦点和状态胶囊。

- 时间：2026-05-20 11:50 Asia/Shanghai
- 做了什么：
  - 在 `ShelfView` 增加 `@FocusState` 管理搜索输入焦点。
  - 新增 `openSearch()` / `closeSearch()`，统一搜索打开和关闭行为。
  - 搜索展开后显示当前范围胶囊，例如“剪贴板”“收藏”或当前分类名。
  - 搜索输入框使用更短 placeholder，范围信息不再只藏在 placeholder 中。
  - 搜索按钮支持 Command-F。
  - 搜索关闭按钮支持 Esc；面板收到 Esc 时，优先关闭搜索，否则隐藏横条。
  - 标题排序模式显示“标题排序”状态胶囊。
- 修改文件：
  - `cheatsheet/Views/Shelf/ShelfView.swift`
  - `.project/agent-loop/06-shelf-search-and-sort-feedback.md`
  - `.project/agent-loop/00-index.md`
- 运行命令：
  - `git diff --check`
  - `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -configuration Debug build`
- 实际输出：
  - `git diff --check` 无输出。
  - Debug build 输出 `** BUILD SUCCEEDED **`。
  - 构建仍有既有 Preview `@State` warning，和本次修改无关。
- 结果：搜索和排序状态反馈优化完成。
- 下一步：等待 Karl 在真实面板中确认 Command-F、Esc 和自动聚焦手感。

## 9. 决策和证据
- 决策：只在标题排序模式显示排序状态提示。
- 原因：手动排序是默认模式，常驻提示会增加噪音；标题排序会禁用拖拽，更需要被看见。
- 证据：`ReorderableHStack` 当前通过 `allowsReordering: currentSortMode == .manual` 控制是否允许拖拽。
- 影响：用户更容易理解标题排序下为什么不能手动拖拽。

- 决策：Esc 优先关闭搜索；没有打开搜索时隐藏横条。
- 原因：搜索打开时用户最可能想退出当前输入；搜索未打开时 Esc 更符合关闭临时面板的预期。
- 证据：`ShelfView` 现在通过 `onExitCommand` 分支处理 `isSearching`。
- 影响：键盘操作更顺手，但需要真实运行确认和系统快捷键是否冲突。

## 10. 停止条件
- 需要用户确认的情况：要做全局快捷键系统；要改变搜索算法；要改变排序规则。
- 高风险动作：删除文件、回滚未提交改动。
- 工具或凭据缺失：无。
- 测试失败且存在多个合理修复方向：暂停说明。
- 需求边界变化：如果要做完整命令面板或全局搜索，另开任务。
