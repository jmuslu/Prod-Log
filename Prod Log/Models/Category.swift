import SwiftUI

struct Category: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let color: Color
    let pointsPerMinute: Double
    let isDefault: Bool
    let deletedDate: Date?
    
    init(id: UUID = UUID(), name: String, color: Color, pointsPerMinute: Double, isDefault: Bool, deletedDate: Date? = nil) {
        self.id = id
        self.name = name
        self.color = color
        self.pointsPerMinute = pointsPerMinute
        self.isDefault = isDefault
        self.deletedDate = deletedDate
    }
    
    static let defaultCategories = [
        Category(name: "Entertainment", color: .blue, pointsPerMinute: 5, isDefault: true),
        Category(name: "Sleep", color: .purple, pointsPerMinute: 5, isDefault: true),
        Category(name: "Physical Activity", color: .green, pointsPerMinute: 5, isDefault: true),
        Category(name: "Work", color: .orange, pointsPerMinute: 5, isDefault: true),
        Category(name: "Relax", color: .teal, pointsPerMinute: 5, isDefault: true)
    ]
    
    // Add computed property to always return integer points
    var pointsPerMinuteInt: Int {
        Int(pointsPerMinute)
    }
    
    // Implement Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Category, rhs: Category) -> Bool {
        lhs.id == rhs.id
    }
}

// Extension to handle Color coding
extension Color: Codable {
    enum CodingKeys: String, CodingKey {
        case red, green, blue, alpha
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let r = try container.decode(Double.self, forKey: .red)
        let g = try container.decode(Double.self, forKey: .green)
        let b = try container.decode(Double.self, forKey: .blue)
        let a = try container.decode(Double.self, forKey: .alpha)
        self.init(red: r, green: g, blue: b, opacity: a)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let (r, g, b, a): (CGFloat, CGFloat, CGFloat, CGFloat) = {
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
            return (r, g, b, a)
        }()
        
        try container.encode(r, forKey: .red)
        try container.encode(g, forKey: .green)
        try container.encode(b, forKey: .blue)
        try container.encode(a, forKey: .alpha)
    }
} 