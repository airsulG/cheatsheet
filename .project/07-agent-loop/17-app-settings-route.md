# 17 App Settings Route

<<<<<<<<<<<<<<<<<<<< 00 Task Progress <<<<<<<<<<<<<<<<<<<<

Current PDOC round:
- [x] Plan: product route, feature flow, interface model, architecture, and code scope fixed.
- [x] Do: scoped execution subagent implemented one Settings window route.
- [x] Observation: build and diff checks passed in subagent and main session.
- [>] Correct: ready for Karl manual UI acceptance.

Status: awaiting_user_acceptance
Owner: Product Development Domain Agent
Execution mode: interactive

<<<<<<<<<<<<<<<<<<<< 01A Objective Decomposition <<<<<<<<<<<<<<<<<<<<

| Dimension | Target |
|---|---|
| Goal object | App-level settings route |
| Current state | Backup and clipboard cleanup open as two separate windows from Shelf |
| Target state | Shelf has one Settings entry; one independent Settings window contains Clipboard and Backup sections |
| Exclusions | No Core Data schema change, no backup format change, no clipboard cleanup strategy change, no SwiftUI sheet from Shelf |
| Delivery shape | New settings window controller + settings host view + Shelf toolbar route update |

<<<<<<<<<<<<<<<<<<<< 01 Context Authority <<<<<<<<<<<<<<<<<<<<

Must read:
- `AGENTS.md`
- `.project/01-product/PRODUCT.md`
- `.project/03-feature-flow/03-app-settings-route.md`
- `.project/04-interface-model/03-app-settings-route.md`
- `.project/06-architecture/03-app-settings-route.md`

Relevant code:
- `cheatsheet/Views/Shelf/ShelfView.swift`
- `cheatsheet/Views/BackupSettingsView.swift`
- `cheatsheet/Views/ClipboardSettingsView.swift`
- `cheatsheet/Utils/BackupWindowController.swift`
- `cheatsheet/Utils/ClipboardSettingsWindowController.swift`

<<<<<<<<<<<<<<<<<<<< 02 Current / Target Gap <<<<<<<<<<<<<<<<<<<<

| Current Evidence | Gap | Target |
|---|---|---|
| Shelf backup button calls `BackupWindowController.shared.present(context:)` | Backup is a separate route | Settings button opens one shared Settings route |
| Shelf clipboard settings button only appears on clipboard tab | Global cleanup depends on current tab visibility | Settings is always visible from Shelf |
| Two window controllers duplicate independent window setup | Presentation logic is split | One `AppSettingsWindowController` owns the route |
| Backup and clipboard views already own their business actions | No need to rewrite data behavior | Reuse existing settings views inside `AppSettingsView` |

<<<<<<<<<<<<<<<<<<<< 03 Task Queue <<<<<<<<<<<<<<<<<<<<

- [x] Add `cheatsheet/Views/AppSettingsView.swift`.
- [x] Add `cheatsheet/Utils/AppSettingsWindowController.swift`.
- [x] Replace Shelf backup and clipboard settings toolbar entries with one Settings button.
- [x] Route the Settings button to `AppSettingsWindowController.shared.present(context:clipboardViewModel:)`.
- [x] Keep JSON command import as a separate toolbar action.
- [x] Do not remove old window controller files unless they become unused and deletion is clearly safe.
- [x] Run `git diff --check` on touched files.
- [x] Run macOS build.

<<<<<<<<<<<<<<<<<<<< 04 Allowed Files <<<<<<<<<<<<<<<<<<<<

Allowed to edit:
- `cheatsheet/Views/Shelf/ShelfView.swift`
- `cheatsheet/Views/AppSettingsView.swift`
- `cheatsheet/Utils/AppSettingsWindowController.swift`
- `cheatsheet/Views/BackupSettingsView.swift` only if embedding requires a tiny layout adjustment.
- `cheatsheet/Views/ClipboardSettingsView.swift` only if embedding requires a tiny layout adjustment.

