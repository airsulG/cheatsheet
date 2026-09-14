import AppKit
import SwiftUI

/// 保留复制时的来源名称和图标；旧记录没有图标时再查找本机 App。
struct CabinetClipboardSource: View {
    let record: ClipboardItem

    var body: some View {
        HStack(spacing: 7) {
            Group {
                if let icon = CabinetSourceIcon.image(data: record.sourceAppIcon, bundleID: record.sourceBundleId) {
                    Image(nsImage: icon).resizable().scaledToFit()
                } else {
                    Image(systemName: "app.dashed").resizable().scaledToFit().foregroundStyle(.secondary)
                }
            }.frame(width: 22, height: 22).accessibilityHidden(true)
            Text(record.sourceAppName ?? "剪贴板").foregroundStyle(.secondary).lineLimit(1)
            if let date = record.createdAt {
                Text("·").foregroundStyle(.tertiary)
                Text(date, style: .relative).foregroundStyle(.tertiary).lineLimit(1)
            }
        }.font(.system(size: 11))
    }
}

@MainActor
enum CabinetSourceIcon {
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 128
        cache.totalCostLimit = 8 * 1024 * 1024
        return cache
    }()

    static func image(data: Data?, bundleID: String?) -> NSImage? {
        if let data {
            let key = "data:\(data.count):\(data.hashValue)" as NSString
            if let image = cache.object(forKey: key) { return image }
            if let image = NSImage(data: data) {
                cache.setObject(image, forKey: key, cost: data.count)
                return image
            }
        }
        guard let bundleID, !bundleID.isEmpty else { return nil }
        let key = "bundle:\(bundleID)" as NSString
        if let image = cache.object(forKey: key) { return image }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        cache.setObject(image, forKey: key, cost: 64 * 64 * 4)
        return image
    }
}
