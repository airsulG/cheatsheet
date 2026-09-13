# Shelf Live Command Refresh Feature Flow

<<<<<<<<<<<<<<<<<<<< 00 Scope <<<<<<<<<<<<<<<<<<<<

This flow covers the user-visible refresh behavior after creating, editing, deleting, moving, favoriting, or importing commands from the bottom Shelf panel. The durable save path already works; the target is immediate visibility in the current Shelf list.

Not covered:
- Redesigning command editor fields.
- Changing Core Data schema.
- Adding sync or external watchers.
- Changing clipboard history refresh.

<<<<<<<<<<<<<<<<<<<< 01 Finished User Experience <<<<<<<<<<<<<<<<<<<<

I open the bottom Shelf panel and select a category. I click the add-command card, enter a title and command content, then save. The editor closes, and the new command card appears in the current category lane without me switching to another tab and back.

If I edit an existing card, its title and content preview update in place after save. If I import JSON into the selected category, the newly imported command cards appear in that same lane after the import panel completes. If the command is favorited or unfavorited, the current category lane and favorites lane both reflect the updated state the next time they are visible.

<<<<<<<<<<<<<<<<<<<< 02 ASCII Frames <<<<<<<<<<<<<<<<<<<<

Frame 1: before save.

```text
+----------------------------------------------------------------------------+
| [剪贴板] [收藏] [产品提示词*] [+]                     [导入] [设置] [搜索] |
+----------------------------------------------------------------------------+
| [01 问题发现] [02 用户研究] [ + 添加命令 ]                                    |
+----------------------------------------------------------------------------+
```

Frame 2: user saves a new command.

```text
+-------------------------+
| 新建命令                 |
+-------------------------+
| 名称: 03 市场定位         |
| 内容: ...                |
|                  [保存]  |
+-------------------------+
```

Frame 3: editor closes and current Shelf list updates immediately.

```text
+----------------------------------------------------------------------------+
| [剪贴板] [收藏] [产品提示词*] [+]                     [导入] [设置] [搜索] |
+----------------------------------------------------------------------------+
| [01 问题发现] [02 用户研究] [03 市场定位] [ + 添加命令 ]                       |
+----------------------------------------------------------------------------+
```

<<<<<<<<<<<<<<<<<<<< 03 State Topology <<<<<<<<<<<<<<<<<<<<

```text
+--------------------+      +---------------------+      +------------------+
| Command editor     | ---> | CommandViewModel    | ---> | Core Data Command|
| save action        |      | create/update/fetch |      | saved            |
+--------------------+      +----------+----------+      +------------------+
                                        |
                                        v
                           +-------------------------+
                           | commandVM.objectWillChange |
                           +------------+------------+
                                        |
                                        v
                           +-------------------------+
                           | ShelfViewModel forwards |
                           | objectWillChange        |
                           +------------+------------+
                                        |
                                        v
                           +-------------------------+
                           | ShelfView re-renders    |
                           | current card lane       |
                           +-------------------------+
```

<<<<<<<<<<<<<<<<<<<< 04 Acceptance Criteria <<<<<<<<<<<<<<<<<<<<

| ID | Scenario | Expected Result |
|---|---|---|
| FF-1 | Create command from selected Shelf category | New card appears without tab switching |
| FF-2 | Edit command from Shelf | Existing card title/preview updates without tab switching |
| FF-3 | Import valid JSON from Shelf | Imported cards appear after import panel completes |
| FF-4 | Delete command from Shelf | Deleted card disappears immediately |
| FF-5 | Toggle favorite state | Relevant category/favorites views reflect the change when visible |
