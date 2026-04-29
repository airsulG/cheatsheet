//
//  BackupArchive.swift
//  cheatsheet
//
//  Created by Codex on 2026/4/29.
//

import Foundation

struct BackupArchive: Codable {
    static let currentVersion = 1

    let version: Int
    let exportedAt: Date
    let appName: String
    let categories: [BackupCategory]

    init(
        version: Int = BackupArchive.currentVersion,
        exportedAt: Date = Date(),
        appName: String = "cheatsheet",
        categories: [BackupCategory]
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.appName = appName
        self.categories = categories
    }
}
struct BackupCategory: Codable, Identifiable {
    let id: UUID
    let name: String
    let order: Int32
    let isPinned: Bool
    let createdAt: Date
    let updatedAt: Date
    let commands: [BackupCommand]
}

struct BackupCommand: Codable, Identifiable {
    let id: UUID
    let name: String
    let content: String
    let order: Int32
    let isFavorite: Bool
    let favoriteOrder: Int32?
    let createdAt: Date
    let updatedAt: Date
}

struct BackupImportResult {
    let categoryCount: Int
    let commandCount: Int
    let favoriteCount: Int
}

enum BackupError: LocalizedError {
    case missingBackupFolder
    case unsupportedVersion(Int)
    case emptyArchive
    case invalidFolderBookmark
    case fileWriteNotAllowed

    var errorDescription: String? {
        switch self {
        case .missingBackupFolder:
            return "请先选择备份文件夹"
        case .unsupportedVersion(let version):
            return "不支持的备份文件版本：\(version)"
        case .emptyArchive:
            return "备份文件里没有可导入的分类"
        case .invalidFolderBookmark:
            return "备份文件夹授权已失效，请重新选择文件夹"
        case .fileWriteNotAllowed:
            return "没有写入这个文件夹的权限，请重新选择备份文件夹"
        }
    }
}
