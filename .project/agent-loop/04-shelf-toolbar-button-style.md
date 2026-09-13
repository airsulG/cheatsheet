# 04 底部横条顶部小图标按钮样式统一

## 0. 当前状态
- 当前阶段：done
- 当前分支：main
- 当前是否允许自动执行：Karl 已确认 `ok 开始`
- 当前阻塞：none
- 下一步：none

## 1. 目标和需求
- 关联 EARS：本项目暂无 `.project/EARS/EARS.md`
- 用户真正想解决的问题：底部横条顶部的添加、备份、搜索按钮样式不一致。
- 最终要看到的结果：以添加按钮的小描边圆样式为参照，统一其他同区域小图标按钮。
- 成功标准：
  - 添加、排序、备份、剪贴板设置、搜索按钮使用同一套图标字号、字重、内边距和圆形描边。
  - 按钮原功能不变。
  - Debug build 通过。
- 不做什么：
  - 不改变排序、备份、设置、搜索、添加的行为。
  - 不改搜索输入框展开态样式。
  - 不改卡片样式和标签条样式。
- 已确认内容：Karl 已同意开始修改。
- 未确认内容：none

## 2. 当前状态和目标差
- 当前系统是什么样：
  - 添加按钮使用 `12px bold + padding(6) + Circle().stroke(separator)`。
  - 备份、设置、搜索、排序使用 `14px regular + padding(8) + Circle().fill(controlBackgroundColor)`。
- 目标系统应该是什么样：同一区域小图标按钮全部使用添加按钮样式。
- 差距在哪里：按钮 label 分散手写，缺少统一 helper。
- 相关文件 / 函数 / 配置：
  - `cheatsheet/Views/Shelf/ShelfView.swift`
- 已掌握证据：`ShelfView.headerBar` 中各按钮 label 样式不同。

## 3. 方案
- 推荐方案：在 `ShelfView` 内抽一个 `toolbarIcon(_:)` helper，所有小图标按钮统一调用。
- 为什么选这个方案：修改范围小，能让后续新增按钮也复用同一视觉样式。
- 不选哪些方案：不创建新的全局组件文件，因为当前只影响 `ShelfView` 一个页面。
- 接驳点：添加按钮、排序菜单 label、备份按钮、剪贴板设置按钮、搜索按钮。
- 风险和边界：外接硬盘备份图标比较宽，统一字号后视觉会更紧凑；这符合“以添加按钮为参照”的目标。

## 4. 验收标准
- 必须满足的结果：同区域按钮外观统一，仍可点击。
- 必须通过的测试：
  - `git diff --check`
  - `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -configuration Debug build`
- 必须产出的截图 / 报告 / 日志：本轮无截图要求。
- 用户可见的完成表现：右上角小按钮统一为添加按钮那种小描边圆。

## 5. 工具、凭据和环境
- 可用命令：
  - `git diff --check`
  - `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -configuration Debug build`
- 可用测试方式：当前 scheme 可构建；test action 仍未配置。
- 可用账号、token、key、登录态或外部服务：无。
- 凭据用途：无。
- 凭据读取方式：无。
- 使用边界：不提交、不删除、不回滚已有未提交改动。
- 禁止动作：不删除本地备份 JSON。

## 6. 本任务专属自循环编排
- 为什么这个任务适合自循环：范围集中在一个 SwiftUI 视图里的重复样式。
- 本任务的循环阶段：确认参照样式 -> 抽 helper -> 替换按钮 -> 构建验证 -> 写回记录。
- 每一轮从哪里开始：从 `ShelfView.headerBar` 的按钮 label 开始。
- 每一轮怎么选择下一项工作：优先统一 label 样式，不改变按钮动作。
- 每一轮允许自主执行哪些动作：编辑 Swift、运行构建、更新 agent-loop。
- 每一轮必须做哪些验证：`git diff --check` 和 Debug build。
- 每一轮必须写回哪些记录：修改文件、验证结果、剩余风险。
- 什么情况下自动进入下一轮：构建失败且错误明确时继续修复。
- 什么情况下必须停止：需要重新设计右侧工具区布局、隐藏按钮、删除功能。
- 这个编排为什么适合当前任务：视觉差异来自重复样式，抽 helper 是最小稳定修复。

## 7. 任务队列
- [x] 创建 agent-loop 任务文档
- [x] 抽出统一小图标按钮 helper
- [x] 替换添加、排序、备份、设置、搜索按钮 label
- [x] 运行构建验证
- [x] 写回执行记录

## 8. 执行记录
- 时间：2026-05-20 11:35 Asia/Shanghai
- 做了什么：创建本任务文档并读取现有按钮代码。
- 修改文件：
  - `.project/agent-loop/04-shelf-toolbar-button-style.md`
- 运行命令：
  - `date '+%Y-%m-%d %H:%M %Z'`
  - `sed -n '1,220p' .project/agent-loop/00-index.md`
  - `nl -ba cheatsheet/Views/Shelf/ShelfView.swift | sed -n '388,510p'`
- 实际输出：确认添加按钮和其他按钮样式差异。
- 结果：准备进入代码修改。
- 下一步：抽 helper 并替换按钮 label。

- 时间：2026-05-20 11:36 Asia/Shanghai
- 做了什么：在 `ShelfView` 内新增 `toolbarIcon(_:)`，并让添加、排序、备份、剪贴板设置、搜索按钮复用同一套图标样式。
- 修改文件：
  - `cheatsheet/Views/Shelf/ShelfView.swift`
  - `.project/agent-loop/04-shelf-toolbar-button-style.md`
  - `.project/agent-loop/00-index.md`
- 运行命令：
  - `git diff --check`
  - `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -configuration Debug build`
- 实际输出：`git diff --check` 无输出；Debug build 输出 `** BUILD SUCCEEDED **`。构建时仍有既有 Preview `@State` warning，和本次按钮样式无关。
- 结果：按钮样式统一完成，构建通过。
- 下一步：等待 Karl 视觉验收。

## 9. 决策和证据
- 决策：以添加按钮样式统一顶部小图标按钮。
- 原因：Karl 明确指定添加按钮作为参照。
- 证据：添加按钮使用描边圆，其他按钮使用填充圆。
- 影响：顶部工具按钮视觉更一致。

- 决策：不把搜索框展开态里的放大镜和关闭按钮一起改成圆形工具按钮。
- 原因：搜索框展开态已经是输入控件内部元素，和未展开时右上角工具按钮不是同一类控件。
- 证据：`ShelfView.headerBar` 在 `isSearching` 为 true 时渲染搜索输入框，未展开时才渲染工具按钮组。
- 影响：只统一右上角工具按钮，不改变搜索输入体验。

## 10. 停止条件
- 需要用户确认的情况：如果要调整布局、隐藏按钮、改变搜索展开方式。
- 高风险动作：删除文件、回滚未提交改动。
- 工具或凭据缺失：无。
- 测试失败且存在多个合理修复方向：暂停说明。
- 需求边界变化：如果要做完整工具栏重设计，另开任务。
