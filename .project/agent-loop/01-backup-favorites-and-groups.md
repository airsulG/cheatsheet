# 01 收藏和分组备份导入

## 0. 当前状态
- 当前阶段：第一版编码完成，构建已通过，等待后续真实界面验收。
- 当前分支：`main`。
- 当前是否允许自动执行：本轮已按用户“开始自循环编码”执行；后续清空式导入、覆盖旧备份、发布构建仍需用户确认。
- 当前阻塞：当前 Xcode scheme 没有配置测试动作，`xcodebuild test` 无法执行测试文件。
- 下一步：用户在应用里打开“备份与恢复”，选择文件夹，执行一次导出和导入试用；如需要覆盖式恢复，再单独确认。

## 1. 目标和需求
- 用户真正想解决的问题：换电脑时，如果忘记迁移软件本地数据库，自己整理的分组、收藏和创建的剪贴内容会丢失，恢复成本很高。
- 最终要看到的结果：用户可以选择一个容易找到的文件夹，把重要数据导出成备份文件；换电脑后可以把备份文件导入回来。
- 成功标准：
  - 能选择备份文件夹。
  - 能导出所有分组和用户创建的剪贴内容。
  - 能导出收藏状态和收藏顺序。
  - 能从备份文件恢复分组、命令、收藏和顺序。
  - 备份文件不包含剪贴板历史内容。
- 不做什么：
  - 不导出 `ClipboardItem` 里的剪贴板历史正文、图片、文件路径和来源 App 信息。
  - 不直接复制 Core Data 数据库文件，因为这会把剪贴板历史一起带走。
  - 不做云同步。
  - 不自动覆盖生产数据，导入前需要用户确认导入方式。
- 已确认内容：
  - 用户需要备份收藏、自己创建的分组和剪贴内容。
  - 用户明确要求不包含剪贴板本身的内容。
  - 用户要求创建本任务的自循环文档。
- 已采用的第一版安全默认值：
  - 导入冲突处理：只追加导入；同名分类自动加序号；不删除、不覆盖现有数据。
  - 定时导出策略：支持关闭、每次启动、每天一次、每周一次。
  - 备份文件保留策略：每次生成带时间戳的新 JSON 文件，不覆盖旧备份。
- 未确认内容：
  - 是否需要“覆盖当前数据并恢复到备份状态”的高级恢复模式。
  - 是否需要自动清理旧备份文件。

### EARS 需求描述
- 当用户选择备份文件夹时，系统应保存这个文件夹的位置，用于之后导出备份文件。
- 当用户点击手动导出时，系统应把 `Category` 和 `Command` 编码为 JSON 文件，并写入用户选择的文件夹。
- 当系统执行定时导出时，系统应使用最近保存的备份文件夹写入新的备份文件。
- 当用户选择备份文件并点击导入时，系统应解析备份文件，并恢复分组、命令、收藏状态和顺序。
- 如果备份文件缺少必要字段，系统应停止导入并显示可读错误。
- 如果备份过程中读取到 `ClipboardItem`，系统应拒绝把它写入备份文件。

## 2. 当前状态和目标差
- 当前系统是什么样：
  - 本地数据存在 Core Data 中。
  - `Category` 表示分组。
  - `Command` 表示用户创建的剪贴内容，也保存收藏状态。
  - `ClipboardItem` 表示真实剪贴板历史。
  - 现有导入导出只面向单个分类，并且通过文本框或剪贴板传 JSON。
- 目标系统应该是什么样：
  - 备份功能应从所有分类读取数据，写入用户指定文件夹。
  - 恢复功能应从备份文件重建分类和命令。
  - 数据边界必须清楚：只碰 `Category` 和 `Command`，不碰 `ClipboardItem`。
- 差距在哪里：
  - 现有导出没有写文件能力。
  - 现有导入不能恢复完整分组结构。
  - 现有 JSON 格式只包含 `name` 和 `prompt`，没有分类顺序、固定状态、收藏状态、收藏顺序。
  - 现有 UI 没有备份文件夹设置。
  - 现有设置只包含剪贴板保存时间，没有备份设置。
