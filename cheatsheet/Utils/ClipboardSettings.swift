//
//  ClipboardSettings.swift
//  cheatsheet
//
//  Created by Claude on 2025/12/20.
//

import Foundation
import SwiftUI

/// 剪贴板历史保存时间选项
enum ClipboardRetentionPeriod: Int, CaseIterable, Identifiable {
    case oneDay = 1
    case threeDays = 3
    case sevenDays = 7
    case thirtyDays = 30
    case forever = 0
    
    var id: Int { rawValue }
    
    var displayName: String {
        switch self {
        case .oneDay: return "1 天"
        case .threeDays: return "3 天"
        case .sevenDays: return "7 天"
        case .thirtyDays: return "30 天"
        case .forever: return "永久保留"
        }
    }
}

/// 剪贴板设置管理器
final class ClipboardSettings: ObservableObject {
    static let shared = ClipboardSettings()
    
    private static let retentionDaysKey = "clipboard_retention_days"
    
    /// 保存天数（0 表示永久）
    @Published var retentionDays: Int {
        didSet {
            UserDefaults.standard.set(retentionDays, forKey: Self.retentionDaysKey)
        }
    }
    
    /// 当前选择的保存周期
    var retentionPeriod: ClipboardRetentionPeriod {
        get {
            ClipboardRetentionPeriod(rawValue: retentionDays) ?? .sevenDays
        }
        set {
            retentionDays = newValue.rawValue
        }
    }
    
    private init() {
        // 默认 7 天
        let saved = UserDefaults.standard.integer(forKey: Self.retentionDaysKey)
        // 如果是第一次启动（未设置过），默认 7 天
        if UserDefaults.standard.object(forKey: Self.retentionDaysKey) == nil {
            self.retentionDays = 7
        } else {
            self.retentionDays = saved
        }
    }
}
