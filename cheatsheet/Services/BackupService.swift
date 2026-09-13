//
//  BackupService.swift
//  cheatsheet
//
//  Created by Codex on 2026/4/29.
//

import CoreData
import Foundation

final class BackupService {
    private let context: NSManagedObjectContext
    private let settings: BackupSettings
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        context: NSManagedObjectContext,
        settings: BackupSettings = .shared
    ) {
        self.context = context
        self.settings = settings

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func makeArchive() throws -> BackupArchive {
        try context.performAndWait {
            let request: NSFetchRequest<Category> = Category.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \Category.isPinned, ascending: false),
                NSSortDescriptor(keyPath: \Category.order, ascending: true),
                NSSortDescriptor(keyPath: \Category.createdAt, ascending: true)
            ]

            let categories = try context.fetch(request)
            let backupCategories = categories.map { category in
                BackupCategory(
                    id: category.id ?? UUID(),
                    name: category.name ?? "未命名分类",
                    order: category.order,
                    isPinned: category.isPinned,
                    createdAt: category.createdAt ?? Date(),
                    updatedAt: category.updatedAt ?? Date(),
                    commands: category.commandsArray.map { command in
                        BackupCommand(
                            id: command.id ?? UUID(),
                            name: command.name ?? "未命名命令",
                            content: command.content ?? "",
                            order: command.order,
                            isFavorite: command.isFavorite,
                            favoriteOrder: command.value(forKey: "favoriteOrder") as? Int32,
                            createdAt: command.createdAt ?? Date(),
                            updatedAt: command.updatedAt ?? Date()
                        )
                    }
                )
            }

            return BackupArchive(categories: backupCategories)
        }
    }

    func exportToConfiguredFolder(now: Date = Date()) throws -> URL {
        let folderURL = try settings.resolveBackupFolder()
        return try export(to: folderURL, now: now)
    }

    func export(to folderURL: URL, now: Date = Date()) throws -> URL {
        let archive = try makeArchive()
        let data = try encoder.encode(archive)
        let fileURL = folderURL.appendingPathComponent(Self.fileName(for: now), isDirectory: false)

        let didAccess = folderURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }

        guard FileManager.default.fileExists(atPath: folderURL.path) else {
            throw BackupError.missingBackupFolder
        }

        do {
            try data.write(to: fileURL, options: [.atomic])
        } catch let error as CocoaError where error.code == .fileWriteNoPermission {
            throw BackupError.fileWriteNotAllowed
        }

        settings.markExported(to: fileURL)
        return fileURL
    }

    func importArchive(from fileURL: URL) throws -> BackupImportResult {
        let didAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: fileURL)
        let archive = try decoder.decode(BackupArchive.self, from: data)
        return try importArchive(archive)
    }

    func importArchive(_ archive: BackupArchive) throws -> BackupImportResult {
        guard archive.version == BackupArchive.currentVersion else {
            throw BackupError.unsupportedVersion(archive.version)
        }
        guard !archive.categories.isEmpty else {
            throw BackupError.emptyArchive
        }

        return try context.performAndWait {
            let nextCategoryOrder = try maxCategoryOrder() + 1
            var categoryCount = 0
            var commandCount = 0
            var favoriteCount = 0

            for (categoryIndex, backupCategory) in archive.categories.enumerated() {
                let category = Category(context: context)
                category.id = backupCategory.id
                category.name = uniqueCategoryName(backupCategory.name)
                category.order = nextCategoryOrder + Int32(categoryIndex)
                category.isPinned = backupCategory.isPinned
                category.createdAt = backupCategory.createdAt
                category.updatedAt = backupCategory.updatedAt
                categoryCount += 1

                for backupCommand in backupCategory.commands.sorted(by: { $0.order < $1.order }) {
                    let command = Command(context: context)
                    command.id = backupCommand.id
                    command.name = backupCommand.name
                    command.content = backupCommand.content
                    command.order = backupCommand.order
                    command.isFavorite = backupCommand.isFavorite
                    command.setValue(backupCommand.favoriteOrder, forKey: "favoriteOrder")
                    command.createdAt = backupCommand.createdAt
                    command.updatedAt = backupCommand.updatedAt
                    command.category = category
                    commandCount += 1
                    if backupCommand.isFavorite {
                        favoriteCount += 1
                    }
                }
            }

            try context.save()
            return BackupImportResult(
                categoryCount: categoryCount,
                commandCount: commandCount,
                favoriteCount: favoriteCount
            )
        }
    }

    func runAutomaticBackupIfNeeded(now: Date = Date()) {
        guard settings.shouldRunAutomaticBackup(now: now) else { return }

        do {
            _ = try exportToConfiguredFolder(now: now)
            settings.markAutoExport(at: now)
        } catch {
            print("Automatic backup failed: \(error.localizedDescription)")
        }
    }

    private func maxCategoryOrder() throws -> Int32 {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Category.order, ascending: false)]
        request.fetchLimit = 1
        return try context.fetch(request).first?.order ?? -1
    }

    private func uniqueCategoryName(_ name: String) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmedName.isEmpty ? "导入的分类" : trimmedName
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", baseName)

        let hasExactName = ((try? context.count(for: request)) ?? 0) > 0
        guard hasExactName else { return baseName }

        var index = 2
        while true {
            let candidate = "\(baseName) (\(index))"
            request.predicate = NSPredicate(format: "name == %@", candidate)
            let exists = ((try? context.count(for: request)) ?? 0) > 0
            if !exists { return candidate }
            index += 1
        }
    }

    private static func fileName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "cheatsheet-backup-\(formatter.string(from: date)).json"
    }
}
