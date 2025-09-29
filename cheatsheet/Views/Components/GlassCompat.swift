import SwiftUI
import AppKit

/// 背景玻璃兼容层：
/// - 在 macOS 26 及以上：使用 SwiftUI 的 `.glassEffect()`（液态玻璃）
/// - 在更早系统：回退到 NSVisualEffectView（磨砂玻璃）
struct GlassBackground: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private var shouldReduceTransparency: Bool {
        // 使用 AppKit 的辅助功能设置检测；结合 SwiftUI 的对比度环境值
        let reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        let increaseContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        return reduceTransparency || increaseContrast || (colorSchemeContrast == .increased)
    }

    var body: some View {
        Group {
            if #available(macOS 26, *) {
                if shouldReduceTransparency {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                } else {
                    // 由上层容器负责液态玻璃；这里不再叠加，避免双重效果
                    Color.clear.ignoresSafeArea()
                }
            } else {
                if shouldReduceTransparency {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                } else {
                    VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                        .ignoresSafeArea()
                }
            }
        }
    }
}

// MARK: - 玻璃联结兼容封装（A1）
struct GlassUnionCompat: ViewModifier {
    let id: String
    let ns: Namespace.ID

    func body(content: Content) -> some View {
        Group {
            if #available(macOS 26, *) {
                content.glassEffectUnion(id: id, namespace: ns)
            } else {
                content
            }
        }
    }
}

extension View {
    func glassUnion(id: String, namespace ns: Namespace.ID) -> some View {
        modifier(GlassUnionCompat(id: id, ns: ns))
    }

    // macOS 26+ 才应用：.glassEffect(.regular.interactive(), in: Capsule())
    @ViewBuilder
    func glassEffectCapsuleInteractiveCompat() -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            self
        }
    }

    // macOS 26+ 才应用：.glassEffect(.regular, in: RoundedRectangle(...))
    @ViewBuilder
    func glassEffectRoundedCompat(cornerRadius: CGFloat) -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self
        }
    }

    // macOS 26+：将当前视图整片矩形液态玻璃（方案 1）
    @ViewBuilder
    func glassEffectRectCompat(shouldReduceTransparency: Bool) -> some View {
        if #available(macOS 26, *), !shouldReduceTransparency {
            self.glassEffect(.regular, in: Rectangle())
        } else {
            self
        }
    }
}
