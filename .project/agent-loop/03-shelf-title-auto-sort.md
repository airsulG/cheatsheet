# 03 底部横条按标题自动排序

## 0. 当前状态
- 当前阶段：done
- 当前分支：main
- 当前是否允许自动执行：Karl 已确认 `OK, 我同意这个方案，先创建新的 agent loop 文档，然后开始执行`
- 当前阻塞：none
- 下一步：等待 Karl 在真实底部横条里确认排序菜单、标题排序效果和自动禁用拖拽是否符合预期

## 1. 目标和需求
- 关联 EARS：本项目暂无 `.project/EARS/EARS.md`
- 用户真正想解决的问题：手动拖拽交换卡片位置成本高，需要一个自动排序方式，让卡片能按标题字符顺序排列。
- 最终要看到的结果：底部横条可以在手动排序和按标题排序之间切换；开启按标题排序后，编辑标题会让卡片自动移动到标题对应位置。
- 成功标准：
  - 当标题排序开启时，普通命令卡片按标题顺序显示并保存。
  - 当收藏卡片页开启标题排序时，收藏卡片按标题顺序显示并保存收藏顺序。
  - 当某张卡片标题从“一”改成“二”时，它会按标题排序规则自动移动到“二”对应的位置。
  - 当标题排序开启时，拖拽交换禁用，避免手动顺序和自动顺序互相覆盖。
- 不做什么：
  - 不修改剪贴板历史记录排序；剪贴板历史没有标题字段，也没有自定义排序字段。
  - 不修改 Core Data schema。
  - 不引入新依赖。
  - 不改变主窗口命令列表的旧排序交互，除非它自然复用同一个 ViewModel 拉取结果。
- 已确认内容：Karl 同意推荐方案。
- 未确认内容：后续是否需要剪贴板历史记录也支持自定义排序。

## 2. 当前状态和目标差
- 当前系统是什么样：
  - 普通命令卡片使用 `Command.order` 排序。
  - 收藏卡片使用 `favoriteOrder` 排序。
  - 编辑标题只改变 `Command.name`，不会重新计算顺序字段。
  - 上一轮已将拖拽交换改为松手后交换一次。
- 目标系统应该是什么样：
  - 用户可切换排序模式。
  - 标题排序模式开启后，标题变更会触发对应顺序字段重算。
  - 标题排序模式下不允许拖拽交换。
- 差距在哪里：缺少排序模式状态、标题比较规则、标题变化后的顺序重算、底部横条 UI 入口。
- 相关文件 / 函数 / 配置：
  - `cheatsheet/Models/ViewModels/CommandViewModel.swift`
  - `cheatsheet/Models/ViewModels/ShelfViewModel.swift`
  - `cheatsheet/Views/Shelf/ShelfView.swift`
  - `cheatsheetTests/DragDropTests.swift`
- 已掌握证据：
  - `CommandViewModel.updateCommand` 保存后仍按 `order` 拉取。
  - `ShelfViewModel.fetchFavorites` 当前按 `favoriteOrder` 拉取。

## 3. 方案
- 推荐方案：新增 `manual` / `title` 两种底部横条排序模式，使用 `UserDefaults` 持久化；标题排序开启时，普通命令重写 `order`，收藏重写 `favoriteOrder`。
- 为什么选这个方案：它保留手动拖拽的控制权，也提供自动标题排序；两种规则不会同时争抢同一组顺序字段。
- 不选哪些方案：
  - 不直接永久取消拖拽，因为上一轮刚修复拖拽交换，手动排序仍有价值。
  - 不只做视图层临时排序，因为编辑后重启或重新拉取时顺序会不稳定。
  - 不做数据库迁移，因为现有 `order` 和 `favoriteOrder` 已能保存排序结果。
- 接驳点：
  - 标题比较规则放在现有 ViewModel 层可访问的位置。
  - `CommandViewModel` 在创建、编辑、拉取时按模式处理普通命令顺序。
  - `ShelfViewModel` 在收藏拉取和模式切换时按模式处理收藏顺序。
  - `ShelfView` 右侧工具区提供排序菜单。
- 风险和边界：
  - 标题排序开启后会覆盖之前手动排序结果；切回手动排序后，会保留最近一次自动排序写入的顺序。
  - 当前 test action 未配置，自动测试可能不能直接运行；至少要保证 Debug build 通过。

## 4. 验收标准
- 必须满足的结果：
  - 用户能从底部横条切换手动排序 / 按标题排序。
  - 标题排序开启时卡片按标题字符顺序排列。
  - 中文数字 `一 二 三 四 五 六 七 八 九 十` 按该顺序处理。
  - 标题排序开启时，普通命令和收藏卡片都禁用拖拽交换。
- 必须通过的测试：
  - `git diff --check`
  - `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -configuration Debug build`
- 必须产出的截图 / 报告 / 日志：本轮无截图要求；记录构建结果。
- 用户可见的完成表现：底部横条多一个排序入口，编辑卡片标题后自动移动到对应位置。

## 5. 工具、凭据和环境
- 可用命令：
  - `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -configuration Debug build`
  - `git diff --check`
