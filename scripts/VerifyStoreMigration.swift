import AppKit
import CoreData
import CryptoKit
@testable import cheatsheet

/// 只在指定的数据副本上升级；输出数量与哈希校验结论，不输出用户正文。
@main
struct VerifyStoreMigration {
    typealias Snapshot = [String: [String: [String: String]]]

    @MainActor static func main() throws {
        guard (4...5).contains(CommandLine.arguments.count) else {
            fatalError("Usage: verify-store <model.momd> <source-directory> <target-directory> [--compare-current]")
        }
        let compareCurrent = CommandLine.arguments.last == "--compare-current"
        let modelURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let source = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        let destination = URL(fileURLWithPath: CommandLine.arguments[3], isDirectory: true)
        // copyItem 拒绝覆盖已有目录，源目录从不以可写方式打开。
        if !compareCurrent { try FileManager.default.copyItem(at: source, to: destination) }
        let oldModel = NSManagedObjectModel(contentsOf: modelURL.appendingPathComponent("cheatsheet.mom"))!
        oldModel.entities.forEach { $0.managedObjectClassName = "NSManagedObject" }
        let old = try open(oldModel, at: source.appendingPathComponent("cheatsheet.sqlite"), readOnly: true)
        let before = try snapshot(old.viewContext, schema: oldModel)
        try close(old)
        let newModel = NSManagedObjectModel(contentsOf: modelURL)!
        let upgraded = try open(newModel, at: destination.appendingPathComponent("cheatsheet.sqlite"), readOnly: compareCurrent)
        if !compareCurrent { try CabinetStore(context: upgraded.viewContext).migrateLegacyTags() }
        let after = try snapshot(upgraded.viewContext, schema: oldModel)
        let retained = before.allSatisfy { entity, records in
            records.allSatisfy { id, values in after[entity]?[id] == values }
        }
        guard retained && (compareCurrent || before == after) else { throw Failure.changedLegacyValues }
        let commands = try upgraded.viewContext.fetch(Command.fetchRequest())
        for command in commands {
            guard command.tagsMigrated else { throw Failure.missingTag }
            if let category = command.category, !command.activeTags.contains(category) { throw Failure.missingTag }
        }
        let images = try upgraded.viewContext.fetch(ClipboardItem.fetchRequest()).filter { $0.type == "image" }
        let decodable = images.filter { $0.data.flatMap(NSImage.init(data:)) != nil }.count
        let report = before.mapValues(\.count)
        print("PASS: every legacy attribute and relationship unchanged; counts \(report)")
        print("PASS: all legacy category links available as tags; image records \(images.count), decodable \(decodable)")
        try close(upgraded)
        if compareCurrent {
            print("PASS: current store read-only comparison preserves all original records; current counts \(after.mapValues(\.count))")
            return
        }
        let reopened = try open(newModel, at: destination.appendingPathComponent("cheatsheet.sqlite"))
        guard try snapshot(reopened.viewContext, schema: oldModel) == before else { throw Failure.changedLegacyValues }
        try close(reopened)
        print("PASS: migrated disk store closes and reopens without changing original values")
    }

    static func open(_ model: NSManagedObjectModel, at url: URL, readOnly: Bool = false) throws -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "cheatsheet", managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: url)
        description.isReadOnly = readOnly
        description.shouldAddStoreAsynchronously = false
        description.shouldMigrateStoreAutomatically = !readOnly
        description.shouldInferMappingModelAutomatically = !readOnly
        container.persistentStoreDescriptions = [description]
        var failure: Error?
        container.loadPersistentStores { _, error in failure = error }
        if let failure { throw failure }
        return container
    }

    static func close(_ container: NSPersistentContainer) throws {
        container.viewContext.reset()
        for store in container.persistentStoreCoordinator.persistentStores {
            try container.persistentStoreCoordinator.remove(store)
        }
    }

    static func identity(_ object: NSManagedObject) -> String {
        if let id = object.value(forKey: "id") as? UUID { return id.uuidString }
        return object.objectID.uriRepresentation().lastPathComponent
    }

    static func snapshot(_ context: NSManagedObjectContext, schema: NSManagedObjectModel) throws -> Snapshot {
        var output: Snapshot = [:]
        for entity in schema.entities {
            let name = entity.name!
            var records: [String: [String: String]] = [:]
            for object in try context.fetch(NSFetchRequest<NSManagedObject>(entityName: name)) {
                var values: [String: String] = [:]
                for key in entity.attributesByName.keys {
                    let value = object.value(forKey: key)
                    if let data = value as? Data {
                        values[key] = "data:\(data.count):" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                    } else if let date = value as? Date {
                        values[key] = "date:\(date.timeIntervalSinceReferenceDate)"
                    } else { values[key] = value.map { String(describing: $0) } ?? "<nil>" }
                }
                for key in entity.relationshipsByName.keys {
                    if let related = object.value(forKey: key) as? NSManagedObject {
                        values["relation:\(key)"] = identity(related)
                    } else if let related = object.value(forKey: key) as? Set<NSManagedObject> {
                        values["relation:\(key)"] = related.map(identity).sorted().joined(separator: ",")
                    } else { values["relation:\(key)"] = "<nil>" }
                }
                let id = identity(object)
                guard records[id] == nil else { throw Failure.duplicateID }
                records[id] = values
            }
            output[name] = records
        }
        return output
    }

    enum Failure: Error { case changedLegacyValues, missingTag, duplicateID }
}