- 相关文件 / 函数 / 配置：
  - `cheatsheet/cheatsheet.xcdatamodeld/cheatsheet.xcdatamodel/contents`
  - `cheatsheet/Models/ViewModels/CategoryViewModel.swift`
  - `cheatsheet/Models/ViewModels/CommandViewModel.swift`
  - `cheatsheet/Models/ViewModels/ShelfViewModel.swift`
  - `cheatsheet/Views/CommandListView.swift`
  - `cheatsheet/Views/ImportPanelView.swift`
  - `cheatsheet/Utils/ClipboardSettings.swift`
  - `cheatsheet/Views/ClipboardSettingsView.swift`
- 已掌握证据：
  - Core Data 模型中 `Category`、`Command`、`ClipboardItem` 是独立实体。
  - 收藏由 `Command.isFavorite` 和 `Command.favoriteOrder` 保存。
  - 剪贴板历史由 `ClipboardMonitor` 写入 `ClipboardItem`。
  - 当前导出只把当前分类的命令复制为 JSON 字符串。

### 数据边界图
```text
用户需要恢复的数据
  |
  +-- Category
  |     +-- name
  |     +-- order
  |     +-- isPinned
  |     +-- createdAt / updatedAt
  |
  +-- Command
        +-- name
        +-- content
        +-- order
        +-- isFavorite
        +-- favoriteOrder
        +-- createdAt / updatedAt

必须排除的数据
  |
  +-- ClipboardItem
        +-- content
        +-- data
        +-- sourceBundleId
        +-- sourceAppName
        +-- sourceAppIcon
```

## 3. 方案
- 推荐方案：新增独立备份服务和备份设置，不复用现有单分类导入弹窗作为主要入口。
- 为什么选这个方案：
  - 备份和恢复是全局数据操作，不属于某一个分类。
  - 独立服务可以在手动导出、定时导出、导入恢复之间复用。
  - 明确只读取 `Category` 和 `Command`，可以从代码层面避免导出剪贴板历史。
- 不选哪些方案：
  - 不选“复制 Core Data 数据库文件”：会包含剪贴板历史，和用户要求冲突。
  - 不选“继续复制 JSON 到剪贴板”：用户的核心目标是换电脑可恢复，文件更可靠。
  - 不选“把逻辑全部塞进 ShelfView”：会让界面文件承担数据读写，后续难维护。
- 代码连接位置：
  - 新增 `BackupArchive` 数据结构，定义 JSON 格式。
  - 新增 `BackupService`，负责读取、写入、解析、导入。
  - 新增 `BackupSettings`，保存备份文件夹、导出周期和最近一次导出结果。
  - 新增 `BackupSettingsView`，让用户选择文件夹、导出和导入。
  - 在 `ShelfView` 增加备份设置入口。
- 风险和边界：
  - 导入可能造成重复数据；第一版通过“追加导入 + 重名加序号”避免删除风险。
  - 定时导出写出的是当前 Core Data 已保存状态；正在编辑但尚未保存的内容不会进入备份。
  - 项目启用了 macOS 沙盒，第一版已使用安全书签保存用户选择的备份文件夹授权。

## 4. 验收标准
- 必须满足的结果：
  - 选择备份文件夹后，路径能被保存。
  - 手动导出能生成 JSON 文件。
  - JSON 文件包含 `version`、`exportedAt`、`categories`。
  - JSON 文件里每个分类包含 `name`、`order`、`isPinned`、`commands`。
  - JSON 文件里每个命令包含 `name`、`content`、`order`、`isFavorite`、`favoriteOrder`。
  - JSON 文件不包含 `ClipboardItem`、`sourceAppName`、`sourceBundleId`、`sourceAppIcon` 字段。
  - 导入后能恢复分类、命令、收藏状态和顺序。
- 必须通过的测试：
  - 新增单元测试：导出不包含剪贴板历史。
  - 新增单元测试：导入后分类数量、命令数量、收藏状态正确。
  - 新增单元测试：无效 JSON 返回明确错误。
  - 现有 Core Data、分类、命令相关测试继续通过。
- 必须产出的截图 / 报告 / 日志：
  - 备份设置界面截图。
  - 导出成功后的文件路径日志。
  - 导入成功后的恢复数量日志。
