import AppKit
import SwiftUI

enum CabinetMotion {
    static func settle(_ duration: Double) -> Animation {
        .timingCurve(0.23, 1, 0.32, 1, duration: duration)
    }
    static let hover = Animation.easeInOut(duration: 0.1)
}

struct CabinetCardStyle: ButtonStyle {
    let selected: Bool
    let palette: CabinetPalette

    func makeBody(configuration: Configuration) -> some View {
        Surface(label: configuration.label, pressed: configuration.isPressed, selected: selected, palette: palette)
    }

    private struct Surface: View {
        let label: ButtonStyleConfiguration.Label
        let pressed: Bool
        let selected: Bool
        let palette: CabinetPalette
        @State private var hovered = false
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            label
                .background(selected ? palette.selection : palette.reader.opacity(0.44), in: RoundedRectangle(cornerRadius: 7))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.primary.opacity(hovered ? 0.025 : 0))
                        .allowsHitTesting(false)
                        .animation(CabinetMotion.hover, value: hovered)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(selected ? palette.accent.opacity(hovered ? 0.64 : 0.48) : Color.primary.opacity(hovered ? 0.22 : 0.12), lineWidth: 1)
                        .allowsHitTesting(false)
                        .animation(CabinetMotion.hover, value: hovered)
                }
                .scaleEffect(pressed && !reduceMotion ? 0.99 : 1)
                .animation(pressed || reduceMotion ? nil : CabinetMotion.settle(0.1), value: pressed)
                // 最外层命中区域不随视觉压缩，保留整张卡片的点击面积。
                .contentShape(Rectangle())
                .onHover { hovered = $0 }
        }
    }
}

struct CabinetToast: View {
    let message: String?
    let palette: CabinetPalette
    @State private var displayedMessage = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var visible: Bool { message != nil }

    var body: some View {
        Label {
            Text(displayedMessage)
        } icon: {
            Image(systemName: "checkmark.circle.fill")
                .scaleEffect(reduceMotion || visible ? 1 : 0.92)
        }
        .font(.system(size: 13, weight: .medium)).foregroundStyle(palette.accent)
        .padding(.horizontal, 16).padding(.vertical, 11)
        .background(palette.reader, in: Capsule())
        .overlay(Capsule().stroke(palette.accent.opacity(0.5), lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        .opacity(visible ? 1 : 0)
        .offset(y: reduceMotion || visible ? 0 : -5)
        .animation(CabinetMotion.settle(visible ? 0.14 : 0.1), value: visible)
        .onChange(of: message, initial: true) { _, value in
            if let value { displayedMessage = value }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(!visible)
        .accessibilityLabel(message ?? "")
    }
}

struct CabinetFavoriteButton: View {
    @ObservedObject var command: Command
    let model: CabinetViewModel
    @State private var usesMotion = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            usesMotion = NSApp.currentEvent?.type != .keyDown
            model.toggleFavorite(command)
        } label: {
            Image(systemName: command.isFavorite ? "star.fill" : "star")
                .scaleEffect(command.isFavorite && !reduceMotion ? 1.04 : 1)
                .animation(reduceMotion || !usesMotion ? nil : .spring(duration: 0.2, bounce: command.isFavorite ? 0.1 : 0), value: command.isFavorite)
        }.buttonStyle(.borderless)
            .help(command.isFavorite ? "取消常用" : "设为常用")
            .accessibilityLabel(command.isFavorite ? "取消常用" : "设为常用")
    }
}
