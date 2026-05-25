//
//  ClipboardHistoryViewModel.swift
//  cheatsheet
//
//  Created by 周麒 on 2025/8/11.
//

import Foundation
import CoreData
import SwiftUI
#if os(macOS)
import AppKit
#endif

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
        // selector 在「发布 save 的那个线程」上同步派发。后台 context 的 save 会让这里跑在
        // 私有队列，跨线程触碰 viewContext 会和 automaticallyMergesChangesFromParent 自动合并
        // 撞拍。修法是只在主队列做 fetch，并且不再手动 mergeChanges——auto-merge 已经接管了。
        guard let context = notification.object as? NSManagedObjectContext,
              context !== viewContext else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.fetchItems()
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
        #if os(macOS)
        let pb = NSPasteboard.general
        pb.clearContents()
        let type = item.type ?? "text"
        var ok = false
        switch type {
        case "image":
            if let data = item.data {
                ok = pb.setData(data, forType: .png) || pb.setData(data, forType: .tiff)
            }
        case "file":
            if let s = item.content, let url = URL(string: s) {
                ok = pb.setString(url.absoluteString, forType: .fileURL)
            }
        case "html":
            ok = pb.setString(item.content ?? "", forType: .html)
        case "rtf":
            if let data = item.data {
                ok = pb.setData(data, forType: .rtf)
            } else {
                ok = pb.setString(item.content ?? "", forType: .string)
            }
        case "url":
            ok = pb.setString(item.content ?? "", forType: .URL)
        default:
            ok = pb.setString(item.content ?? "", forType: .string)
        }
        if ok {
            showCopyToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.showCopyToast = false }
        }
        #else
        _ = item
        #endif
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
