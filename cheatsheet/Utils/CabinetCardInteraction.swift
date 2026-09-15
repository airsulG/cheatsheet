import AppKit
import CoreData

/// 首击立即打开面板；次击即使落在面板覆盖范围内，仍复制首击的卡片。
@MainActor
final class CabinetCardInteraction {
    private let model: CabinetViewModel
    private var lastClick: (id: NSManagedObjectID, point: NSPoint, time: TimeInterval,
                            wasOpen: Bool, location: CabinetLocation, query: String)?
    private var consumeMouseUp = false

    init(model: CabinetViewModel) { self.model = model }

    func activate(_ id: NSManagedObjectID, event: NSEvent?) {
        if let event, event.type == .leftMouseUp || event.type == .leftMouseDown {
            lastClick = (id, event.locationInWindow, event.timestamp, model.isDetailPresented, model.location, model.query)
        } else { lastClick = nil }
        model.openDetail(id, animated: event != nil)
    }

    func handle(_ event: NSEvent) -> Bool {
        if event.type == .leftMouseUp && consumeMouseUp {
            consumeMouseUp = false
            return true
        }
        guard event.type == .leftMouseDown else { return false }
        consumeMouseUp = false
        guard event.clickCount == 2, let click = lastClick,
              event.timestamp >= click.time, event.timestamp - click.time <= NSEvent.doubleClickInterval,
              abs(event.locationInWindow.x - click.point.x) <= 4,
              abs(event.locationInWindow.y - click.point.y) <= 4,
              model.location == click.location, model.query == click.query,
              model.items.contains(where: { $0.id == click.id }) else { return false }
        lastClick = nil
        consumeMouseUp = true
        if model.select(click.id) {
            model.copy(close: false)
            if !click.wasOpen { model.closeDetail() }
        }
        return true
    }
}
