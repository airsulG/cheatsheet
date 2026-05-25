# Agent Loop 任务索引

当前执行模式：unattended
execution_mode: unattended
unattended_started_at: 2026-05-25 12:35
last_active_task: 14-shelf-clipboard-source-app-icon-display.md
current_blocker: 队列里没有可由 agent 自主推进的任务；task 01 / task 14 等待 Karl 真实界面验收。Karl 显式退出无人值守 / 给出新任务前 hold。

## 当前任务

| 文件名 | 适用场景 | 当前目标 |
| --- | --- | --- |
| `01-backup-favorites-and-groups.md` | 为本地收藏、分组和用户创建的剪贴内容增加备份与恢复能力 | awaiting_user_acceptance；第一版编码完成，等待 Karl 实际操作验收手动导出 / 导入流程 |
| `02-shelf-drag-swap-performance.md` | 底部横条命令/收藏卡片水平拖拽卡顿和交换结果错误 | done；已改为拖动中只预览、松手后交换并保存一次 |
| `03-shelf-title-auto-sort.md` | 底部横条命令/收藏卡片增加按标题自动排序 | done；已增加手动/标题排序模式，标题排序下禁用拖拽，构建通过 |
| `04-shelf-toolbar-button-style.md` | 底部横条顶部小图标按钮样式统一 | done；已以添加按钮描边圆样式统一排序、备份、设置、搜索按钮，构建通过 |
| `05-shelf-clipboard-loading-performance.md` | 底部横条剪贴板首开卡死和列表切换不跟手 | done；横条已改用轻量预览模型、后台分页和受控加载更多，构建通过 |
| `06-shelf-search-and-sort-feedback.md` | 底部横条搜索和排序状态反馈 | done；已增加搜索自动聚焦、Command-F、Esc 关闭、搜索范围和标题排序提示，构建通过 |
| `07-shelf-sort-toggle-and-source-app.md` | 底部横条排序入口和剪贴板来源 App 展示 | done；已改成文字切换排序按钮，并恢复剪贴板来源 App 图标和名称，构建通过 |
| `08-shelf-resizable-height.md` | 底部横条上边缘拖拽调高和长内容预览 | done；已增加面板高度持久化、顶部拖拽热区和随高度增长的卡片内容预览，构建通过 |
| `09-shelf-open-animation-smoothness.md` | 底部横条快捷键打开动画卡顿 | done；已将打开/关闭从高度动画改为固定高度位移动画，并减少打开期间重复解码和二次动画，构建通过 |
| `10-coredata-crash-mainqueue-merge.md` | 长跑后 NSInvalidArgumentException 在 `_postRefreshedObjectsNotificationAndClearList` 路径上崩溃 | done；ShelfViewModel/ClipboardHistoryViewModel 的 contextDidSave 改为 main 队列 fetch，移除手动 mergeChanges；xcodebuild 通过；commit 45a82b5 |
| `11-shelf-clipboard-icon-and-image-preview.md` | 底部横条剪贴板卡片不再显示来源 App 图标和图片预览 | done；ClipboardPreviewItem 新增 imageData，maxSourceAppIconBytes 放宽到 512KB，ShelfCard image case 真渲染；xcodebuild 通过 |
| `12-shelf-clipboard-fast-open.md` | 唤醒 Shelf 后剪贴板首屏要等几百 ms ~ 几 s | done；ShelfWindowController.show 预取 + AppStorage 记忆默认 tab + fetch 切窄到文本字段 + enrichBlobs 异步补 blob；xcodebuild 通过 |
| `13-shelf-clipboard-incremental-update.md` | 复制一次就整页 reset，闪烁明显 | done；contextDidSave 改为读 userInfo 增量 patch，新增 applyChanges；ShelfViewModel 不再代理转发；xcodebuild 通过 |
| `14-shelf-clipboard-source-app-icon-display.md` | 剪贴板卡片清一色 app.dashed 占位，看不到来源 App 真实图标 | awaiting_user_acceptance；写入端 redraw 32×32（~2KB），读取端 cap 提到 8MB 兜底；xcodebuild 通过 + 本地脚本验证体积比 1:700 |

## 任务状态字段

```text
任务：14-shelf-clipboard-source-app-icon-display.md
status: awaiting_user_acceptance
phase: implementation-complete
role_next: Karl
plan_review_policy: auto_approved
depends_on: 11（done）
parallel_safe: yes
current_goal: 让历史 599 条剪贴板卡片立即显示真实 App 图标，并把新写入控制在 ~2KB
next_action: 等待 Karl ⌘R 启动新构建验收图标显示
blocker: none
updated_at: 2026-05-25 13:58
```
