//
//  Persistence.swift
//  cheatsheet
//
//  Created by 周麒 on 2025/6/9.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext

        // 创建示例分类
        let dockerCategory = Category(context: viewContext, name: "Docker")
        dockerCategory.isPinned = true
        dockerCategory.order = 0

        let gitCategory = Category(context: viewContext, name: "Git")
        gitCategory.isPinned = true
        gitCategory.order = 1

        let opensslCategory = Category(context: viewContext, name: "OpenSSL")
        opensslCategory.order = 2

        // 创建示例命令
        let dockerCommands = [
            ("进入运行中的容器", "docker exec -it [容器名/ID] /bin/bash"),
            ("查看所有容器", "docker ps -a"),
            ("清理未使用资源", "docker system prune -a"),
            ("启动服务 (Compose)", "docker-compose up -d")
        ]

        for (index, (name, content)) in dockerCommands.enumerated() {
            let command = Command(context: viewContext, name: name, content: content, category: dockerCategory)
            command.order = Int32(index)
        }

        let gitCommands = [
            ("查看状态", "git status"),
            ("提交更改", "git commit -m \"[message]\""),
            ("推送到远程", "git push origin [branch]"),
            ("拉取最新", "git pull origin [branch]")
        ]

        for (index, (name, content)) in gitCommands.enumerated() {
            let command = Command(context: viewContext, name: name, content: content, category: gitCategory)
            command.order = Int32(index)
        }

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "cheatsheet")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
