//
//  ClipboardHistoryViewModel.swift
//  cheatsheet
//
//  Created by 周麒 on 2025/8/11.
//

import Foundation
import CoreData
import SwiftUI

class ClipboardHistoryViewModel: ObservableObject {
    private let viewContext: NSManagedObjectContext
    
    @Published var items: [ClipboardItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showCopyToast = false

    init(context: NSManagedObjectContext) {
        self.viewContext = context
        fetchItems()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contextDidSave(_:)),
            name: .NSManagedObjectContextDidSave,
            object: nil // Observe saves from any context
        )
    }
    
    @objc private func contextDidSave(_ notification: Notification) {
        // We only care about saves from a background context that get merged to the main
        guard let context = notification.object as? NSManagedObjectContext,
              context != viewContext else {
            return
        }
        
        viewContext.perform {
            self.viewContext.mergeChanges(fromContextDidSave: notification)
            self.fetchItems() // Re-fetch to update the UI
        }
    }
    
    func fetchItems() {
        isLoading = true
        let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItem.createdAt, ascending: false)]
        
        do {
            items = try viewContext.fetch(request)
        } catch {
            errorMessage = "Failed to fetch clipboard history: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    func deleteItem(_ item: ClipboardItem) {
        viewContext.perform {
            self.viewContext.delete(item)
            self.saveContext()
            DispatchQueue.main.async {
                if let index = self.items.firstIndex(of: item) {
                    self.items.remove(at: index)
                }
            }
        }
    }
    
    func copyItem(_ item: ClipboardItem) {
        guard let content = item.content else { return }
        let success = ClipboardManager.shared.copy(content)
        if success {
            showCopyToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.showCopyToast = false
            }
        }
    }

    private func saveContext() {
        do {
            try viewContext.save()
            errorMessage = nil
        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
        }
    }
}
