# 15 Shelf Command Import

<<<<<<<<<<<<<<<<<<<< 00 Task Progress <<<<<<<<<<<<<<<<<<<<

Current PDOC round:
- [x] Plan: product, feature-flow, interface model, architecture, and execution scope fixed.
- [x] Do: scoped execution subagent implemented Shelf import entry.
- [x] Observation: build and diff checks passed in subagent and main session.
- [>] Correct: ready for Karl manual UI acceptance.

Status: awaiting_user_acceptance
Owner: Product Development Domain Agent
Execution mode: interactive

<<<<<<<<<<<<<<<<<<<< 01A Objective Decomposition <<<<<<<<<<<<<<<<<<<<

| Dimension | Target |
|---|---|
| Goal object | Bottom Shelf panel command import entry |
| Current state | Bulk import exists in main/legacy command surfaces, but not in Shelf |
| Target state | Shelf exposes command JSON import for selected category |
| Exclusions | No direct SQLite write, no folder watcher, no multi-category package import, no Core Data schema change |
| Delivery shape | SwiftUI UI change + build verification |

<<<<<<<<<<<<<<<<<<<< 01 Context Authority <<<<<<<<<<<<<<<<<<<<

Must read:
- `AGENTS.md`
- `.project/01-product/PRODUCT.md`
- `.project/03-feature-flow/01-shelf-command-import.md`
- `.project/04-interface-model/01-shelf-command-import.md`
- `.project/06-architecture/01-shelf-command-import.md`

Relevant code:
- `cheatsheet/Views/Shelf/ShelfView.swift`
- `cheatsheet/Views/ImportPanelView.swift`
- `cheatsheet/Models/ViewModels/ShelfViewModel.swift`
- `cheatsheet/Models/ViewModels/CommandViewModel.swift`

<<<<<<<<<<<<<<<<<<<< 02 Current / Target Gap <<<<<<<<<<<<<<<<<<<<

| Current Evidence | Gap | Target |
|---|---|---|
| `ShelfView` toolbar has sort, backup, settings, search | No import action in actual bottom panel | Add import button |
| `ImportPanelView` already accepts `Category` + `CommandViewModel` | Existing import panel is not presented from Shelf without moving the bottom panel | Present import through an independent window |
| Shelf can be on clipboard/favorites/category tabs | Import needs a category target | Guard no-category state with alert |

<<<<<<<<<<<<<<<<<<<< 03 Memory and Decisions <<<<<<<<<<<<<<<<<<<<

Decision:
- Use existing `ImportPanelView` and `[ImportCommand]` JSON contract.
- Write only through `CommandViewModel` / Core Data context.
- Use an independent import window instead of a SwiftUI sheet from Shelf, because attached sheets push the bottom `NSPanel` upward.

Dirty worktree note:
- There are pre-existing dirty/untracked files outside this task.
- Do not revert, reset, checkout, delete, or overwrite unrelated changes.

<<<<<<<<<<<<<<<<<<<< 04 Task Queue <<<<<<<<<<<<<<<<<<<<

- [x] Add Shelf state for missing-target alert.
- [x] Add toolbar import icon near backup/search.
- [x] Present `ImportPanelView` in an independent window when `selectedCategory` is non-nil.
- [x] Show target-required alert on clipboard/favorites.
- [x] Add `ImportPanelWindowController`.
- [x] Add optional close callback to `ImportPanelView`.
- [x] Run `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -destination 'platform=macOS' build`.
- [x] Report changed files and verification.

<<<<<<<<<<<<<<<<<<<< 05 Allowed Files <<<<<<<<<<<<<<<<<<<<

Allowed to edit:
- `cheatsheet/Views/Shelf/ShelfView.swift`
- `cheatsheet/Utils/ImportPanelWindowController.swift`
- `cheatsheet/Views/ImportPanelView.swift`

Read-only unless absolutely required:
- `cheatsheet/Views/ImportPanelView.swift`
- `cheatsheet/Models/ViewModels/ShelfViewModel.swift`
- `cheatsheet/Models/ViewModels/CommandViewModel.swift`

