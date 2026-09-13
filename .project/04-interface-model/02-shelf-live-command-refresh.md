# Shelf Live Command Refresh Interface Model

<<<<<<<<<<<<<<<<<<<< 00 Source and Scope <<<<<<<<<<<<<<<<<<<<

Source feature-flow: `.project/03-feature-flow/02-shelf-live-command-refresh.md`.

This model covers state propagation between `ShelfViewModel`, its child view models, and `ShelfView`. It focuses on command/category/favorites UI freshness after writes.

<<<<<<<<<<<<<<<<<<<< 01 Component Tree <<<<<<<<<<<<<<<<<<<<

```text
ShelfView
  observes ShelfViewModel
    owns CategoryViewModel
      publishes categories
    owns CommandViewModel
      publishes commands / error / copy toast
    owns PagedClipboardViewModel
      publishes clipboard preview items
    publishes favorites / selectedCategory / searchText / showCopyToast
```

<<<<<<<<<<<<<<<<<<<< 02 Component Responsibilities <<<<<<<<<<<<<<<<<<<<

| Component | Responsibility | Not Responsible For |
|---|---|---|
| `CommandFormView` | Calls create/update command and dismisses | Refreshing every Shelf surface |
| `CommandViewModel` | Saves commands and refreshes its own `commands` array | Notifying `ShelfView` directly |
| `ShelfViewModel` | Owns child view models and should bridge their visible changes to Shelf | Duplicating command arrays |
| `ShelfView` | Renders card lanes from `viewModel.commandVM.commands`, `favorites`, and clipboard previews | Polling Core Data |

<<<<<<<<<<<<<<<<<<<< 03 State Matrix <<<<<<<<<<<<<<<<<<<<

| State | Authority | Trigger | UI Consumer | Required Propagation |
|---|---|---|---|---|
| `commandVM.commands` | `CommandViewModel` | create/edit/delete/import/fetch | category lane | child `objectWillChange` -> parent `objectWillChange` |
| `categoryVM.categories` | `CategoryViewModel` | create/rename/delete category | tag strip and move menus | child `objectWillChange` -> parent `objectWillChange` |
| `pagedClipboardVM.previewItems` | `PagedClipboardViewModel` | clipboard capture / delete / pagination | clipboard lane | child `objectWillChange` -> parent `objectWillChange` |
| `favorites` | `ShelfViewModel` | fetch/toggle/move | favorites lane | existing parent `@Published` |

<<<<<<<<<<<<<<<<<<<< 04 Event Flow <<<<<<<<<<<<<<<<<<<<

| User Action | Event | Data Changed | UI Feedback |
|---|---|---|---|
| Save new command | `CommandViewModel.createCommand` | `Command` row + `commands` array | Shelf category lane re-renders |
| Save edit | `CommandViewModel.updateCommand` | existing `Command` fields + `commands` array | card text updates |
| Import JSON | `ImportPanelView.performImport` -> repeated `createCommand` | multiple `Command` rows | new cards appear |
| Delete command | `CommandViewModel.deleteCommand` | command removed + `commands` array | card disappears |

<<<<<<<<<<<<<<<<<<<< 05 Boundary States <<<<<<<<<<<<<<<<<<<<

| State | Handling |
|---|---|
| Current tab is category | command changes should be visible immediately |
| Current tab is favorites | favorite changes should still rely on `favorites` refresh |
| Current tab is clipboard | command list changes do not affect clipboard cards, but category/tag updates should still render |
| Child emits frequently | bridge should only forward objectWillChange, not duplicate fetches |

<<<<<<<<<<<<<<<<<<<< 06 Downstream Handoff <<<<<<<<<<<<<<<<<<<<

| Handoff | Target | Reason |
|---|---|---|
| Architecture | `.project/06-architecture/02-shelf-live-command-refresh.md` | Define Combine bridge and Core Data boundaries |
| PDOC | `.project/07-agent-loop/16-shelf-live-command-refresh.md` | Scoped implementation |
