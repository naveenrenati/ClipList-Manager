import Foundation
import SwiftData

@Model
class ClipboardItem: Identifiable {
    @Attribute(.unique) var id: UUID
    var content: String
    var createdAt: Date
    var isPinned: Bool
    
    init(content: String, createdAt: Date = Date(), isPinned: Bool = false) {
        self.id = UUID()
        self.content = content
        self.createdAt = createdAt
        self.isPinned = isPinned
    }
}
