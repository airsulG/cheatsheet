import AVFoundation
import Combine
import Foundation

enum CabinetSuccess: CaseIterable {
    case copied, saved
    var resource: String { self == .copied ? "cabinet-copy" : "cabinet-save" }
}

/// 只接受已经成功的用户操作；启动时预载，点击路径不读文件、不解码。
@MainActor
final class CabinetSoundPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = CabinetSoundPlayer()
    static let enabledKey = "cabinetSoundEnabled"
    static let saveEnabledKey = "cabinetSaveSoundEnabled"
    static let volumeKey = "cabinetSoundVolume"
    @Published private(set) var available = false
    private let defaults: UserDefaults
    private let playback: ((CabinetSuccess, Float) -> Bool)?
    private let clock: () -> TimeInterval
    private var players: [CabinetSuccess: AVAudioPlayer] = [:]
    private var pendingSave: Task<Void, Never>?
    private var lastStart: (kind: CabinetSuccess, time: TimeInterval)?

    init(defaults: UserDefaults = .standard,
         clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         playback: ((CabinetSuccess, Float) -> Bool)? = nil) {
        self.defaults = defaults
        self.clock = clock
        self.playback = playback
        super.init()
        available = playback != nil
    }

    var enabled: Bool { defaults.object(forKey: Self.enabledKey) as? Bool ?? true }
    var saveEnabled: Bool { defaults.object(forKey: Self.saveEnabledKey) as? Bool ?? false }
    var volume: Float {
        let value = defaults.object(forKey: Self.volumeKey) as? Double ?? 0.35
        return value.isFinite ? Float(min(1, max(0, value))) : 0.35
    }

    func prepare(bundle: Bundle = .main) {
        guard players.isEmpty, playback == nil else { return }
        for kind in CabinetSuccess.allCases {
            guard let url = bundle.url(forResource: kind.resource, withExtension: "wav", subdirectory: "InteractionSounds")
                ?? bundle.url(forResource: kind.resource, withExtension: "wav"),
                let data = try? Data(contentsOf: url),
                let player = try? AVAudioPlayer(data: data), player.prepareToPlay() else { continue }
            player.numberOfLoops = 0
            player.delegate = self
            players[kind] = player
        }
        available = players.count == CabinetSuccess.allCases.count
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard !player.isPlaying else { return }
        // 自然播放结束也会释放准备状态；在结束回调预备下一次，不等下一次点击。
        player.currentTime = 0
        if !player.prepareToPlay() { available = false }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        available = false
        stop()
    }

    func request(_ kind: CabinetSuccess) {
        if kind == .copied { cancelPending() }
        guard enabled, available, volume > 0 else { return }
        if kind == .saved {
            guard saveEnabled else { return }
            cancelPending()
            // 为紧接着发生的复制保留合并窗口；不延迟保存、复制或视觉反馈。
            pendingSave = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(80))
                guard !Task.isCancelled, let self else { return }
                self.pendingSave = nil
                guard self.saveEnabled else { return }
                _ = self.play(.saved)
            }
        } else { _ = play(.copied) }
    }

    @discardableResult
    func audition(_ kind: CabinetSuccess) -> Bool {
        cancelPending()
        return play(kind, audition: true)
    }

    func cancelPending() {
        pendingSave?.cancel()
        pendingSave = nil
    }

    func stop() {
        cancelPending()
        players.values.forEach { $0.pause(); $0.currentTime = 0 }
        lastStart = nil
    }

    @discardableResult
    private func play(_ kind: CabinetSuccess, audition: Bool = false) -> Bool {
        guard enabled, available, volume > 0 else { return false }
        let now = clock()
        if !audition, let lastStart {
            let gap = now - lastStart.time
            if kind == .copied && lastStart.kind == .copied && gap < 0.12 { return false }
            if kind == .saved && gap < 0.3 { return false }
        }
        let started: Bool
        if let playback { started = playback(kind, volume) }
        else {
            guard let player = players[kind] else { return false }
            // pause 保留 prepareToPlay 的准备状态，避免 stop 在下一击重新准备。
            players.values.forEach { $0.pause(); $0.currentTime = 0 }
            player.currentTime = 0
            player.volume = volume
            started = player.play()
        }
        if started { lastStart = (kind, now) }
        return started
    }
}
