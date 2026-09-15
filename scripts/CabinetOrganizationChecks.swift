import AppKit
import CoreData
import SwiftUI
@testable import cheatsheet

@main struct CabinetOrganizationChecks {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        try await checkSidebar()
    }

    @MainActor static func checkSidebar() async throws {
        precondition(CabinetSidebarWidth.visible(900, in: 1600) == 320)
        precondition(CabinetSidebarWidth.visible(100, in: 1600) == 160)
        precondition(CabinetSidebarWidth.visible(.nan, in: 1600) == 188)
        let suite = "cabinet-sidebar-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(280.0, forKey: CabinetSidebarWidth.preferenceKey)
        let host = NSHostingView(rootView: CabinetSplitView {
            Color.gray
        } content: {
            Color.black
        }.defaultAppStorage(defaults))
        host.frame = NSRect(x: 0, y: 0, width: 760, height: 560)
        func settle() async throws {
            host.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(30))
            host.layoutSubtreeIfNeeded()
        }
        func divider(in view: NSView) -> CabinetSidebarDivider? {
            (view as? CabinetSidebarDivider) ?? view.subviews.lazy.compactMap { divider(in: $0) }.first
        }
        func mouse(_ type: NSEvent.EventType, _ x: CGFloat) -> NSEvent {
            NSEvent.mouseEvent(with: type, location: NSPoint(x: x, y: 40), modifierFlags: [],
                timestamp: 0, windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)!
        }
        try await settle()
        let handle = divider(in: host)!
        func width() -> Double { (handle.accessibilityValue() as! NSNumber).doubleValue }
        precondition(width() == 228)
        precondition(defaults.double(forKey: CabinetSidebarWidth.preferenceKey) == 280)
        handle.mouseDown(with: mouse(.leftMouseDown, 228))
        handle.mouseUp(with: mouse(.leftMouseUp, 228))
        precondition(defaults.double(forKey: CabinetSidebarWidth.preferenceKey) == 280)
        host.frame.size.width = 1140
        try await settle()
        precondition(width() == 280, "Widening must restore the preference, not the temporary clamp")
        handle.mouseDown(with: mouse(.leftMouseDown, 280))
        handle.mouseDragged(with: mouse(.leftMouseDragged, 300))
        try await settle()
        precondition(width() == 300)
        precondition(defaults.double(forKey: CabinetSidebarWidth.preferenceKey) == 280, "Persist only at drag end")
        handle.mouseDragged(with: mouse(.leftMouseDragged, 600))
        handle.mouseUp(with: mouse(.leftMouseUp, 600))
        try await settle()
        precondition(width() == 320 && defaults.double(forKey: CabinetSidebarWidth.preferenceKey) == 320)
        precondition(handle.accessibilityPerformDecrement())
        try await settle()
        precondition(width() == 310 && UserDefaults(suiteName: suite)!.double(forKey: CabinetSidebarWidth.preferenceKey) == 310)
        handle.mouseDown(with: mouse(.leftMouseDown, 310))
        handle.mouseDragged(with: mouse(.leftMouseDragged, -100))
        handle.mouseUp(with: mouse(.leftMouseUp, -100))
        try await settle()
        precondition(width() == 160)
        print("PASS: native sidebar drag, min/max, adaptive clamp, no-op click, end-only persistence, resize restoration and accessibility step")
    }
}