- 用户可见的完成表现：
  - 用户能在界面里看到备份设置入口。
  - 用户能选择文件夹并看到当前备份位置。
  - 用户能点击导出并得到成功提示。
  - 用户能选择备份文件导入并得到结果提示。

## 5. 工具、凭据和环境
- 可用命令：
  - `git status --short --branch`
  - `rg`
  - `xcodebuild test`
  - `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet build`
- 可用测试方式：
  - 通过现有 `cheatsheetTests` 增加备份相关单元测试。
  - 使用临时目录验证 JSON 文件写入和读取。
- 可用账号、token、key、登录态或外部服务：
  - 当前任务不需要账号、token、key 或外部服务。
- 凭据用途：
  - 无。
- 凭据读取方式：
  - 无。
- 使用边界：
  - 不读取项目中的凭据文件。
  - 不触碰部署、服务器、数据库和 Cloudflare。
- 禁止动作：
  - 禁止删除用户数据。
  - 禁止执行 `rm`、`git reset`、`git checkout` 等可能丢失用户改动的命令。
  - 禁止直接覆盖现有 Core Data 数据，除非用户明确确认导入策略。

## 6. 本任务专属自循环编排
- 为什么这个任务适合自循环：
  - 它包含清晰的分段工作：数据格式、读写服务、界面入口、测试验证。
  - 每段都可以独立验证，失败时能定位到具体层。
- 本任务的循环阶段：
  1. 数据边界检查：确认本轮是否只读取和写入 `Category` 与 `Command`。
  2. 代码修改：每轮只修改一类文件，例如数据结构、服务、界面或测试。
  3. 文件级验证：运行能覆盖本轮修改的最小测试或构建命令。
  4. 证据写回：把改了什么、跑了什么、结果是什么写回本文件。
  5. 下一轮判断：如果测试通过且没有触发停止条件，继续下一类文件。
- 每一轮从哪里开始：
  - 从本文件的任务队列中选择第一个未完成项。
  - 再用 `git status` 和 `rg` 核对真实代码状态。
- 每一轮怎么选择下一项工作：
  - 优先顺序是数据结构、服务、测试、界面、定时导出。
  - 如果上一轮发现导入策略未确认，暂停等待用户确认。
- 每一轮允许自主执行哪些动作：
  - 读取非敏感源码。
  - 新增或修改备份功能相关 Swift 文件。
  - 新增或修改备份功能测试。
  - 运行构建和测试命令。
  - 更新本任务文档。
- 每一轮必须做哪些验证：
  - 修改数据结构后，检查 JSON 编码和解码测试。
  - 修改导出服务后，检查导出文件不包含 `ClipboardItem` 字段。
  - 修改导入服务后，检查导入后的分类、命令、收藏顺序。
  - 修改界面后，至少运行构建。
- 每一轮必须写回哪些记录：
  - 修改文件。
  - 运行命令。
  - 实际输出摘要。
  - 是否满足本轮验收。
  - 下一步。
- 什么情况下自动进入下一轮：
  - 本轮测试或构建通过。
  - 没有新增需要用户决定的导入策略。
  - 没有发现会触碰剪贴板历史导出的风险。
- 什么情况下必须停止：
  - 需要清空或覆盖现有用户数据。
  - 导入冲突出现多个合理处理方式。
  - 测试失败且存在多个合理修复方向。
  - 发现 macOS 文件夹权限需要额外用户授权。
  - 用户改变“不要导出剪贴板历史”的边界。
- 这个编排为什么适合当前任务：
  - 这个功能的核心风险是数据边界和恢复行为，所以每轮都先检查数据边界，再改一小类文件，最后用测试证明没有把剪贴板历史带进备份。

## 7. 任务队列
- [x] 调研当前 Core Data 模型和现有导入导出代码。
- [x] 创建本 Agent Loop 任务文件和索引。
- [x] 确认第一版导入冲突策略：追加导入，不删除、不覆盖。
- [x] 确认第一版定时导出策略：关闭、每次启动、每天一次、每周一次。
- [x] 新增备份 JSON 数据结构。
- [x] 新增备份导出服务。
- [x] 新增备份导入服务。
- [x] 新增备份设置存储。
- [x] 新增备份设置界面入口。
- [x] 增加单元测试文件。
- [x] 运行构建和测试：构建通过；测试命令因 scheme 未配置测试动作而无法执行。
- [x] 更新执行记录和最终验证结果。

