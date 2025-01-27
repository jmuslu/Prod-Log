import SwiftUI

class SettingsManager: ObservableObject {
    @Published var timeInterval: Int = 3 // Default 3 hours
    @Published var categories: [Category] = Category.defaultCategories
    
    let availableIntervals = [1, 2, 3, 4, 6, 12]
    
    func addCategory(name: String, color: Color, pointsPerMinute: Double) {
        let newCategory = Category(name: name, color: color, pointsPerMinute: pointsPerMinute, isDefault: false)
        categories.append(newCategory)
    }
    
    func removeCategory(_ category: Category) {
        categories.removeAll { $0.id == category.id }
    }
    
    func resetPoints() {
        // Will implement points reset functionality later
    }
} 