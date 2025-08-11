//
//  ClipboardMonitor.swift
//  cheatsheet
//
//  Created by 周麒 on 2025/8/11.
//

import AppKit
import CoreData

class ClipboardMonitor {
    private let context: NSManagedObjectContext
    private let pasteboard: PasteboardReading
    private var timer: Timer?
    private var lastCopiedValue: String?
    private var lastChangeCount: Int
    
    init(context: NSManagedObjectContext, pasteboard: PasteboardReading) {
        self.context = context
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount
        
        // Run cleanup on initialization in the background
        cleanupOldItems()
        fetchLastItem()
    }

    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func fetchLastItem() {
        context.perform {
            let request: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItem.createdAt, ascending: false)]
            request.fetchLimit = 1
            
            do {
                let lastItem = try self.context.fetch(request).first
                self.lastCopiedValue = lastItem?.content
            } catch {
                print("❌ Error fetching last clipboard item: \(error)")
            }
        }
    }

    private func checkClipboard() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        
        guard let newText = pasteboard.string(forType: .string),
              !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              newText != lastCopiedValue else {
            return
        }
        
        lastCopiedValue = newText
        
        context.perform {
            _ = ClipboardItem(context: self.context, content: newText)
            print("✅ ClipboardMonitor: Saved new item - \(newText.prefix(30))")
            
            do {
                try self.context.save()
            } catch {
                print("❌ Error saving clipboard item: \(error)")
            }
        }
    }
    
    private func cleanupOldItems() {
        context.perform {
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            let fetchRequest: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "createdAt < %@", sevenDaysAgo as NSDate)
            
            do {
                let itemsToDelete = try self.context.fetch(fetchRequest)
                if !itemsToDelete.isEmpty {
                    for item in itemsToDelete {
                        self.context.delete(item)
                    }
                    try self.context.save()
                    print("✅ ClipboardMonitor: Cleaned up \(itemsToDelete.count) items older than 7 days.")
                }
            } catch {
                print("❌ Error cleaning up old clipboard items: \(error.localizedDescription)")
            }
        }
    }
}
