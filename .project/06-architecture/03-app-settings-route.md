# App Settings Route Architecture

<<<<<<<<<<<<<<<<<<<< 00 Architecture Goal <<<<<<<<<<<<<<<<<<<<

Replace two separate settings window routes with one canonical Settings window route while preserving existing backup and clipboard business logic.

<<<<<<<<<<<<<<<<<<<< 01 Current State <<<<<<<<<<<<<<<<<<<<

| Current File | Role |
|---|---|
| `cheatsheet/Utils/BackupWindowController.swift` | Opens independent backup window |
| `cheatsheet/Utils/ClipboardSettingsWindowController.swift` | Opens independent clipboard settings window |
| `cheatsheet/Views/BackupSettingsView.swift` | Backup UI and backup service calls |
| `cheatsheet/Views/ClipboardSettingsView.swift` | Clipboard retention, stats, and cleanup UI |
| `cheatsheet/Views/Shelf/ShelfView.swift` | Shows separate backup and clipboard settings toolbar entries |

<<<<<<<<<<<<<<<<<<<< 02 Target State <<<<<<<<<<<<<<<<<<<<

| Target File | Role |
|---|---|
| `cheatsheet/Utils/AppSettingsWindowController.swift` | Single independent settings window controller |
| `cheatsheet/Views/AppSettingsView.swift` | Section navigation and content host |
| `BackupSettingsView` | Reused inside Settings without changing backup logic |
| `ClipboardSettingsView` | Reused inside Settings without changing cleanup logic |
| `ShelfView` | Replaces separate backup/clipboard settings buttons with one Settings button |

<<<<<<<<<<<<<<<<<<<< 03 Integration Contract <<<<<<<<<<<<<<<<<<<<

```text
ShelfView
  -> AppSettingsWindowController.shared.present(
       context: viewModel.viewContext,
       clipboardViewModel: viewModel.pagedClipboardVM
     )
  -> AppSettingsView(context, clipboardViewModel)
       -> ClipboardSettingsView(viewModel)
       -> BackupSettingsView(context)
```

Rules:
- Do not edit Core Data model files.
- Do not change `BackupService`, `BackupSettings`, or `ClipboardSettings` behavior unless compilation forces a narrow access fix.
- Do not present Settings with SwiftUI `.sheet` from Shelf.
- Keep existing destructive confirmation alerts.
- Keep backup import strategy as append-only.

<<<<<<<<<<<<<<<<<<<< 04 Verification Plan <<<<<<<<<<<<<<<<<<<<

Commands:
- `git diff --check -- cheatsheet/Views/Shelf/ShelfView.swift cheatsheet/Views/AppSettingsView.swift cheatsheet/Utils/AppSettingsWindowController.swift`
- `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -destination 'platform=macOS' build`

Manual acceptance:
- Click Settings from Shelf.
- Confirm a single centered independent window opens.
- Confirm Clipboard and Backup sections both work.
- Confirm Shelf is not moved or resized by Settings.
