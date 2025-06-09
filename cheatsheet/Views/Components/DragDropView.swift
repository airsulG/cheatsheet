//
//  DragDropView.swift
//  cheatsheet
//
//  Created by 周麒 on 2025/6/9.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - 拖拽数据类型定义

struct DragData {
    let id: String
    let type: DragType
    let index: Int
}

enum DragType: String, CaseIterable {
    case category = "category"
    case command = "command"

    var utType: UTType {
        switch self {
        case .category:
            return UTType("com.cheathub.category") ?? UTType.data
        case .command:
            return UTType("com.cheathub.command") ?? UTType.data
        }
    }
}

// MARK: - 拖拽状态管理

class DragState: ObservableObject {
    @Published var isDragging = false
    @Published var draggedItem: DragData?
    @Published var dropTarget: DragData?
    
    func startDrag(item: DragData) {
        isDragging = true
        draggedItem = item
    }
    
    func endDrag() {
        isDragging = false
        draggedItem = nil
        dropTarget = nil
    }
    
    func setDropTarget(_ target: DragData?) {
        dropTarget = target
    }
}

// MARK: - 可拖拽视图修饰符

struct DraggableModifier: ViewModifier {
    let dragData: DragData
    @ObservedObject var dragState: DragState
    @State private var dragTimer: Timer?
    @State private var isLongPressing = false

    func body(content: Content) -> some View {
        content
            .opacity(dragState.draggedItem?.id == dragData.id ? 0.5 : 1.0)
            .scaleEffect(dragState.draggedItem?.id == dragData.id ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: dragState.isDragging)
            .onLongPressGesture(minimumDuration: 0.5) {
                // 长按0.5秒后启用拖拽
                isLongPressing = true
            }
            .onDrag {
                // 只有在长按后才允许拖拽
                if isLongPressing {
                    dragState.startDrag(item: dragData)
                    isLongPressing = false
                    return NSItemProvider(object: dragData.id as NSString)
                } else {
                    return NSItemProvider()
                }
            }
    }
}

// MARK: - 可放置视图修饰符

struct DroppableModifier: ViewModifier {
    let dropData: DragData
    @ObservedObject var dragState: DragState
    let onDrop: (DragData, DragData) -> Bool
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(dropTargetColor)
                    .opacity(dropTargetOpacity)
                    .animation(.easeInOut(duration: 0.2), value: dragState.dropTarget?.id)
            )
            .onDrop(of: [dropData.type.utType], delegate: CheatHubDropDelegate(
                dropData: dropData,
                dragState: dragState,
                onDrop: onDrop
            ))
    }
    
    private var dropTargetColor: Color {
        guard let dropTarget = dragState.dropTarget,
              dropTarget.id == dropData.id,
              let draggedItem = dragState.draggedItem,
              draggedItem.type == dropData.type else {
            return Color.clear
        }
        return Color.blue
    }
    
    private var dropTargetOpacity: Double {
        guard let dropTarget = dragState.dropTarget,
              dropTarget.id == dropData.id else {
            return 0.0
        }
        return 0.2
    }
}

// MARK: - 拖放代理

struct CheatHubDropDelegate: DropDelegate {
    let dropData: DragData
    @ObservedObject var dragState: DragState
    let onDrop: (DragData, DragData) -> Bool
    
    func dropEntered(info: DropInfo) {
        guard let draggedItem = dragState.draggedItem,
              draggedItem.type == dropData.type,
              draggedItem.id != dropData.id else {
            return
        }
        dragState.setDropTarget(dropData)
    }
    
    func dropExited(info: DropInfo) {
        if dragState.dropTarget?.id == dropData.id {
            dragState.setDropTarget(nil)
        }
    }
    
    func performDrop(info: DropInfo) -> Bool {
        guard let draggedItem = dragState.draggedItem,
              draggedItem.type == dropData.type else {
            dragState.endDrag()
            return false
        }
        
        let success = onDrop(draggedItem, dropData)
        dragState.endDrag()
        return success
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard let draggedItem = dragState.draggedItem,
              draggedItem.type == dropData.type else {
            return DropProposal(operation: .forbidden)
        }
        
        return DropProposal(operation: .move)
    }
}

// MARK: - 视图扩展

extension View {
    func draggable(
        dragData: DragData,
        dragState: DragState
    ) -> some View {
        self.modifier(DraggableModifier(dragData: dragData, dragState: dragState))
    }
    
    func droppable(
        dropData: DragData,
        dragState: DragState,
        onDrop: @escaping (DragData, DragData) -> Bool
    ) -> some View {
        self.modifier(DroppableModifier(
            dropData: dropData,
            dragState: dragState,
            onDrop: onDrop
        ))
    }
}

// MARK: - 拖拽指示器视图

struct DragIndicatorView: View {
    @ObservedObject var dragState: DragState
    
    var body: some View {
        if dragState.isDragging {
            HStack {
                Image(systemName: "hand.draw")
                    .foregroundColor(.blue)
                Text("拖拽以重新排序")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            .transition(.opacity.combined(with: .scale))
            .animation(.easeInOut(duration: 0.3), value: dragState.isDragging)
        }
    }
}
