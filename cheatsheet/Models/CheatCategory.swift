import Foundation
import SwiftUI

struct CheatCommand: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var command: String
    var order: Int
}

struct CheatCategory: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var pinned: Bool = false
    var order: Int
    var commands: [CheatCommand] = []
}
