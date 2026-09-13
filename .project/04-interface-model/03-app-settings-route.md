# App Settings Route Interface Model

<<<<<<<<<<<<<<<<<<<< 00 Interface Goal <<<<<<<<<<<<<<<<<<<<

Provide one app-level Settings window that organizes existing maintenance views into sections. The interface should make backup and cleanup discoverable without tying either action to a specific Shelf tab.

<<<<<<<<<<<<<<<<<<<< 01 Component Model <<<<<<<<<<<<<<<<<<<<

```text
ShelfView
  toolbar
    SettingsButton
      -> AppSettingsWindowController.present(context, clipboardViewModel)

AppSettingsWindowController
  NSWindow
    NSHostingController
      AppSettingsView
        SettingsSidebar
          Clipboard
          Backup
        SettingsContent
          ClipboardSettingsView
          BackupSettingsView
```

<<<<<<<<<<<<<<<<<<<< 02 State Model <<<<<<<<<<<<<<<<<<<<

| State | Owner | Meaning |
|---|---|---|
| `selectedSection` | `AppSettingsView` | Current Settings section |
| `window` | `AppSettingsWindowController` | Single live settings window |
| Clipboard stats and cleanup state | `ClipboardSettingsView` | Existing clipboard settings behavior |
| Backup folder, frequency, import/export messages | `BackupSettingsView` | Existing backup settings behavior |

Initial section:
- `Clipboard` is acceptable as the default because it is currently the only settings entry tied to a Shelf tab.
- If later the caller wants deep links, `present(..., initialSection:)` can be added without changing section content.

<<<<<<<<<<<<<<<<<<<< 03 Event Contract <<<<<<<<<<<<<<<<<<<<

| User Action | Event | Result |
|---|---|---|
| Click Shelf Settings | `present(context:viewModel:)` | Focus existing Settings window or create one |
| Select Clipboard | `selectedSection = .clipboard` | Shows clipboard retention, stats, and cleanup |
| Select Backup | `selectedSection = .backup` | Shows backup folder, export, and import |
| Click Done | `dismiss()` | Closes Settings window through hosting dismissal |

<<<<<<<<<<<<<<<<<<<< 04 Layout Contract <<<<<<<<<<<<<<<<<<<<

- Use one titled, closable, resizable `NSWindow`.
- Window should be centered like existing backup and clipboard windows.
- Keep the window independent from the bottom Shelf `NSPanel`.
- Prefer a two-column settings layout over tabs because the settings surface is expected to grow.
- Avoid nesting cards inside cards; reuse existing `Form` sections.
