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

            var archive = BackupArchive(categories: backupCategories)
            archive.categoriesMetadata(from: categories)
            archive.commands = try context.fetch(Command.fetchRequest()).map { command in
                var record = BackupCommand(id: command.id ?? UUID(), name: command.name ?? "",
                    content: command.content ?? "", order: command.order, isFavorite: command.isFavorite,
                    favoriteOrder: command.favoriteOrder, createdAt: command.createdAt ?? Date(),
                    updatedAt: command.updatedAt ?? Date())
                var tags = command.tags as? Set<Category> ?? []
                if !command.tagsMigrated, let legacy = command.category { tags.insert(legacy) }
                record.tagIDs = tags.compactMap(\.id)
                record.pinnedTagIDs = (command.pinnedTags as? Set<Category> ?? []).intersection(tags).compactMap(\.id)
                record.imageData = command.imageData
                record.originID = command.originID
                record.deletedAt = command.deletedAt
                return record
            }
            archive.groups = try context.fetch(TagGroup.fetchRequest()).map {
                BackupTagGroup(id: $0.id ?? UUID(), name: $0.name ?? "", order: $0.order, deletedAt: $0.deletedAt)
            }
            return archive
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
        guard (1...BackupArchive.currentVersion).contains(archive.version) else {
            throw BackupError.unsupportedVersion(archive.version)
        }
        guard !archive.categories.isEmpty || !(archive.commands ?? []).isEmpty || !(archive.groups ?? []).isEmpty else {
            throw BackupError.emptyArchive
        }

        return try context.performAndWait {
            let nextCategoryOrder = try maxCategoryOrder() + 1
            var categoryCount = 0
            var commandCount = 0
            var favoriteCount = 0
            var importedTags: [UUID: Category] = [:]
            var importedGroups: [UUID: TagGroup] = [:]
            for record in archive.groups ?? [] {
                let group = TagGroup(context: context)
                group.id = UUID()
                let baseName = record.name.isEmpty ? "导入的分组" : record.name
                var candidate = baseName
                var suffix = 2
                let names = NSFetchRequest<TagGroup>(entityName: "TagGroup")
                while true {
                    names.predicate = NSPredicate(format: "name ==[cd] %@", candidate)
                    if try context.count(for: names) == 0 { break }
                    candidate = "\(baseName) (\(suffix))"
                    suffix += 1
                }
                group.name = candidate
                group.order = record.order
                group.deletedAt = record.deletedAt
                importedGroups[record.id] = group
            }

            for (categoryIndex, backupCategory) in archive.categories.enumerated() {
                let category = Category(context: context)
                category.id = UUID()
                category.name = uniqueCategoryName(backupCategory.name)
                category.order = nextCategoryOrder + Int32(categoryIndex)
                category.isPinned = backupCategory.isPinned
                category.createdAt = backupCategory.createdAt
                category.updatedAt = backupCategory.updatedAt
                category.deletedAt = backupCategory.deletedAt
                category.group = backupCategory.groupID.flatMap { importedGroups[$0] }
                category.previousGroupID = backupCategory.previousGroupID.flatMap { importedGroups[$0]?.id }
                importedTags[backupCategory.id] = category
                categoryCount += 1

                for backupCommand in (archive.commands == nil ? backupCategory.commands : []).sorted(by: { $0.order < $1.order }) {
                    let command = Command(context: context)
                    command.id = UUID()
                    command.name = backupCommand.name
                    command.content = backupCommand.content
                    command.order = backupCommand.order
                    command.isFavorite = backupCommand.isFavorite
                    command.setValue(backupCommand.favoriteOrder, forKey: "favoriteOrder")
                    command.createdAt = backupCommand.createdAt
                    command.updatedAt = backupCommand.updatedAt
                    command.category = category
                    command.addToTags(category)
                    command.tagsMigrated = true
                    commandCount += 1
                    if backupCommand.isFavorite {
                        favoriteCount += 1
                    }
                }
            }

            for record in archive.commands ?? [] {
                let command = Command(context: context, name: record.name, content: record.content)
                command.order = record.order
                command.isFavorite = record.isFavorite
                command.favoriteOrder = record.favoriteOrder ?? 0
                command.createdAt = record.createdAt
                command.updatedAt = record.updatedAt
                command.tags = NSSet(array: (record.tagIDs ?? []).compactMap { importedTags[$0] })
                let importedMemberships = command.tags as? Set<Category> ?? []
                command.pinnedTags = NSSet(set: Set((record.pinnedTagIDs ?? []).compactMap { importedTags[$0] }).intersection(importedMemberships))
                command.tagsMigrated = true
                command.imageData = record.imageData
                command.originID = record.originID
                command.deletedAt = record.deletedAt
                commandCount += 1
                if command.isFavorite { favoriteCount += 1 }
            }

            try context.save()
            return BackupImportResult(
                categoryCount: categoryCount,
                commandCount: commandCount,
                favoriteCount: favoriteCount,
                groupCount: importedGroups.count
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
