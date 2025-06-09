//
//  Category+Extensions.swift
//  cheatsheet
//
//  Created by 周麒 on 2025/6/9.
//

import Foundation
import CoreData

extension Category {
    
    // MARK: - Convenience Initializers
    
    convenience init(context: NSManagedObjectContext, name: String) {
        self.init(context: context)
        self.id = UUID()
        self.name = name
        self.order = 0
        self.isPinned = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Computed Properties
    
    var commandsArray: [Command] {
        let set = commands as? Set<Command> ?? []
        return set.sorted { $0.order < $1.order }
    }
    
    var commandCount: Int {
        return commands?.count ?? 0
    }
    
    // MARK: - Helper Methods
    
    func updateTimestamp() {
        self.updatedAt = Date()
    }
    
    func addCommand(_ command: Command) {
        command.category = self
        command.order = Int32(commandCount)
        updateTimestamp()
    }
    
    func removeCommand(_ command: Command) {
        command.category = nil
        updateTimestamp()
        // 重新排序剩余命令
        reorderCommands()
    }
    
    func reorderCommands() {
        let sortedCommands = commandsArray
        for (index, command) in sortedCommands.enumerated() {
            command.order = Int32(index)
        }
    }
    
    func moveCommand(from sourceIndex: Int, to destinationIndex: Int) {
        var commands = commandsArray
        let command = commands.remove(at: sourceIndex)
        commands.insert(command, at: destinationIndex)
        
        // 更新所有命令的顺序
        for (index, cmd) in commands.enumerated() {
            cmd.order = Int32(index)
        }
        updateTimestamp()
    }
}
