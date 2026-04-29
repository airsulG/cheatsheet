//
//  BackupServiceTests.swift
//  cheatsheetTests
//
//  Created by Codex on 2026/4/29.
//

import CoreData
import XCTest
@testable import cheatsheet

final class BackupServiceTests: XCTestCase {
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
    }

    override func tearDownWithError() throws {
        persistenceController = nil
        context = nil
    }

    func testArchiveDoesNotIncludeClipboardHistory() throws {
        let category = Category(context: context, name: "Docker")
        category.isPinned = true
        category.order = 0

        let command = Command(context: context, name: "查看容器", content: "docker ps -a", category: category)
        command.isFavorite = true
        command.setValue(Int32(0), forKey: "favoriteOrder")

        let clipboardItem = ClipboardItem(context: context, content: "不应该进入备份")
        clipboardItem.sourceAppName = "Finder"

        try context.save()

        let archive = try BackupService(context: context).makeArchive()
        XCTAssertEqual(archive.categories.count, 1)
        XCTAssertEqual(archive.categories[0].commands.count, 1)
        XCTAssertEqual(archive.categories[0].commands[0].content, "docker ps -a")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = String(data: try encoder.encode(archive), encoding: .utf8) ?? ""

        XCTAssertFalse(json.contains("ClipboardItem"))
        XCTAssertFalse(json.contains("sourceAppName"))
        XCTAssertFalse(json.contains("不应该进入备份"))
        XCTAssertFalse(json.contains("Finder"))
    }

    func testImportArchiveAppendsCategoriesAndRestoresFavorites() throws {
        let archive = BackupArchive(
            categories: [
                BackupCategory(
                    id: UUID(),
                    name: "Git",
                    order: 0,
                    isPinned: true,
                    createdAt: Date(),
                    updatedAt: Date(),
                    commands: [
                        BackupCommand(
                            id: UUID(),
                            name: "状态",
                            content: "git status",
                            order: 0,
                            isFavorite: true,
                            favoriteOrder: 0,
                            createdAt: Date(),
                            updatedAt: Date()
                        )
                    ]
                )
            ]
        )

        let result = try BackupService(context: context).importArchive(archive)
        XCTAssertEqual(result.categoryCount, 1)
        XCTAssertEqual(result.commandCount, 1)
        XCTAssertEqual(result.favoriteCount, 1)

        let categoryRequest: NSFetchRequest<Category> = Category.fetchRequest()
        let categories = try context.fetch(categoryRequest)
        XCTAssertEqual(categories.count, 1)
        XCTAssertEqual(categories.first?.name, "Git")
        XCTAssertTrue(categories.first?.isPinned ?? false)

        let commandRequest: NSFetchRequest<Command> = Command.fetchRequest()
        let commands = try context.fetch(commandRequest)
        XCTAssertEqual(commands.count, 1)
        XCTAssertEqual(commands.first?.name, "状态")
        XCTAssertEqual(commands.first?.content, "git status")
        XCTAssertTrue(commands.first?.isFavorite ?? false)
        XCTAssertEqual(commands.first?.value(forKey: "favoriteOrder") as? Int32, 0)
    }

    func testImportRejectsUnsupportedVersion() throws {
        let archive = BackupArchive(version: 999, categories: [])

        XCTAssertThrowsError(try BackupService(context: context).importArchive(archive)) { error in
            guard case BackupError.unsupportedVersion(999) = error else {
                return XCTFail("应返回不支持版本错误")
            }
        }
    }
}
