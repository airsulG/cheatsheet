import Foundation
import SwiftUI

@MainActor
class CheatStore: ObservableObject {
    @Published var categories: [CheatCategory] = [] {
        didSet { save() }
    }

    private let storeURL: URL

    init() {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storeURL = url.appendingPathComponent("cheatstore.json")
        load()
    }

    func load() {
        do {
            let data = try Data(contentsOf: storeURL)
            let decoder = JSONDecoder()
            categories = try decoder.decode([CheatCategory].self, from: data)
        } catch {
            categories = []
        }
    }

    func save() {
        do {
            try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            let data = try encoder.encode(categories)
            try data.write(to: storeURL)
        } catch {
            print("Save error: \(error)")
        }
    }

    // MARK: - Category Operations
    func addCategory(named name: String) {
        let order = (categories.map { $0.order }.max() ?? 0) + 1
        categories.append(CheatCategory(name: name, order: order))
    }

    func renameCategory(_ category: CheatCategory, newName: String) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else { return }
        categories[index].name = newName
    }

    func deleteCategories(at offsets: IndexSet) {
        categories.remove(atOffsets: offsets)
    }

    func moveCategories(from source: IndexSet, to destination: Int) {
        categories.move(fromOffsets: source, toOffset: destination)
        for index in categories.indices { categories[index].order = index }
    }

    // MARK: - Command Operations
    func addCommand(to category: CheatCategory, name: String, command: String) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else { return }
        let order = (categories[index].commands.map { $0.order }.max() ?? 0) + 1
        categories[index].commands.append(CheatCommand(name: name, command: command, order: order))
    }

    func renameCommand(_ commandItem: CheatCommand, in category: CheatCategory, newName: String, newCommand: String) {
        guard let catIndex = categories.firstIndex(where: { $0.id == category.id }) else { return }
        guard let cmdIndex = categories[catIndex].commands.firstIndex(where: { $0.id == commandItem.id }) else { return }
        categories[catIndex].commands[cmdIndex].name = newName
        categories[catIndex].commands[cmdIndex].command = newCommand
    }

    func deleteCommands(in category: CheatCategory, at offsets: IndexSet) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else { return }
        categories[index].commands.remove(atOffsets: offsets)
    }

    func moveCommands(in category: CheatCategory, from source: IndexSet, to destination: Int) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else { return }
        categories[index].commands.move(fromOffsets: source, toOffset: destination)
        for cmdIndex in categories[index].commands.indices { categories[index].commands[cmdIndex].order = cmdIndex }
    }
}
