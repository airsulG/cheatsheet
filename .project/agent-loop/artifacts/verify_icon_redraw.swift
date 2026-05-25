import AppKit
import Foundation

// 快速本地验证：对常见 App bundle 用旧路径（tiffRepresentation）和新路径
// （pngData(fromIcon:pixelSize:32) redraw）分别编码 PNG，比较字节数。
// 预期：新路径稳定在几 KB；旧路径 130KB ~ 4MB。

func pngData(fromIcon image: NSImage, pixelSize: Int) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }
    rep.size = NSSize(width: pixelSize, height: pixelSize)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(
        in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize),
        from: .zero,
        operation: .sourceOver,
        fraction: 1.0
    )
    NSGraphicsContext.restoreGraphicsState()

    return rep.representation(using: .png, properties: [:])
}

func tiffPngData(from image: NSImage) -> Data? {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else { return nil }
    return rep.representation(using: .png, properties: [:])
}

let bundles = [
    "/Applications/Safari.app",
    "/System/Applications/Calculator.app",
    "/System/Applications/Utilities/Activity Monitor.app",
    "/Applications/Xcode.app",
]

for path in bundles {
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: path) else {
        print("[skip] \(path)")
        continue
    }
    let icon = NSWorkspace.shared.icon(forFile: url.path)
    let oldData = tiffPngData(from: icon)
    let newData = pngData(fromIcon: icon, pixelSize: 32)
    let oldSize = oldData?.count ?? -1
    let newSize = newData?.count ?? -1
    let name = url.lastPathComponent
    print("\(name) | tiff_path=\(oldSize) bytes | redraw_32=\(newSize) bytes")
}
