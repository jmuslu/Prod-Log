import SwiftUI

class SettingsManager: ObservableObject {
    @Published var timeInterval: Double = 3.0
    @Published var categories: [Category] = Category.defaultCategories
    @Published private var dailyPoints: [Date: Int] = [:]
    @Published private var categoryPoints: [Date: [Category: Int]] = [:]
    
    let availableIntervals = [1.0, 2.0, 3.0, 4.0, 6.0, 12.0]
    
    func getNextTimeSlot(from date: Date = Date()) -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let intervalHours = Int(timeInterval)
        
        let currentSlot = hour / intervalHours
        let nextSlot = (currentSlot + 1) * intervalHours
        
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = nextSlot
        components.minute = 0
        components.second = 0
        
        if nextSlot >= 24 {
            components = calendar.dateComponents([.year, .month, .day], from: calendar.date(byAdding: .day, value: 1, to: date)!)
            components.hour = 0
        }
        
        return calendar.date(from: components)!
    }
    
    func getCurrentTimeSlot() -> (start: Date, end: Date)? {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let intervalHours = Int(timeInterval)
        
        // Calculate the current slot
        let currentSlot = (hour / intervalHours) * intervalHours
        
        var startComponents = calendar.dateComponents([.year, .month, .day], from: now)
        startComponents.hour = currentSlot
        startComponents.minute = 0
        startComponents.second = 0
        
        let startDate = calendar.date(from: startComponents)!
        let endDate = calendar.date(byAdding: .hour, value: intervalHours, to: startDate)!
        
        // Only return the slot if it's completed
        if now >= endDate {
            return (startDate, endDate)
        }
        return nil
    }
    
    func getLastCompletedSlot() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let intervalHours = Int(timeInterval)
        
        // Calculate the last completed slot
        let currentSlot = (hour / intervalHours) * intervalHours
        let lastSlot = currentSlot - intervalHours
        
        var startComponents = calendar.dateComponents([.year, .month, .day], from: now)
        startComponents.hour = lastSlot
        startComponents.minute = 0
        startComponents.second = 0
        
        let startDate = calendar.date(from: startComponents)!
        let endDate = calendar.date(byAdding: .hour, value: intervalHours, to: startDate)!
        
        return (startDate, endDate)
    }
    
    func intervalInSeconds() -> TimeInterval {
        return timeInterval * 3600 // Convert hours to seconds
    }
    
    func addCategory(name: String, color: Color, pointsPerMinute: Double) {
        let newCategory = Category(name: name, color: color, pointsPerMinute: pointsPerMinute, isDefault: false)
        categories.append(newCategory)
        saveCategories()
    }
    
    func removeCategory(_ category: Category) {
        categories.removeAll { $0.id == category.id }
        saveCategories()
    }
    
    func resetPoints() {
        // Will implement points reset functionality later
    }
    
    func calculatePoints(for card: LogCard) -> Int {
        var total = 0
        for (category, percentage) in card.categories {
            let minutes = timeInterval * 60 // Convert hours to minutes
            let points = Int(category.pointsPerMinute * minutes * (percentage / 100.0))
            total += points
        }
        return total
    }
    
    func calculateDailyPoints(for date: Date, from cards: [LogCard]) -> Int {
        let calendar = Calendar.current
        return cards
            .filter { calendar.isDate($0.startTime, inSameDayAs: date) && $0.isComplete }
            .reduce(0) { $0 + calculatePoints(for: $1) }
    }
    
    func calculateWeeklyPoints(from cards: [LogCard]) -> Int {
        let calendar = Calendar.current
        let today = Date()
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) else { return 0 }
        
        return cards
            .filter { $0.startTime >= weekAgo && $0.isComplete }
            .reduce(0) { $0 + calculatePoints(for: $1) }
    }
    
    func updateCategory(_ category: Category, name: String, color: Color, pointsPerMinute: Double) {
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = Category(
                id: category.id,
                name: name,
                color: color,
                pointsPerMinute: pointsPerMinute,
                isDefault: category.isDefault
            )
            saveCategories()
            objectWillChange.send()
        }
    }
    
    func savePoints(_ points: Int, for date: Date, categories: [Category: Double]) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        // Save total points
        dailyPoints[startOfDay, default: 0] += points
        
        // Save category points
        var categoryPointsForDay = categoryPoints[startOfDay] ?? [:]
        for (category, percentage) in categories {
            let categoryPoints = Int(Double(points) * percentage / 100.0)
            categoryPointsForDay[category, default: 0] += categoryPoints
        }
        categoryPoints[startOfDay] = categoryPointsForDay
        
        objectWillChange.send()
    }
    
    func getPoints(for date: Date) -> Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return dailyPoints[startOfDay] ?? 0
    }
    
    func getCategoryPoints(for date: Date) -> [(Category, Int)] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let pointsForDay = categoryPoints[startOfDay] ?? [:]
        return categories.map { category in
            (category, pointsForDay[category] ?? 0)
        }
    }
    
    private func saveCategories() {
        if let encoded = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(encoded, forKey: "savedCategories")
            UserDefaults.standard.synchronize() // Force save
        }
    }
    
    private func loadCategories() {
        if let savedCategories = UserDefaults.standard.data(forKey: "savedCategories"),
           let decoded = try? JSONDecoder().decode([Category].self, from: savedCategories) {
            categories = decoded
        } else {
            categories = Category.defaultCategories
        }
    }
    
    init() {
        loadCategories()
    }
} 