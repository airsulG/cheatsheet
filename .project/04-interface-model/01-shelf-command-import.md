# Shelf Command Import Interface Model

<<<<<<<<<<<<<<<<<<<< 00 Source and Scope <<<<<<<<<<<<<<<<<<<<

Source feature-flow: `.project/03-feature-flow/01-shelf-command-import.md`.

This model covers the bottom Shelf panel toolbar, import entry state, independent import window presentation, and target-required alert. It reuses the existing `ImportPanelView` and `CommandViewModel` import path.

<<<<<<<<<<<<<<<<<<<< 01 Page Frame <<<<<<<<<<<<<<<<<<<<

```text
+--------------------------------------------------------------------------------+
| TagStripView                                          ShelfToolbarActions        |
| [clipboard] [favorites] [category tabs...] [+]        [sort] [import] [backup]  |
|                                                       [settings?] [search] brand |
+--------------------------------------------------------------------------------+
| Horizontal card lane                                                            |
| - clipboard preview cards OR favorite command cards OR selected category commands|
+--------------------------------------------------------------------------------+
```

<<<<<<<<<<<<<<<<<<<< 02 Component Tree <<<<<<<<<<<<<<<<<<<<

```text
ShelfView
  headerBar
    TagStripView
      addCategoryButton
    ShelfToolbarActions
      importCommandsButton
      settingsButton
      searchButton
  horizontalCardLane
  ImportPanelWindowController
    ImportPanelView
  targetRequiredAlert
```

<<<<<<<<<<<<<<<<<<<< 03 Component Responsibilities <<<<<<<<<<<<<<<<<<<<

| Component | Responsibility | Not Responsible For |
|---|---|---|
| `ShelfView.headerBar` | Shows current Shelf navigation and compact command actions | Parsing JSON |
| `importCommandsButton` | Opens import panel when a category is selected; otherwise shows target alert | Choosing a category automatically |
| `ImportPanelView` | Collects JSON text, decodes `[ImportCommand]`, creates commands | Multi-category import |
| `CommandViewModel` | Creates `Command` records and refreshes current category commands | Direct SQLite writes |
| `targetRequiredAlert` | Prevents import without a concrete category target | Creating categories |

<<<<<<<<<<<<<<<<<<<< 04 Component States <<<<<<<<<<<<<<<<<<<<

| Component | State | Trigger | Visible Feedback | Data Impact | Exit |
|---|---|---|---|---|---|
| import button | enabled-targeted | `selectedCategory != nil` | Import icon is visible and clickable | none | user opens import window |
| import button | target-missing | clipboard or favorites tab | Click opens alert | none | user selects category |
| import window | editing | independent window opened | JSON editor and import button | none | import / cancel |
| import window | importing | user clicks import | existing disabled state during import | pending Core Data writes | success / failure |
| import window | success | valid JSON saved | success message, auto-dismiss | new `Command` rows | dismiss |
| import window | failure | invalid JSON or save error | failure message | no intended command writes | edit JSON / cancel |

<<<<<<<<<<<<<<<<<<<< 05 User Actions and Events <<<<<<<<<<<<<<<<<<<<

| User Action | Trigger Component | Event | Data Changed | Page Feedback | Failure State |
|---|---|---|---|---|---|
| Select category tab | `TagStripView` | `viewModel.selectCategory(category)` | `selectedCategory`, command fetch | command cards show | category missing falls back |
| Click import with category | import button | `ImportPanelWindowController.shared.present(...)` | none | independent import window opens | none |
| Click import without category | import button | `showingImportTargetAlert = true` | none | alert opens | target missing |
| Paste JSON and import | `ImportPanelView` | decode `[ImportCommand]` and `createCommand` | `Command` rows in Core Data | success card and refreshed category | invalid JSON failure |

<<<<<<<<<<<<<<<<<<<< 06 State Ownership <<<<<<<<<<<<<<<<<<<<

| State / Data | Authority | Long-Term Fact | Readers / Writers | Notes |
|---|---|---|---|---|
| selected category | `ShelfViewModel.selectedCategory` | no | `ShelfView`, `TagStripView` | Runtime view state |
| category tabs | Core Data `Category` via `CategoryViewModel` | yes | Shelf and main window | Existing model |
| imported commands | Core Data `Command` via `CommandViewModel` | yes | `ImportPanelView`, Shelf cards | Existing write path |
| import window open | `ImportPanelWindowController` | no | `ShelfView`, window controller | Presentation state; must not attach as Shelf sheet |
| target-required alert | `ShelfView` local state | no | `ShelfView` | Guardrail only |

<<<<<<<<<<<<<<<<<<<< 07 Data Flow <<<<<<<<<<<<<<<<<<<<

```text
+------------------+      +------------------+      +------------------+
| User JSON text   | ---> | ImportPanelView  | ---> | CommandViewModel |
+------------------+      +------------------+      +---------+--------+
                                                              |
                                                              v
+------------------+      +------------------+      +------------------+
| Shelf cards      | <--- | fetchCommands    | <--- | Core Data Command|
+------------------+      +------------------+      +------------------+
```

<<<<<<<<<<<<<<<<<<<< 08 Boundary States <<<<<<<<<<<<<<<<<<<<

| State | Condition | Affected Component | User Can Do | Recovery |
|---|---|---|---|---|
| No category selected | Clipboard or favorites tab active | import button | Read alert | Select a category |
| Empty category | Category has no commands | horizontal card lane | Import or add new command | Import creates cards |
| Invalid JSON | Decoder fails | import window | Edit JSON | Retry import |
| Save failure | Core Data save fails | import window / VM error | Keep window open | Retry after error is fixed |

<<<<<<<<<<<<<<<<<<<< 09 Downstream Handoff <<<<<<<<<<<<<<<<<<<<

| Handoff | Target | Reason | Verification |
|---|---|---|---|
| PDOC | `.project/07-agent-loop/15-shelf-command-import.md` | Code change is scoped and ready | xcodebuild + manual Shelf inspection |
| Architecture | `.project/06-architecture/01-shelf-command-import.md` | Keep Core Data and UI boundaries explicit | No direct SQLite writes |
