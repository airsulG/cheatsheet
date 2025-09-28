//
//  PasteboardReading.swift
//  cheatsheet
//
//  Created by 周麒 on 2025/8/11.
//

import Foundation
import AppKit

protocol PasteboardReading {
    var changeCount: Int { get }
    func string(forType type: NSPasteboard.PasteboardType) -> String?
    func data(forType type: NSPasteboard.PasteboardType) -> Data?
    var types: [NSPasteboard.PasteboardType] { get }
}

struct SystemPasteboard: PasteboardReading {
    private let pasteboard = NSPasteboard.general
    
    var changeCount: Int {
        pasteboard.changeCount
    }
    
    func string(forType type: NSPasteboard.PasteboardType) -> String? {
        pasteboard.string(forType: type)
    }

    func data(forType type: NSPasteboard.PasteboardType) -> Data? {
        pasteboard.data(forType: type)
    }

    var types: [NSPasteboard.PasteboardType] {
        pasteboard.types ?? []
    }
}