- 可用测试方式：当前 scheme 可构建；此前测试命令提示 scheme 未配置 test action。
- 可用账号、token、key、登录态或外部服务：无。
- 凭据用途：无。
- 凭据读取方式：无。
- 使用边界：不提交、不删除、不回滚用户或上一轮未提交改动。
- 禁止动作：不修改 Core Data schema；不删除本地备份 JSON。

## 6. 本任务专属自循环编排
- 为什么这个任务适合自循环：范围集中在排序状态、排序规则、底部横条入口和构建验证。
- 本任务的循环阶段：创建任务文档 -> 实现排序规则 -> 接入普通命令 -> 接入收藏 -> 接入 UI -> 构建验证 -> 写回记录。
- 每一轮从哪里开始：从 `CommandViewModel` 和 `ShelfViewModel` 的现有排序字段开始。
- 每一轮怎么选择下一项工作：先让数据排序稳定，再让 UI 能切换，再处理拖拽禁用。
- 每一轮允许自主执行哪些动作：编辑 Swift 代码、补测试代码、运行构建、更新 agent-loop。
- 每一轮必须做哪些验证：`git diff --check` 和 Debug build。
- 每一轮必须写回哪些记录：改动文件、构建结果、测试限制、剩余风险。
- 什么情况下自动进入下一轮：构建失败且错误明确时继续修复。
- 什么情况下必须停止：需要数据库迁移、删除文件、修改 scheme、发布或需求扩大到剪贴板历史排序。
- 这个编排为什么适合当前任务：排序功能要先固定规则，再落到已有顺序字段，最后接 UI。

## 7. 任务队列
- [x] 创建 agent-loop 任务文档
- [x] 实现标题排序模式和比较规则
- [x] 普通命令卡片接入标题排序
- [x] 收藏卡片接入标题排序
- [x] 底部横条增加排序菜单
- [x] 标题排序模式下禁用拖拽交换
- [x] 运行构建验证
- [x] 写回执行记录

## 8. 执行记录
- 时间：2026-05-20 11:25 Asia/Shanghai
- 做了什么：创建本任务文档，准备进入实现。
- 修改文件：
  - `.project/agent-loop/03-shelf-title-auto-sort.md`
- 运行命令：
  - `date '+%Y-%m-%d %H:%M %Z'`
  - `sed -n '1,220p' .project/agent-loop/00-index.md`
- 实际输出：确认当前索引已有 01、02 两个任务。
- 结果：任务文档已创建。
- 下一步：实现代码。

- 时间：2026-05-20 11:30 Asia/Shanghai
- 做了什么：完成按标题自动排序实现；底部横条增加排序菜单；标题排序开启后禁用拖拽交换。
- 修改文件：
  - `.project/agent-loop/00-index.md`
  - `.project/agent-loop/03-shelf-title-auto-sort.md`
  - `cheatsheet/Models/ViewModels/CommandViewModel.swift`
  - `cheatsheet/Models/ViewModels/ShelfViewModel.swift`
  - `cheatsheet/Views/Components/ReorderableHStack.swift`
  - `cheatsheet/Views/Shelf/ShelfView.swift`
  - `cheatsheetTests/DragDropTests.swift`
- 运行命令：
  - `git diff --check`
  - `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -configuration Debug build`
  - `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -only-testing:cheatsheetTests/DragDropTests test`
- 实际输出：
  - `git diff --check` 通过。
  - Debug build 输出 `** BUILD SUCCEEDED **`。
  - XCTest 命令仍失败，错误为 `Scheme cheatsheet is not currently configured for the test action.`
- 结果：功能实现完成并构建通过；新增测试代码已写入但当前 scheme 不能直接运行测试。
- 下一步：Karl 手动验证底部横条排序菜单和编辑标题后的自动排序。

## 9. 决策和证据
- 决策：标题排序与手动排序做成模式切换。
- 原因：手动拖拽和自动标题排序会写同一组顺序字段，必须避免同时生效。
- 证据：普通命令使用 `order`，收藏使用 `favoriteOrder`。
- 影响：开启标题排序会覆盖当前手动顺序；切回手动后保留最近保存的顺序。

- 决策：底部横条排序模式只注入 `ShelfViewModel` 持有的 `CommandViewModel`，普通主窗口默认仍然手动排序。
- 原因：这轮目标是底部横条排序，不应让底部横条的设置静默改变主窗口命令列表。
- 证据：`CommandViewModel.sortModeProvider` 默认返回 `.manual`，`ShelfViewModel` 初始化时注入 `ShelfCardSortSettings.mode`。
- 影响：底部横条按标题排序；主窗口命令列表保持原行为，除非后续明确要求同步。

## 10. 停止条件
- 需要用户确认的情况：需要 Core Data schema 迁移；需要剪贴板历史排序；需要删除或重置已有数据。
- 高风险动作：数据库迁移、删除备份、修改 scheme、发布。
- 工具或凭据缺失：无。
- 测试失败且存在多个合理修复方向：暂停说明。
- 需求边界变化：如果排序范围扩大到剪贴板历史或分组标签，另开任务。
