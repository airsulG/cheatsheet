//
//  BackupSettings.swift
//  cheatsheet
//
//  Created by Codex on 2026/4/29.
//

import Foundation

enum BackupFrequency: String, CaseIterable, Identifiable {
    case off
    case onLaunch
    case daily
    case weekly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: return "关闭"
        case .onLaunch: return "每次启动"
        case .daily: return "每天一次"
        case .weekly: return "每周一次"
        }
    }

    var interval: TimeInterval? {
        switch self {
        case .off:
            return nil
        case .onLaunch:
            return 0
        case .daily:
            return 24 * 60 * 60
        case .weekly:
            return 7 * 24 * 60 * 60
        }
    }
}
final class BackupSettings: ObservableObject {
    static let shared = BackupSettings()

    private static let folderBookmarkKey = "backup_folder_bookmark"
    private static let folderPathKey = "backup_folder_path"
    private static let frequencyKey = "backup_frequency"
    private static let lastAutoExportAtKey = "backup_last_auto_export_at"
    private static let lastExportPathKey = "backup_last_export_path"

    @Published private(set) var backupFolderPath: String?
    @Published var frequency: BackupFrequency {
        didSet {
            UserDefaults.standard.set(frequency.rawValue, forKey: Self.frequencyKey)
        }
    }
    @Published private(set) var lastAutoExportAt: Date?
    @Published private(set) var lastExportPath: String?

    private init() {
        backupFolderPath = UserDefaults.standard.string(forKey: Self.folderPathKey)
        if let rawValue = UserDefaults.standard.string(forKey: Self.frequencyKey),
           let savedFrequency = BackupFrequency(rawValue: rawValue) {
            frequency = savedFrequency
        } else {
            frequency = .off
        }
        lastAutoExportAt = UserDefaults.standard.object(forKey: Self.lastAutoExportAtKey) as? Date
        lastExportPath = UserDefaults.standard.string(forKey: Self.lastExportPathKey)
    }

    func setBackupFolder(_ url: URL) throws {
        let bookmark = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(bookmark, forKey: Self.folderBookmarkKey)
        UserDefaults.standard.set(url.path, forKey: Self.folderPathKey)
        backupFolderPath = url.path
    }

    func clearBackupFolder() {
        UserDefaults.standard.removeObject(forKey: Self.folderBookmarkKey)
        UserDefaults.standard.removeObject(forKey: Self.folderPathKey)
        backupFolderPath = nil
    }

    func resolveBackupFolder() throws -> URL {
        guard let bookmark = UserDefaults.standard.data(forKey: Self.folderBookmarkKey) else {
            throw BackupError.missingBackupFolder
        }

        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        if isStale {
            try setBackupFolder(url)
        }

        return url
    }

    func markAutoExport(at date: Date) {
        lastAutoExportAt = date
        UserDefaults.standard.set(date, forKey: Self.lastAutoExportAtKey)
    }

    func markExported(to url: URL) {
        lastExportPath = url.path
        UserDefaults.standard.set(url.path, forKey: Self.lastExportPathKey)
    }

    func shouldRunAutomaticBackup(now: Date = Date()) -> Bool {
        guard let interval = frequency.interval else { return false }
        guard backupFolderPath != nil else { return false }
        if frequency == .onLaunch { return true }
        guard let lastAutoExportAt else { return true }
        return now.timeIntervalSince(lastAutoExportAt) >= interval
    }
}
