# 02 底部横条卡片拖拽交换和性能修复

## 0. 当前状态
- 当前阶段：done
- 当前分支：main
- 当前是否允许自动执行：Karl 已确认 `ok 开始修改`
- 当前阻塞：none
- 下一步：等待 Karl 在真实底部横条里手动确认拖拽手感

## 1. 目标和需求
- 关联 EARS：本项目暂无 `.project/EARS/EARS.md`
- 用户真正想解决的问题：底部复制横条里卡片水平拖拽时明显卡顿，并且拖拽结果不符合“把一张卡拖到另一张卡位置后两张交换”的意图。
- 最终要看到的结果：拖动过程中不再高频保存和刷新；松手后只交换拖拽卡片和目标卡片的位置。
- 成功标准：第 4 张拖到第 1 张时，结果应为第 4 张到第 1 位，第 1 张到第 4 位，中间卡片顺序保持不变。
- 不做什么：不修改剪贴板历史 Core Data schema；不改变顶部分类标签拖拽；不改变主列表旧拖拽逻辑。
- 已确认内容：用户已确认开始修改。
- 未确认内容：是否还要让“剪贴板历史记录”本身拥有可持久化的自定义排序字段。

## 2. 当前状态和目标差
- 当前系统是什么样：`ReorderableHStack` 在 `DragGesture.onChanged` 中每次移动都调用重排逻辑。
- 目标系统应该是什么样：拖动中只移动当前卡片并标记目标，松手后提交一次交换。
- 差距在哪里：旧逻辑把拖动过程中的多个中间位置都写入数组和 Core Data，导致卡顿和最终顺序偏离用户落点。
- 相关文件 / 函数 / 配置：
  - `cheatsheet/Views/Components/ReorderableHStack.swift`
  - `cheatsheet/Views/Shelf/ShelfView.swift`
  - `cheatsheet/Models/ViewModels/CommandViewModel.swift`
  - `cheatsheet/Models/ViewModels/ShelfViewModel.swift`
  - `cheatsheetTests/DragDropTests.swift`
- 已掌握证据：
  - 旧 `ReorderableHStack` 在 `onChanged` 里调用 `updateReorder`。
  - 命令排序旧路径每次移动都会 `saveContext()`。
  - 收藏排序旧路径每次移动都会 `saveContext()` 后 `fetchFavorites()`。

## 3. 方案
- 推荐方案：把底部横条使用的 `ReorderableHStack` 改成拖动中只记录目标卡片，松手时调用一次 `onSwap`。
- 为什么选这个方案：用户描述的是交换两张卡片，不是插入式排序；同时减少拖动过程中的保存和刷新次数。
- 不选哪些方案：
  - 不继续使用拖动中实时插入，因为它会高频写入并造成顺序漂移。
  - 不改 Core Data schema，因为当前问题可以先在命令和收藏卡片层解决。
- 接驳点：`ShelfView` 的收藏卡片调用 `swapFavoritePositions`；命令卡片调用 `swapCommandPositions`。
- 风险和边界：如果用户指的是剪贴板历史记录本身的持久化排序，还需要单独增加 `ClipboardItem` 排序字段和迁移。

## 4. 验收标准
- 必须满足的结果：拖动中不再调用 ViewModel 的持久化重排方法；松手后只交换一次。
- 必须通过的测试：Debug build 通过；新增命令交换顺序测试覆盖第 4 张拖到第 1 张的结果。
- 必须产出的截图 / 报告 / 日志：本轮无截图；构建命令结果记录在执行记录。
- 用户可见的完成表现：底部横条拖拽更轻，交换结果更符合目标位置。

## 5. 工具、凭据和环境
- 可用命令：
  - `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -configuration Debug build`
  - `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -only-testing:cheatsheetTests/DragDropTests test`
