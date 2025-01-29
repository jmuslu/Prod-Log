import SwiftUI

struct LogCard: Identifiable, Codable, Equatable {
    let id: UUID
    let startTime: Date
    let endTime: Date
    var categories: [Category: Double]
    var isComplete: Bool
    
    // Helper struct for encoding/decoding category-double pairs
    private struct CategoryPercentage: Codable {
        let category: Category
        let percentage: Double
    }
    
    init(id: UUID = UUID(), startTime: Date, endTime: Date, categories: [Category: Double] = [:], isComplete: Bool = false) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.categories = categories
        self.isComplete = isComplete
    }
    
    // Custom coding keys
    enum CodingKeys: String, CodingKey {
        case id, startTime, endTime, categories, isComplete
    }
    
    // Custom encoding for dictionary with Category keys
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encode(isComplete, forKey: .isComplete)
        
        // Convert dictionary to array of CategoryPercentage
        let categoryPercentages = categories.map { (category, percentage) in
            CategoryPercentage(category: category, percentage: percentage)
        }
        try container.encode(categoryPercentages, forKey: .categories)
    }
    
    // Custom decoding for dictionary with Category keys
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decode(Date.self, forKey: .endTime)
        isComplete = try container.decode(Bool.self, forKey: .isComplete)
        
        // Decode array of CategoryPercentage back to dictionary
        let categoryPercentages = try container.decode([CategoryPercentage].self, forKey: .categories)
        categories = Dictionary(uniqueKeysWithValues: categoryPercentages.map { ($0.category, $0.percentage) })
    }
    
    static func == (lhs: LogCard, rhs: LogCard) -> Bool {
        lhs.id == rhs.id
    }
} 