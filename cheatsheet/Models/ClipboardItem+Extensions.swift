//
//  ClipboardItem+Extensions.swift
//  cheatsheet
//
//  Created by 周麒 on 2025/8/11.
//

import Foundation
import CoreData

extension ClipboardItem {
    
    // MARK: - Convenience Initializers
    
    convenience init(context: NSManagedObjectContext, content: String, type: String = "text") {
        self.init(context: context)
        self.id = UUID()
        self.content = content
        self.createdAt = Date()
        self.type = type
        self.data = nil // For future use with media types
    }
}
