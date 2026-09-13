# App Settings Route Feature Flow

<<<<<<<<<<<<<<<<<<<< 00 Flow Goal <<<<<<<<<<<<<<<<<<<<

Move app-level maintenance actions behind one Settings route. The Shelf toolbar should no longer expose separate backup and clipboard settings windows. Users open Settings once, then choose the section they need.

Non-goals:
- No change to backup archive format.
- No change to command JSON import from the current category.
- No destructive cleanup without the existing confirmation alerts.
- No return to SwiftUI `.sheet` presentation from the bottom Shelf panel.

<<<<<<<<<<<<<<<<<<<< 01 Primary Journey <<<<<<<<<<<<<<<<<<<<

```text
--------------------+
| User in Shelf      |
+---------+----------+
          |
          v
+--------------------+
| Click Settings     |
+---------+----------+
          |
          v
+-----------------------------+
| App Settings window opens   |
| independent centered window |
+--------------+--------------+
               |
       +-------+--------+
       |                |
       v                v
+--------------+  +----------------+
| Clipboard    |  | Backup         |
| section      |  | section        |
+--------------+  +----------------+
       |                |
       v                v
retain / stats /  folder / auto /
cleanup actions   export / import
```

<<<<<<<<<<<<<<<<<<<< 02 Frames <<<<<<<<<<<<<<<<<<<<

Frame A: Shelf toolbar.

```text
| [剪贴板] [收藏] [分类] [+]              [导入] [设置] [搜索] |
```

Expected behavior:
- Settings button is always visible.
- JSON command import remains separate because it depends on the selected category.
- Backup and clipboard cleanup no longer appear as separate toolbar buttons.

Frame B: Settings window.

```text
+-------------------------------------------------------------+
| 设置                                                   [完成] |
+----------------------+--------------------------------------+
| 横条                 | 命令排序                             |
| 剪贴板               |                                      |
| 备份与恢复           |                                      |
+----------------------+--------------------------------------+
```

Frame C: Backup section.

```text
+-------------------------------------------------------------+
| 设置                                                   [完成] |
+----------------------+--------------------------------------+
| 横条                 |                                      |
| 剪贴板               |                                      |
| 备份与恢复           | 备份文件夹                           |
|                      | 自动导出                             |
|                      | 立即导出 / 从备份文件导入             |
|                      | 最近导出文件                         |
+----------------------+--------------------------------------+
```

<<<<<<<<<<<<<<<<<<<< 03 Acceptance Scenarios <<<<<<<<<<<<<<<<<<<<

| Scenario | Expected Result |
|---|---|
| Open Shelf and click Settings | One independent Settings window opens; Shelf panel is not pushed or resized |
| Switch to Clipboard section | Retention picker, stats, and cleanup actions are visible |
| Switch to Backup section | Backup folder, automatic export, manual export, and import actions are visible |
| Trigger cleanup | Existing destructive confirmation alert appears before deleting clipboard records |
| Trigger backup import | Existing append-import confirmation appears before importing archive content |
| Reopen Settings while open | Existing Settings window is focused instead of creating duplicates |
