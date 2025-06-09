//
//  Command+Extensions.swift
//  cheatsheet
//
//  Created by 周麒 on 2025/6/9.
//

import Foundation
import CoreData

extension Command {
    
    // MARK: - Convenience Initializers
    
    convenience init(context: NSManagedObjectContext, name: String, content: String, category: Category? = nil) {
        self.init(context: context)
        self.id = UUID()
        self.name = name
        self.content = content
        self.order = 0
        self.isFavorite = false
        self.createdAt = Date()
        self.updatedAt = Date()

        if let category = category {
            self.category = category
            self.order = Int32(category.commandCount)
        }
    }
    
    // MARK: - Helper Methods
    
    func updateTimestamp() {
        self.updatedAt = Date()
        category?.updateTimestamp()
    }

    func updateContent(name: String, content: String) {
        self.name = name
        self.content = content
        updateTimestamp()
    }
    
    // MARK: - Favorite Operations

    func toggleFavorite() {
        self.isFavorite.toggle()
        updateTimestamp()
    }

    func setFavorite(_ favorite: Bool) {
        self.isFavorite = favorite
        updateTimestamp()
    }

    // MARK: - Clipboard Operations

    func copyToClipboard() {
        ClipboardManager.shared.copy(content ?? "")
    }
}