- 可用测试方式：当前 scheme 可构建；当前 scheme 没有配置 test action，不能直接运行 XCTest。
- 可用账号、token、key、登录态或外部服务：无。
- 凭据用途：无。
- 凭据读取方式：无。
- 使用边界：不执行删除、重置、回滚和提交。
- 禁止动作：不修改生产数据；不删除本地备份 JSON。

## 6. 本任务专属自循环编排
- 为什么这个任务适合自循环：问题可以由代码根因、最小修复、构建验证和记录四步闭环。
- 本任务的循环阶段：读拖拽链路 -> 修改一次拖拽提交策略 -> 构建验证 -> 记录证据。
- 每一轮从哪里开始：从 `ReorderableHStack` 和底部横条调用点开始。
- 每一轮怎么选择下一项工作：先保证拖动中不写数据库，再保证落点交换语义，再补验证。
- 每一轮允许自主执行哪些动作：读代码、修改 Swift 文件、运行构建、补测试代码、更新 agent-loop。
- 每一轮必须做哪些验证：`git diff --check` 和 Debug build。
- 每一轮必须写回哪些记录：修改文件、验证结果、未完成测试原因。
- 什么情况下自动进入下一轮：构建失败且根因明确时可继续修复。
- 什么情况下必须停止：需要 Core Data schema 迁移、删除文件、发布或改 scheme 时停止等 Karl 确认。
- 这个编排为什么适合当前任务：任务风险集中在一个拖拽组件和两个 ViewModel，适合小范围修复后立即构建验证。

## 7. 任务队列
- [x] 读取底部横条拖拽链路
- [x] 修改 `ReorderableHStack` 为松手提交一次交换
- [x] 增加命令与收藏交换保存方法
- [x] 更新底部横条调用点
- [x] 增加命令交换单元测试用例
- [x] 运行构建验证
- [x] 记录无法运行 XCTest 的原因

## 8. 执行记录
- 时间：2026-05-20 11:22 Asia/Shanghai
- 做了什么：将底部横条使用的横向拖拽从高频插入改为松手交换。
- 修改文件：
  - `cheatsheet/Views/Components/ReorderableHStack.swift`
  - `cheatsheet/Views/Shelf/ShelfView.swift`
  - `cheatsheet/Models/ViewModels/CommandViewModel.swift`
  - `cheatsheet/Models/ViewModels/ShelfViewModel.swift`
  - `cheatsheetTests/DragDropTests.swift`
- 运行命令：
  - `git diff --check`
  - `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -configuration Debug build`
  - `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -only-testing:cheatsheetTests/DragDropTests test`
- 实际输出：
  - `git diff --check` 通过。
  - Debug build 输出 `** BUILD SUCCEEDED **`。
  - XCTest 命令失败，错误为 `Scheme cheatsheet is not currently configured for the test action.`
- 结果：代码构建通过；单测代码已补，但当前 scheme 不能直接运行测试。
- 下一步：Karl 在真实 UI 里确认底部横条拖拽手感和交换结果。

## 9. 决策和证据
- 决策：底部横条卡片拖拽使用交换语义，不再使用拖动中连续插入语义。
- 原因：Karl 明确描述“第四张拖到第一张，第一张变成第四张”。
- 证据：`ReorderableHStack` 现在只在 `onEnded` 调用 `commitDrop`，`ShelfView` 调用 `swapFavoritePositions` 和 `swapCommandPositions`。
- 影响：拖动中不再触发 Core Data 保存和列表重取；最终顺序更贴近用户落点。

## 10. 停止条件
- 需要用户确认的情况：如果继续支持剪贴板历史记录本身的自定义排序，需要新增模型字段和迁移。
- 高风险动作：Core Data schema 迁移、删除本地备份、修改 scheme。
- 工具或凭据缺失：无。
- 测试失败且存在多个合理修复方向：当前不是测试失败，而是 scheme 没有 test action。
- 需求边界变化：如果拖拽目标从命令/收藏卡片扩大到剪贴板历史记录，另开任务处理。
