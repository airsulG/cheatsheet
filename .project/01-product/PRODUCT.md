# PRODUCT

<<<<<<<<<<<<<<<<<<<< 00 Product Identity <<<<<<<<<<<<<<<<<<<<

`cheatsheet` is a local macOS command and clipboard utility. Its main user-visible experience is the bottom Shelf panel: a fast launcher for clipboard history, favorite commands, and categorized command snippets. The app stores durable user data through Core Data entities: `Category`, `Command`, and `ClipboardItem`.

<<<<<<<<<<<<<<<<<<<< 01 Core Objects <<<<<<<<<<<<<<<<<<<<

| Object | Meaning | Long-Term Owner |
|---|---|---|
| Category | User-created command group shown as a Shelf tab | Core Data `Category` |
| Command | Reusable snippet with a title and content copied to clipboard on click | Core Data `Command` |
| ClipboardItem | Captured system clipboard history item | Core Data `ClipboardItem` |

<<<<<<<<<<<<<<<<<<<< 02 Product Rules <<<<<<<<<<<<<<<<<<<<

1. The bottom Shelf panel is a primary operating surface, not a secondary debug view. Capabilities needed for daily command management should be reachable from Shelf when they are safe and compact enough.
2. Command import writes real `Command` objects into a selected `Category`. It must not write directly to the Core Data backing SQLite store.
3. External data should enter the app through an import contract such as JSON text or backup archives, then be persisted by the app through Core Data contexts.
4. Clipboard history and command snippets are separate product objects. Importing command prompts must not create `ClipboardItem` records.
5. Backup files named `cheatsheet-backup-*.json` are runtime artifacts and should not be treated as source-controlled product facts.
6. Shelf command lists must reflect command create, edit, delete, move, favorite, and import results without requiring the user to switch tabs or reopen the panel.
7. Backup, restore, clipboard retention, storage statistics, and destructive cleanup are global app maintenance capabilities. They should live behind one Settings route instead of separate Shelf toolbar windows.

<<<<<<<<<<<<<<<<<<<< 03 当前实现与历史问题 <<<<<<<<<<<<<<<<<<<<

横条已经接入分类命令 JSON 导入、子 ViewModel 更新通知和统一设置窗口。设置包含“横条”“剪贴板”“备份与恢复”三个区块；排序入口位于“横条”设置，默认按标题排序，切换为手动排序后可拖动交换卡片位置。

分类与收藏的搜索按标题或完整正文匹配。无标题栏面板通过 `ShelfPanel.canBecomeKey` 接收键盘输入，搜索字段出现时再请求窗口和字段焦点。剪贴板搜索仍按已加载预览中的类型、文本预览和来源 App 名称过滤，不能把它描述成全库全文搜索。

这些路径的实现已存在，完整交互验收状态见 [Issue #5](https://github.com/airsulG/cheatsheet/issues/5) 和关联 PR。下面保留的是这些实现解决的原始问题背景，并非当前缺失功能清单。

The app already has a JSON command import panel in older main-window surfaces, but the active bottom Shelf panel does not expose it. This makes the app appear to lack bulk import even though the underlying import UI and command creation path exist.

After command creation or editing from Shelf, saved data can exist in Core Data while the visible Shelf card lane stays stale until the user switches tabs. This is a UI state propagation bug: the active Shelf surface should update from the same command state changes that already save successfully.

Backup and clipboard cleanup currently open as two separate utility windows from the Shelf toolbar. That split exposes implementation history instead of user intent: both surfaces are app-level maintenance tasks, and the Shelf should route to one Settings window with clear sections.
