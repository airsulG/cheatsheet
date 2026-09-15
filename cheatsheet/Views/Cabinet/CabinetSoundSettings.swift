import SwiftUI

struct CabinetSoundSettings: View {
    @AppStorage(CabinetSoundPlayer.enabledKey) private var enabled = true
    @AppStorage(CabinetSoundPlayer.saveEnabledKey) private var saveEnabled = false
    @AppStorage(CabinetSoundPlayer.volumeKey) private var volume = 0.35
    @ObservedObject private var player = CabinetSoundPlayer.shared

    var body: some View {
        CabinetSettingsSection {
            Toggle("操作音效", isOn: $enabled)
            Text("复制成功时轻声确认；输入、滚动和后台采集保持安静。")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Text("音效音量")
                Slider(value: $volume, in: 0...1).labelsHidden().accessibilityLabel("音效音量")
                Text(volume.formatted(.percent.precision(.fractionLength(0))))
                    .monospacedDigit().frame(width: 38, alignment: .trailing)
            }.disabled(!enabled)
            Toggle("自动保存音", isOn: $saveEnabled).disabled(!enabled)
            HStack {
                Text(player.available ? "试听" : "音效暂不可用")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("复制音") { player.audition(.copied) }
                    .accessibilityLabel("试听复制音")
                Button("保存音") { player.audition(.saved) }
                    .accessibilityLabel("试听保存音")
            }.disabled(!enabled || !player.available || volume == 0)
            Text("关闭音效后，保存和复制仍显示文字提示。")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        } header: { Text("声音反馈") }
        .onChange(of: enabled) { _, value in if !value { player.stop() } }
        .onChange(of: saveEnabled) { _, value in if !value { player.cancelPending() } }
        .onChange(of: volume) { _, value in if value == 0 { player.stop() } }
    }
}
