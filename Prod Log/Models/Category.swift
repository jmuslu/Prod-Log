import SwiftUI

struct Category: Identifiable, Codable {
    var id = UUID()
    var name: String
    var color: Color
    var pointsPerMinute: Double
    var isDefault: Bool
    
    static let defaultCategories = [
        Category(name: "Entertainment", color: .blue, pointsPerMinute: 5, isDefault: true),
        Category(name: "Sleep", color: .purple, pointsPerMinute: 5, isDefault: true),
        Category(name: "Physical Activity", color: .green, pointsPerMinute: 5, isDefault: true),
        Category(name: "Work", color: .orange, pointsPerMinute: 5, isDefault: true),
        Category(name: "Relax", color: .teal, pointsPerMinute: 5, isDefault: true)
    ]
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
        var r, g, b, a: CGFloat
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        try container.encode(r, forKey: .red)
        try container.encode(g, forKey: .green)
        try container.encode(b, forKey: .blue)
        try container.encode(a, forKey: .alpha)
    }
} 