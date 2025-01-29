import SwiftUI

struct LogCard: Identifiable, Equatable {
    let id = UUID()
    let startTime: Date
    let endTime: Date
    var categories: [Category: Double] = [:]
    var isComplete: Bool = false
    
    static func == (lhs: LogCard, rhs: LogCard) -> Bool {
        lhs.id == rhs.id
    }
} 