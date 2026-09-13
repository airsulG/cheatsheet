# Shelf Live Command Refresh Architecture

<<<<<<<<<<<<<<<<<<<< 00 Technical Boundary <<<<<<<<<<<<<<<<<<<<

This fix is a SwiftUI observation bridge. It must not change Core Data schema, command persistence, editor window ownership, or command sorting semantics.

<<<<<<<<<<<<<<<<<<<< 01 Current Problem <<<<<<<<<<<<<<<<<<<<

`ShelfView` observes `ShelfViewModel`, but it renders values owned by child `ObservableObject`s such as `commandVM.commands` and `categoryVM.categories`. SwiftUI does not automatically re-render a view observing a parent object when a nested child object publishes changes, unless the parent forwards that change.

`CommandViewModel.createCommand` and `updateCommand` save data and refresh `commandVM.commands`, but Shelf can remain visually stale until another parent-level state change occurs.

<<<<<<<<<<<<<<<<<<<< 02 Recommended Implementation <<<<<<<<<<<<<<<<<<<<

Implement a child-observable bridge in `ShelfViewModel`:

1. Import `Combine`.
2. Add a private `Set<AnyCancellable>`.
3. In `init`, subscribe to relevant child `objectWillChange` publishers:
   - `categoryVM.objectWillChange`
   - `commandVM.objectWillChange`
   - `pagedClipboardVM.objectWillChange`
4. Forward each child emission to `self.objectWillChange.send()` on the main queue.
5. Keep existing `contextDidSave` guard against self-saves. Do not reintroduce manual Core Data merging.

<<<<<<<<<<<<<<<<<<<< 03 Integration Contract <<<<<<<<<<<<<<<<<<<<

| Contract Item | Canonical Value |
|---|---|
| Parent observed by Shelf | `ShelfViewModel` |
| Child state source | `CategoryViewModel`, `CommandViewModel`, `PagedClipboardViewModel` |
| Bridge mechanism | Combine subscriptions retained by `ShelfViewModel` |
| Persistence path | Existing view models and Core Data context |
| Not allowed | Direct SQLite writes, manual `mergeChanges`, broad refactor |

<<<<<<<<<<<<<<<<<<<< 04 Risks <<<<<<<<<<<<<<<<<<<<

| Risk | Handling |
|---|---|
| Infinite update loop | Forward only `objectWillChange`; do not call fetch in the bridge |
| Actor/thread warning | Deliver forwarded events on main queue |
| Over-refresh | Acceptable for compact Shelf; no extra persistence or fetch work |
| Existing dirty files | Edit only `ShelfViewModel.swift` unless compile requires otherwise |

<<<<<<<<<<<<<<<<<<<< 05 Verification <<<<<<<<<<<<<<<<<<<<

Run:

```bash
git diff --check -- cheatsheet/Models/ViewModels/ShelfViewModel.swift
xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -destination 'platform=macOS' build
```

Manual QA:
- Open Shelf and select a category.
- Create a new command from the add-command card.
- Confirm it appears without switching tabs.
- Edit an existing command and confirm text updates in place.
- Import JSON and confirm imported cards appear after the sheet closes.