Must not edit:
- Core Data model.
- Backup service.
- Clipboard capture path.
- Legacy `.project/agent-loop/`.
- Git metadata or PRD files.

<<<<<<<<<<<<<<<<<<<< 06 Integration Contract <<<<<<<<<<<<<<<<<<<<

| Contract Item | Value |
|---|---|
| Presentation state | `ImportPanelWindowController` |
| Target source | `viewModel.selectedCategory` |
| Window | `ImportPanelView(category: category, commandViewModel: viewModel.commandVM, onClose: ...)` in independent `NSWindow` |
| Missing target | Alert text: `请选择一个分类后再导入命令。` |
| Toolbar icon | SF Symbol, icon-only, with `.help("JSON 批量导入")` |
| Persistence | Existing `CommandViewModel.createCommand` |

<<<<<<<<<<<<<<<<<<<< 07 Stop Conditions <<<<<<<<<<<<<<<<<<<<

Stop and report if:
- `ImportPanelView` cannot be presented from Shelf without changing broad view model ownership.
- Import presentation would require returning to SwiftUI `.sheet` from the bottom Shelf panel.
- The build fails due to unrelated existing dirty changes.
- Fix requires editing Core Data schema or command persistence.
- There is a conflict with existing user edits in `ShelfView.swift`.

<<<<<<<<<<<<<<<<<<<< 08 Verification Record <<<<<<<<<<<<<<<<<<<<

Execution subagent:
- agent: `019ee621-42e6-7693-90c5-3e4ae86c761e`
- lifecycle_decision: `close_after_review`
- changed_files:
  - `cheatsheet/Views/Shelf/ShelfView.swift`
- implementation:
  - Added Shelf-local import sheet state.
  - Added Shelf-local missing-target alert state.
  - Added icon-only `square.and.arrow.down` toolbar button with `JSON 批量导入` help text.
  - Reused `ImportPanelView(category:commandViewModel:)`.
  - Preserved existing JSON import contract and Core Data write path.

Subagent verification:
- `git diff --check -- cheatsheet/Views/Shelf/ShelfView.swift`: passed.
- `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -destination 'platform=macOS' build`: passed, `** BUILD SUCCEEDED **`.

Main-session verification:
- `git diff --check -- cheatsheet/Views/Shelf/ShelfView.swift .project`: passed.
- `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -destination 'platform=macOS' build`: passed, `** BUILD SUCCEEDED **`.

Regression fix:
- Reported issue: bulk import still pushed the bottom Shelf panel upward.
- Root cause: Shelf import still used SwiftUI `.sheet(isPresented:)`, so macOS attached the import UI to the bottom `NSPanel`.
- Changed files:
  - `cheatsheet/Utils/ImportPanelWindowController.swift`
  - `cheatsheet/Views/ImportPanelView.swift`
  - `cheatsheet/Views/Shelf/ShelfView.swift`
- Fix:
  - Added an independent centered import `NSWindow`.
  - Removed Shelf import `.sheet`.
  - Kept target-required alert for clipboard/favorites.
  - Kept existing JSON import contract and `CommandViewModel` write path.
- Verification:
  - `git diff --check -- cheatsheet/Views/Shelf/ShelfView.swift cheatsheet/Views/ImportPanelView.swift cheatsheet/Utils/ImportPanelWindowController.swift`: passed.
  - `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -destination 'platform=macOS' build`: passed, `** BUILD SUCCEEDED **`.

Manual acceptance for Karl:
- Open the bottom Shelf panel.
- Select a normal category tab.
- Click the new import icon near sort / backup / search.
- Confirm the bulk import window opens for that category without pushing or resizing the bottom Shelf panel.
- Paste valid `[{"name":"...","prompt":"..."}]` JSON and import.
- Confirm new command cards appear and copy correctly.
- Switch to clipboard or favorites and confirm import shows `请选择一个分类后再导入命令。`.
