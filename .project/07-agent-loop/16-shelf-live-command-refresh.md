# 16 Shelf Live Command Refresh

<<<<<<<<<<<<<<<<<<<< 00 Task Progress <<<<<<<<<<<<<<<<<<<<

Current PDOC round:
- [x] Plan: bug chain, feature-flow, interface model, architecture, and execution scope fixed.
- [x] Do: scoped execution subagent implemented Shelf child ViewModel observation bridge.
- [x] Observation: build and diff checks passed in subagent and main session.
- [>] Correct: ready for Karl manual UI acceptance.

Status: awaiting_user_acceptance
Owner: Product Development Domain Agent
Execution mode: interactive

<<<<<<<<<<<<<<<<<<<< 01A Objective Decomposition <<<<<<<<<<<<<<<<<<<<

| Dimension | Target |
|---|---|
| Goal object | Bottom Shelf current list refresh after command writes |
| Current state | Saved command changes may not appear until tab/category switching |
| Target state | Shelf re-renders immediately when child view models publish visible state changes |
| Exclusions | No Core Data schema change, no direct SQLite write, no manual Core Data merge, no command editor redesign |
| Delivery shape | SwiftUI observation bridge + build verification |

<<<<<<<<<<<<<<<<<<<< 01 Context Authority <<<<<<<<<<<<<<<<<<<<

Must read:
- `AGENTS.md`
- `.project/01-product/PRODUCT.md`
- `.project/03-feature-flow/02-shelf-live-command-refresh.md`
- `.project/04-interface-model/02-shelf-live-command-refresh.md`
- `.project/06-architecture/02-shelf-live-command-refresh.md`

Relevant code:
- `cheatsheet/Models/ViewModels/ShelfViewModel.swift`
- `cheatsheet/Models/ViewModels/CommandViewModel.swift`
- `cheatsheet/Models/ViewModels/CategoryViewModel.swift`
- `cheatsheet/Models/ViewModels/PagedClipboardViewModel.swift`
- `cheatsheet/Views/Shelf/ShelfView.swift`
- `cheatsheet/Views/CommandFormView.swift`

<<<<<<<<<<<<<<<<<<<< 02 Current / Target Gap <<<<<<<<<<<<<<<<<<<<

| Current Evidence | Gap | Target |
|---|---|---|
| `CommandFormView.saveCommand` calls `CommandViewModel.createCommand/updateCommand` | Save path works | Keep save path |
| `CommandViewModel` refreshes its own `commands` array | Shelf observes parent, not child | Parent forwards child objectWillChange |
| `ShelfViewModel.contextDidSave` ignores self-saves to avoid Core Data merge bugs | Self-save notification will not refresh Shelf | Observation bridge handles same-context UI changes |

<<<<<<<<<<<<<<<<<<<< 03 State Chain <<<<<<<<<<<<<<<<<<<<

```text
CommandFormView.saveCommand
  -> CommandViewModel.create/update
  -> Core Data save + commandVM.commands update
  -> commandVM.objectWillChange
  -> ShelfViewModel.objectWillChange
  -> ShelfView renders updated lane
```

<<<<<<<<<<<<<<<<<<<< 04 Task Queue <<<<<<<<<<<<<<<<<<<<

- [x] Add `Combine` import to `ShelfViewModel.swift`.
- [x] Add cancellable storage to `ShelfViewModel`.
- [x] Subscribe to child view model `objectWillChange` publishers in init.
- [x] Forward child changes through `ShelfViewModel.objectWillChange.send()`.
- [x] Do not call fetch or Core Data merge in the bridge.
- [x] Run `git diff --check -- cheatsheet/Models/ViewModels/ShelfViewModel.swift`.
- [x] Run `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -destination 'platform=macOS' build`.

<<<<<<<<<<<<<<<<<<<< 05 Allowed Files <<<<<<<<<<<<<<<<<<<<

Allowed to edit:
- `cheatsheet/Models/ViewModels/ShelfViewModel.swift`

Read-only unless absolutely required:
- `cheatsheet/Views/Shelf/ShelfView.swift`
- `cheatsheet/Models/ViewModels/CommandViewModel.swift`
- `cheatsheet/Models/ViewModels/CategoryViewModel.swift`
- `cheatsheet/Models/ViewModels/PagedClipboardViewModel.swift`
- `cheatsheet/Views/CommandFormView.swift`

Must not edit:
- Core Data model.
- Backup service.
- Legacy `.project/agent-loop/`.
- Git metadata or PRD files.

<<<<<<<<<<<<<<<<<<<< 06 Integration Contract <<<<<<<<<<<<<<<<<<<<

| Contract Item | Value |
|---|---|
| Bridge owner | `ShelfViewModel` |
| Subscription storage | private `Set<AnyCancellable>` |
| Child publishers | `categoryVM.objectWillChange`, `commandVM.objectWillChange`, `pagedClipboardVM.objectWillChange` |
| Bridge action | `self?.objectWillChange.send()` on main queue |
| Forbidden side effect | No fetch, save, merge, or model mutation inside bridge |

<<<<<<<<<<<<<<<<<<<< 07 Stop Conditions <<<<<<<<<<<<<<<<<<<<

Stop and report if:
- Swift concurrency isolation prevents a safe Combine bridge.
- Fix requires broad changes to command editor or Core Data persistence.
- Build failure points to unrelated existing dirty changes.
- There is a conflict with existing user edits in `ShelfViewModel.swift`.

<<<<<<<<<<<<<<<<<<<< 08 Verification Record <<<<<<<<<<<<<<<<<<<<

Execution subagent:
- agent: `019ee62b-ef1f-7740-9914-1ec7b352dcfa`
- lifecycle_decision: `close_after_review`
- changed_files:
  - `cheatsheet/Models/ViewModels/ShelfViewModel.swift`
- implementation:
  - Added `Combine`.
  - Added private `Set<AnyCancellable>` storage.
  - Subscribed to `categoryVM.objectWillChange`, `commandVM.objectWillChange`, and `pagedClipboardVM.objectWillChange`.
  - Forwarded child emissions to `ShelfViewModel.objectWillChange.send()` on the main queue.
  - Did not add fetch, save, merge, or Core Data mutation inside the bridge.

Subagent verification:
- `git diff --check -- cheatsheet/Models/ViewModels/ShelfViewModel.swift`: passed.
- `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -destination 'platform=macOS' build`: passed, `BUILD SUCCEEDED`.

Main-session verification:
- `git diff --check -- cheatsheet/Models/ViewModels/ShelfViewModel.swift .project/07-agent-loop/16-shelf-live-command-refresh.md .project/03-feature-flow/02-shelf-live-command-refresh.md .project/04-interface-model/02-shelf-live-command-refresh.md .project/06-architecture/02-shelf-live-command-refresh.md`: passed.
- `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -destination 'platform=macOS' build`: passed, `** BUILD SUCCEEDED **`.

Manual acceptance for Karl:
- Open Shelf and select a normal category tab.
- Create a new command from the add-command card.
- Confirm the new card appears without switching tabs.
- Edit an existing command and confirm the card updates without switching tabs.
- Import valid JSON and confirm imported cards appear after the panel completes.
