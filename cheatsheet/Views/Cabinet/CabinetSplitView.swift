import AppKit
import SwiftUI

enum CabinetSidebarWidth {
    static let preferenceKey = "cabinetSidebarWidth"
    static let initial: CGFloat = 188
    static let minimum: CGFloat = 160
    static let maximum: CGFloat = 320

    static func limit(in available: CGFloat) -> CGFloat {
        max(minimum, min(maximum, available * 0.3))
    }

    static func visible(_ preferred: CGFloat, in available: CGFloat) -> CGFloat {
        min(limit(in: available), max(minimum, preferred.isFinite ? preferred : initial))
    }
}

/// 拖动只影响视图宽度；窗口临时收窄不会覆盖用户保存的宽度。
struct CabinetSplitView<Sidebar: View, Content: View>: View {
    @AppStorage(CabinetSidebarWidth.preferenceKey) private var preferredWidth = Double(CabinetSidebarWidth.initial)
    @State private var dragOrigin: CGFloat?
    @State private var dragWidth: CGFloat?
    @ViewBuilder var sidebar: () -> Sidebar
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geometry in
            let width = CabinetSidebarWidth.visible(dragWidth ?? preferredWidth, in: geometry.size.width)
            HStack(spacing: 0) {
                sidebar().frame(width: width)
                Divider()
                content()
            }
            .overlay(alignment: .leading) {
                CabinetSidebarResizeHandle(width: width, resize: { delta in
                    if dragOrigin == nil { dragOrigin = width }
                    dragWidth = CabinetSidebarWidth.visible((dragOrigin ?? width) + delta, in: geometry.size.width)
                }, finish: {
                    if let dragWidth, dragWidth != dragOrigin { preferredWidth = dragWidth }
                    dragOrigin = nil
                    dragWidth = nil
                }, step: { delta in
                    let next = CabinetSidebarWidth.visible(width + delta, in: geometry.size.width)
                    if next != width { preferredWidth = next }
                })
                .frame(width: 8).offset(x: width - 3.5)
            }
        }
    }
}

private struct CabinetSidebarResizeHandle: NSViewRepresentable {
    var width: CGFloat
    var resize: (CGFloat) -> Void
    var finish: () -> Void
    var step: (CGFloat) -> Void

    func makeNSView(context: Context) -> CabinetSidebarDivider {
        let view = CabinetSidebarDivider()
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.splitter)
        view.setAccessibilityLabel("侧栏宽度")
        view.setAccessibilityHelp("左右拖动调整宽度；辅助功能增减操作每次调整 10 点")
        return view
    }

    func updateNSView(_ view: CabinetSidebarDivider, context: Context) {
        view.resize = resize
        view.finish = finish
        view.step = step
        view.setAccessibilityValue(NSNumber(value: Double(width)))
    }
}

/// AppKit 直接接收拖动事件，不用计时器或循环等待，也不抢正文输入焦点。
final class CabinetSidebarDivider: NSView {
    var resize: (CGFloat) -> Void = { _ in }
    var finish: () -> Void = {}
    var step: (CGFloat) -> Void = { _ in }
    private var originX: CGFloat?
    private var didDrag = false
    private var hovered = false

    override func resetCursorRects() { addCursorRect(bounds, cursor: .resizeLeftRight) }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect], owner: self))
    }
    override func mouseEntered(with event: NSEvent) { hovered = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hovered = false; needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        guard hovered || didDrag else { return }
        NSColor.secondaryLabelColor.withAlphaComponent(0.35).setFill()
        NSRect(x: bounds.midX - 1, y: 0, width: 2, height: bounds.height).fill()
    }
    override func mouseDown(with event: NSEvent) {
        originX = event.locationInWindow.x
        didDrag = false
    }
    override func mouseDragged(with event: NSEvent) {
        guard let originX else { return }
        didDrag = true
        resize(event.locationInWindow.x - originX)
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        if didDrag, let originX { resize(event.locationInWindow.x - originX) }
        finish()
        originX = nil
        didDrag = false
        needsDisplay = true
    }
    override func accessibilityPerformIncrement() -> Bool { step(10); return true }
    override func accessibilityPerformDecrement() -> Bool { step(-10); return true }
}