Read-only unless build requires otherwise:
- `cheatsheet/Utils/BackupWindowController.swift`
- `cheatsheet/Utils/ClipboardSettingsWindowController.swift`
- `cheatsheet/Services/BackupService.swift`
- `cheatsheet/Utils/BackupSettings.swift`
- `cheatsheet/Utils/ClipboardSettings.swift`

Must not edit:
- Core Data model.
- Backup archive schema.
- Legacy `.project/agent-loop/`.
- Git metadata or runtime backup JSON files.

<<<<<<<<<<<<<<<<<<<< 05 Integration Contract <<<<<<<<<<<<<<<<<<<<

| Contract Item | Value |
|---|---|
| Canonical settings route | `AppSettingsWindowController` |
| Canonical settings host | `AppSettingsView` |
| Shelf toolbar action | One Settings button |
| Presentation style | Independent centered `NSWindow`, not `.sheet` |
| Clipboard section | Existing `ClipboardSettingsView(viewModel:)` |
| Backup section | Existing `BackupSettingsView(context:)` |

<<<<<<<<<<<<<<<<<<<< 06 Stop Conditions <<<<<<<<<<<<<<<<<<<<

Stop and report if:
- Embedding existing views requires rewriting backup or cleanup business logic.
- Build reveals old window controllers are referenced from another active route and deleting them would be unsafe.
- macOS Settings scene conflicts with the intended independent Shelf-launched settings window.
- Implementation would require destructive data actions or schema changes.

<<<<<<<<<<<<<<<<<<<< 07 Verification Record <<<<<<<<<<<<<<<<<<<<

Execution subagent:
- agent: `019ee633-7d06-7030-a429-2bfb7549c643`
- lifecycle_decision: `close_after_review`
- changed_files:
  - `cheatsheet/Views/AppSettingsView.swift`
  - `cheatsheet/Utils/AppSettingsWindowController.swift`
  - `cheatsheet/Views/Shelf/ShelfView.swift`
  - `cheatsheet/Views/BackupSettingsView.swift`
  - `cheatsheet/Views/ClipboardSettingsView.swift`
- implementation:
  - Added one Settings host view with Clipboard and Backup sections.
  - Added one independent centered `NSWindow` controller for Settings.
  - Replaced separate Shelf backup and clipboard settings buttons with one always-visible Settings button.
  - Reused existing backup and clipboard settings views through a header-hidden embed mode.
  - Did not change Core Data schema, backup archive schema, `BackupService`, or cleanup behavior.

Subagent verification:
- `git diff --check -- cheatsheet/Views/Shelf/ShelfView.swift cheatsheet/Views/AppSettingsView.swift cheatsheet/Utils/AppSettingsWindowController.swift`: passed.
- `git diff --check` for all five touched Swift files: passed.
- `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -destination 'platform=macOS' build`: passed, `BUILD SUCCEEDED`.

Main-session verification:
- `git diff --check -- cheatsheet/Views/Shelf/ShelfView.swift cheatsheet/Views/AppSettingsView.swift cheatsheet/Utils/AppSettingsWindowController.swift cheatsheet/Views/BackupSettingsView.swift cheatsheet/Views/ClipboardSettingsView.swift .project/07-agent-loop/17-app-settings-route.md .project/03-feature-flow/03-app-settings-route.md .project/04-interface-model/03-app-settings-route.md .project/06-architecture/03-app-settings-route.md`: passed.
- `xcodebuild -project cheatsheet.xcodeproj -scheme cheatsheet -destination 'platform=macOS' build`: passed, `** BUILD SUCCEEDED **`.

Manual acceptance for Karl:
- Open Shelf and confirm the toolbar has one Settings button instead of separate Backup and Clipboard Settings buttons.
- Click Settings and confirm one centered independent window opens without pushing the Shelf panel.
- Switch between Clipboard and Backup sections.
- Confirm clipboard cleanup still shows destructive confirmation before deleting records.
- Confirm backup import still shows append-import confirmation before importing archive content.