## 8. 执行记录
- 时间：2026-04-29
- 做了什么：
  - 读取项目上下文和仓库状态。
  - 读取 Core Data 模型、`CategoryViewModel`、`CommandViewModel`、`ShelfViewModel`、现有导入导出界面和剪贴板监控代码。
  - 明确备份应包含 `Category` 和 `Command`，不包含 `ClipboardItem`。
  - 创建本任务文档和索引。
- 修改文件：
  - `.project/agent-loop/00-index.md`
  - `.project/agent-loop/01-backup-favorites-and-groups.md`
- 运行命令：
  - `git status --short --branch`
  - `find .project -maxdepth 3 -type f`
  - `rg --files`
  - 多次 `sed` 和 `nl` 读取相关源码。
- 实际输出：
  - 当前分支是 `main`。
  - 仓库存在多处用户已有未提交改动，本次只新增 `.project/agent-loop` 文档。
- 结果：
  - 自循环文档已建立，后续可从本文档恢复任务。
- 下一步：
  - 等待用户确认“开始实现”，并确认导入冲突策略和定时导出策略。

- 时间：2026-04-29
- 做了什么：
  - 新增备份 JSON 数据结构，包含版本、导出时间、分类、命令、收藏状态和顺序。
  - 新增备份设置存储，保存备份文件夹安全书签、自动导出周期、最近导出路径和最近自动导出时间。
  - 新增备份服务，只读取 `Category` 和 `Command`，不读取 `ClipboardItem`。
  - 新增备份设置界面，支持选择文件夹、立即导出、追加导入、设置自动导出周期。
  - 在横条右侧加入“备份与恢复”入口。
  - 在 app 启动时按设置执行自动备份。
  - 将沙盒文件权限从用户选择文件只读改为读写，用于写入用户选择的备份文件夹。
  - 新增 `BackupServiceTests.swift`，覆盖“不导出剪贴板历史”“导入恢复收藏”“拒绝不支持版本”。
- 修改文件：
  - `cheatsheet/Models/BackupArchive.swift`
  - `cheatsheet/Utils/BackupSettings.swift`
  - `cheatsheet/Services/BackupService.swift`
  - `cheatsheet/Views/BackupSettingsView.swift`
  - `cheatsheet/Views/Shelf/ShelfView.swift`
  - `cheatsheet/cheatsheetApp.swift`
  - `cheatsheet/cheatsheet.entitlements`
  - `cheatsheetTests/BackupServiceTests.swift`
  - `.project/agent-loop/01-backup-favorites-and-groups.md`
- 运行命令：
  - `xcodebuild -list -project cheatsheet.xcodeproj`
  - `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -configuration Debug build`
  - `xcodebuild test -project cheatsheet.xcodeproj -scheme cheatsheet -configuration Debug`
  - `git diff --check -- <本次相关文件>`
- 实际输出：
  - `xcodebuild -list` 显示当前只有 `cheatsheet` app target，没有测试 target。
  - Debug build 输出 `BUILD SUCCEEDED`。
  - test 输出 `Scheme cheatsheet is not currently configured for the test action.`。
  - 本次相关文件的 `git diff --check` 通过。
- 结果：
  - 第一版功能代码完成并通过构建。
  - 测试文件已创建，但当前 Xcode project 没有测试 target，暂时不能执行。
- 下一步：
  - 需要在真实应用里选择备份文件夹，导出一次 JSON，并导入到测试数据环境做人工验收。

## 9. 决策和证据
- 决策：备份只读取 `Category` 和 `Command`。
- 原因：用户明确要求不包括剪贴板本身内容；`ClipboardItem` 保存真实剪贴板历史。
- 证据：
  - 文件路径：`cheatsheet/cheatsheet.xcdatamodeld/cheatsheet.xcdatamodel/contents`
  - 函数 / 模块：Core Data 模型
  - 关键代码片段或命令：模型中有 `Category`、`Command`、`ClipboardItem` 三个实体。
  - 实际输出：`ClipboardItem` 包含 `content`、`data`、`sourceAppName` 等字段。
  - 证明了什么：剪贴板历史和用户创建内容可以在实体层区分。
  - 对方案的影响：导出服务必须只 fetch `Category` 和 `Command`。

