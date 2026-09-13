# Shelf Command Import Architecture

<<<<<<<<<<<<<<<<<<<< 00 Technical Boundary <<<<<<<<<<<<<<<<<<<<

The feature should expose an existing import path from the Shelf UI. It should not add a new persistence model, direct SQLite writer, background file watcher, or backup archive parser.

<<<<<<<<<<<<<<<<<<<< 01 Existing Code Contracts <<<<<<<<<<<<<<<<<<<<

| Contract | File | Rule |
|---|---|---|
| Shelf UI | `cheatsheet/Views/Shelf/ShelfView.swift` | Header actions are toolbar buttons plus target-required alert |
| Import window | `cheatsheet/Utils/ImportPanelWindowController.swift` | Opens an independent centered `NSWindow` so the bottom Shelf is not pushed |
| Import content | `cheatsheet/Views/ImportPanelView.swift` | Requires `Category` and `CommandViewModel`; accepts optional close callback |
| Command writes | `cheatsheet/Models/ViewModels/CommandViewModel.swift` | `createCommand` writes `Command` rows through Core Data context |
| Data model | `cheatsheet.xcdatamodeld` | `Command` belongs to optional `Category`; import should assign category |

<<<<<<<<<<<<<<<<<<<< 02 Recommended Implementation <<<<<<<<<<<<<<<<<<<<

1. Add Shelf-local missing-target alert state:
   - `showingImportTargetAlert: Bool`
2. Add a compact toolbar import button near settings/search.
3. If `viewModel.selectedCategory` exists, present `ImportPanelView` through `ImportPanelWindowController.shared.present(category:commandViewModel:)`.
4. If no category is selected, show an alert explaining that import needs a category target.
5. Keep the import UI independent from the bottom Shelf `NSPanel`; do not use SwiftUI `.sheet` from Shelf for this route.

<<<<<<<<<<<<<<<<<<<< 03 Integration Contract <<<<<<<<<<<<<<<<<<<<

| Contract Item | Canonical Value |
|---|---|
| User target | `viewModel.selectedCategory` |
| Import UI | `ImportPanelView` |
| Presentation route | `ImportPanelWindowController` independent `NSWindow` |
| Import payload | `[ImportCommand]` JSON with `name` and `prompt` |
| Write path | `CommandViewModel.createCommand(name:content:category:)` |
| Refresh path | Existing `CommandViewModel.fetchCommands(for:)` inside `createCommand` |
| Missing target feedback | Shelf-local alert; no command write |

<<<<<<<<<<<<<<<<<<<< 04 Risks <<<<<<<<<<<<<<<<<<<<

| Risk | Handling |
|---|---|
| User imports while on clipboard/favorites | Guard with target-required alert |
| Toolbar overcrowding | Use SF Symbol icon and `.help`, no text label |
| Bottom Shelf is pushed upward by attached sheet | Use independent `NSWindow`, not `.sheet` from `ShelfView` |
| Existing dirty code in `CommandViewModel` | Do not modify it for this task |
| Core Data concurrency | Keep writes on current main view context via existing view model |

<<<<<<<<<<<<<<<<<<<< 05 Verification <<<<<<<<<<<<<<<<<<<<

Run:

```bash
xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -destination 'platform=macOS' build
```

Manual QA:
- Open Shelf.
- Select a category tab.
- Click import icon.
- Confirm the import window is centered and the bottom Shelf panel is not pushed or resized.
- Paste a valid JSON array and import.
- Confirm command cards appear in the selected category.
- Switch to clipboard/favorites and confirm import shows a target-required alert.
