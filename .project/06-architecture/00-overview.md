# Architecture Overview

| Architecture Note | File | Status |
|---|---|---|
| Shelf command import | `01-shelf-command-import.md` | ready_for_execution |
| Shelf live command refresh | `02-shelf-live-command-refresh.md` | ready_for_execution |
| App settings route | `03-app-settings-route.md` | ready_for_execution |

Stable project facts:
- macOS app built with SwiftUI + AppKit + Core Data.
- `viewContext` is main queue.
- Background contexts are used by clipboard monitoring and backup service.
- UI code must not directly write the Core Data backing SQLite store.