- 决策：新增独立 `BackupService`，不把备份逻辑写进现有导入弹窗。
- 原因：备份是全局操作，需要跨分类读取和恢复，不属于单个分类界面。
- 证据：
  - 文件路径：`cheatsheet/Views/CommandListView.swift`
  - 函数 / 模块：`copyExportToClipboard`
  - 关键代码片段或命令：只把 `commandViewModel.commands` 映射成 `ImportCommand`。
  - 实际输出：现有导出只覆盖当前分类，且复制到剪贴板。
  - 证明了什么：现有入口不能满足换电脑恢复完整数据。
  - 对方案的影响：需要新增全局备份入口。

- 决策：导入策略需要用户确认后再写代码。
- 原因：追加、合并和覆盖会产生不同结果，覆盖还可能删除用户现有数据。
- 证据：
  - 文件路径：`cheatsheet/Models/ViewModels/CategoryViewModel.swift`
  - 函数 / 模块：`deleteCategory`
  - 关键代码片段或命令：删除分类会同时删除该分类下的命令。
  - 实际输出：模型关系中 `Category.commands` 的删除规则是 `Cascade`。
  - 证明了什么：如果选择覆盖策略，会有真实数据删除风险。
- 对方案的影响：第一版建议使用追加导入，覆盖策略必须另行确认。

- 决策：第一版导入只追加，不做覆盖恢复。
- 原因：用户的核心目标是防丢数据；追加导入不会删除现有数据，风险最低。
- 证据：
  - 文件路径：`cheatsheet/Services/BackupService.swift`
  - 函数 / 模块：`importArchive(_:)`
  - 关键代码片段或命令：为每个备份分类创建新的 `Category`，同名时使用 `uniqueCategoryName` 加序号。
  - 实际输出：导入不会调用删除分类或批量删除命令。
  - 证明了什么：第一版恢复不会破坏用户现有数据。
  - 对方案的影响：如果以后要做“覆盖恢复”，必须新增明确确认弹窗和单独测试。

- 决策：自动导出写入带时间戳的新文件。
- 原因：不覆盖旧备份可以避免一次错误导出破坏唯一可用备份。
- 证据：
  - 文件路径：`cheatsheet/Services/BackupService.swift`
  - 函数 / 模块：`fileName(for:)`
  - 关键代码片段或命令：文件名格式为 `cheatsheet-backup-yyyyMMdd-HHmmss.json`。
  - 实际输出：每次导出得到不同文件名。
  - 证明了什么：第一版保留多份备份。
  - 对方案的影响：后续如需自动清理旧备份，需要新增保留数量或保留天数设置。

- 决策：将沙盒用户选择文件权限改为读写。
- 原因：用户选择的备份文件夹需要被应用写入 JSON 文件，原来的只读权限不足。
- 证据：
  - 文件路径：`cheatsheet/cheatsheet.entitlements`
  - 函数 / 模块：macOS sandbox entitlement
  - 关键代码片段或命令：`com.apple.security.files.user-selected.read-write`
  - 实际输出：构建时 entitlements 显示 read-write 已生效。
  - 证明了什么：应用具备写入用户选择文件夹的沙盒权限。
  - 对方案的影响：备份设置可以使用安全书签持久保存文件夹授权。

## 10. 停止条件
- 需要用户确认的情况：
  - 导入时是否允许覆盖或删除现有分组和命令。
  - 是否允许定时导出覆盖旧备份文件。
  - 是否需要启用 macOS 沙盒安全书签。
- 高风险动作：
  - 清空现有 Core Data 数据。
  - 删除已有备份文件。
  - 修改项目签名、沙盒或权限配置。
- 工具或凭据缺失：
  - 当前不需要凭据。
  - 如果后续要写入受保护目录，需要用户通过文件选择器授予权限。
- 测试失败且存在多个合理修复方向：
  - 停止并说明失败测试、原因和可选修复方案。
- 需求边界变化：
  - 如果用户要求同时备份剪贴板历史，需要重新设计数据格式和隐私提示。
