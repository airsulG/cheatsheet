# Agent Loop 任务索引

当前执行模式：unattended
execution_mode: unattended
unattended_started_at: 2026-05-25 12:35
last_active_task: 10-coredata-crash-mainqueue-merge.md

## 当前任务

| 文件名 | 适用场景 | 当前目标 |
| --- | --- | --- |
| `01-backup-favorites-and-groups.md` | 为本地收藏、分组和用户创建的剪贴内容增加备份与恢复能力 | 先实现可选择文件夹、手动导出、手动导入；再按确认范围加入定时导出 |
| `02-shelf-drag-swap-performance.md` | 底部横条命令/收藏卡片水平拖拽卡顿和交换结果错误 | done；已改为拖动中只预览、松手后交换并保存一次 |
| `03-shelf-title-auto-sort.md` | 底部横条命令/收藏卡片增加按标题自动排序 | done；已增加手动/标题排序模式，标题排序下禁用拖拽，构建通过 |
| `04-shelf-toolbar-button-style.md` | 底部横条顶部小图标按钮样式统一 | done；已以添加按钮描边圆样式统一排序、备份、设置、搜索按钮，构建通过 |
| `05-shelf-clipboard-loading-performance.md` | 底部横条剪贴板首开卡死和列表切换不跟手 | done；横条已改用轻量预览模型、后台分页和受控加载更多，构建通过 |
| `06-shelf-search-and-sort-feedback.md` | 底部横条搜索和排序状态反馈 | done；已增加搜索自动聚焦、Command-F、Esc 关闭、搜索范围和标题排序提示，构建通过 |
| `07-shelf-sort-toggle-and-source-app.md` | 底部横条排序入口和剪贴板来源 App 展示 | done；已改成文字切换排序按钮，并恢复剪贴板来源 App 图标和名称，构建通过 |
| `08-shelf-resizable-height.md` | 底部横条上边缘拖拽调高和长内容预览 | done；已增加面板高度持久化、顶部拖拽热区和随高度增长的卡片内容预览，构建通过 |
| `09-shelf-open-animation-smoothness.md` | 底部横条快捷键打开动画卡顿 | done；已将打开/关闭从高度动画改为固定高度位移动画，并减少打开期间重复解码和二次动画，构建通过 |
| `10-coredata-crash-mainqueue-merge.md` | 长跑后 NSInvalidArgumentException 在 `_postRefreshedObjectsNotificationAndClearList` 路径上崩溃 | done；ShelfViewModel/ClipboardHistoryViewModel 的 contextDidSave 改为 main 队列 fetch，移除手动 mergeChanges；xcodebuild 通过 |

## 任务状态字段

```text
任务：10-coredata-crash-mainqueue-merge.md
status: done
phase: implementation-complete
role_next: none
plan_review_policy: auto_approved
depends_on: none
parallel_safe: no
current_goal: 让 viewContext.automaticallyMergesChangesFromParent 独占主队列合并；ShelfViewModel/ClipboardHistoryViewModel 仅在主队列上 fetch 与写 @Published
next_action: 等待 Karl 长跑验收（30 分钟高频复制粘贴）
blocker: none
updated_at: 2026-05-25 12:34
```
