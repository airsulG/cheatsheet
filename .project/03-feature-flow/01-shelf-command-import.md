# Shelf Command Import Feature Flow

<<<<<<<<<<<<<<<<<<<< 00 Scope <<<<<<<<<<<<<<<<<<<<

This flow exposes the existing JSON command import capability inside the bottom Shelf panel. It serves users who want to paste or externally generate a list of command prompts and add them to a visible command category.

Not covered:
- Multi-category prompt package import.
- Folder watching or automatic external ingestion.
- Direct SQLite writes.
- Backup archive import UI changes.

<<<<<<<<<<<<<<<<<<<< 01 Finished User Experience <<<<<<<<<<<<<<<<<<<<

I open the bottom Shelf panel. If I am on clipboard history or favorites, I can still see command management controls, but the import action tells me I need to choose a real category first. When I select a command category tab, the toolbar shows an import icon near backup and search.

I click the import icon. A centered bulk import window opens independently from the bottom Shelf panel and clearly says which category will receive the commands. I paste JSON in the existing format:

```json
[
  { "name": "01 问题发现与机会评估", "prompt": "..." }
]
```

I press import. The app creates real `Command` objects in the selected category. After success, the category list refreshes and the new cards appear in Shelf. Clicking a new card copies its prompt content to the clipboard.

If I click import while no category is selected, the app does not guess a target. It shows a compact alert telling me to choose a category first.

<<<<<<<<<<<<<<<<<<<< 02 ASCII Frames <<<<<<<<<<<<<<<<<<<<

Frame 1: category selected, import is available.

```text
+--------------------------------------------------------------------------------+
| [剪贴板] [收藏] [产品提示词] [+]                          [导入] [设置] [搜索] |
+--------------------------------------------------------------------------------+
| [01 问题发现...] [02 用户研究...] [ + 新建命令 ]                                  |
+--------------------------------------------------------------------------------+
```

This proves the import action belongs to the Shelf command-management toolbar and targets the currently selected category.

Frame 2: clipboard or favorites selected, import does not guess a target.

```text
+--------------------------------------------------------------------------------+
| [剪贴板*] [收藏] [产品提示词] [+]                        [导入] [设置] [搜索] |
+--------------------------------------------------------------------------------+
| Clipboard cards...                                                              |
+--------------------------------------------------------------------------------+
| Alert: 请选择一个分类后再导入命令。                                                |
+--------------------------------------------------------------------------------+
```

This keeps command import from silently writing to the wrong place.

Frame 3: existing import panel is reused.

```text
+--------------------------------------------------------------+
| 批量导入命令                                      [x]          |
| 导入到分类：产品提示词                                         |
+--------------------------------------------------------------+
| 导入格式说明                                                   |
| JSON 数据                                                     |
| +----------------------------------------------------------+ |
| | [ { "name": "...", "prompt": "..." } ]                   | |
| +----------------------------------------------------------+ |
|                                         [取消] [导入命令]      |
+--------------------------------------------------------------+
```

This avoids creating a second import experience and keeps the existing JSON contract.

<<<<<<<<<<<<<<<<<<<< 03 Flow Topology <<<<<<<<<<<<<<<<<<<<

```text
+--------------------+       +------------------------+
| User opens Shelf   | ----> | Current tab resolved   |
+--------------------+       +-----------+------------+
                                         |
                    +--------------------+-------------------+
                    |                                        |
                    v                                        v
       +------------------------+              +----------------------------+
       | Category tab selected  |              | Clipboard / Favorites tab  |
       +-----------+------------+              +-------------+--------------+
                   |                                         |
                   v                                         v
       +------------------------+              +----------------------------+
       | Import button opens    |              | Import button shows target |
       | ImportPanelWindow      |              | required alert             |
       +-----------+------------+              +----------------------------+
                   |
                   v
       +------------------------+       +------------------------+
       | JSON decoded as        | ----> | CommandViewModel       |
       | [ImportCommand]        |       | creates Command rows   |
       +-----------+------------+       +-----------+------------+
                   |                                |
                   v                                v
       +------------------------+       +------------------------+
       | Success / failure      | <---- | Core Data save +       |
       | feedback in window     |       | category refresh       |
       +------------------------+       +------------------------+
```

<<<<<<<<<<<<<<<<<<<< 04 Acceptance Criteria <<<<<<<<<<<<<<<<<<<<

| ID | Scenario | Expected Result |
|---|---|---|
| FF-1 | User selects a category tab in Shelf | Toolbar shows an import icon with help text for JSON import |
| FF-2 | User clicks import on a category tab | `ImportPanelView` opens in an independent centered window for that selected category |
| FF-3 | User imports valid JSON | New command cards appear in that category after import |
| FF-4 | User clicks import on clipboard or favorites | App shows a target-required alert and creates no command |
| FF-5 | User imports invalid JSON | Existing import panel shows a failure message and keeps the panel open |
