import SwiftUI

class SettingsManager: ObservableObject {
    @Published var timeInterval: Double
    @Published var categories: [Category]
    @Published private var dailyPoints: [Date: Int]
    @Published private var categoryPoints: [Date: [Category: Int]]
    
    let availableIntervals = [1.0, 2.0, 3.0, 4.0, 6.0, 12.0]
    
    // Create a struct to handle time slot encoding/decoding
    private struct TimeSlot: Codable {
        let start: Date
        let end: Date
        
        init(start: Date, end: Date) {
            self.start = start
            self.end = end
        }
    }
    
    @Published private var loggedTimeSlots: [TimeSlot] = []
    @Published private var completedCards: [LogCard] = []
    
    init() {
        // Initialize all stored properties first
        self.categories = []
        self.dailyPoints = [:]
        self.categoryPoints = [:]
        self.timeInterval = UserDefaults.standard.double(forKey: "timeInterval")
        
        // Set default time interval if needed
        if self.timeInterval == 0 {
            self.timeInterval = 3.0
            UserDefaults.standard.set(self.timeInterval, forKey: "timeInterval")
        }
        
        // Load saved data
        loadCategories()
        loadDailyPoints()
        loadCategoryPoints()
        loadLoggedTimeSlots()
        loadCompletedCards()
    }
    
    func getNextTimeSlot() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let intervalHours = Int(timeInterval)
        
        // Change to let since it's not mutated
        let nextSlotHour = ((currentHour / intervalHours) + 1) * intervalHours
        
        // If we're in the last slot of the day
        if nextSlotHour >= 24 {
            // Get tomorrow's first slot
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else {
                return now
            }
            var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
            components.hour = 0
            components.minute = 0
            components.second = 0
            return calendar.date(from: components) ?? now
        }
        
        // Get today's next slot
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = nextSlotHour
        components.minute = 0
        components.second = 0
        
        return calendar.date(from: components) ?? now
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
        
        // Return the slot if we're currently in it
        if now >= startDate && now < endDate {
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
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories.remove(at: index)
            
            // Update points data to remove the deleted category
            for (date, points) in categoryPoints {
                var updatedPoints = points
                updatedPoints.removeValue(forKey: category)
                categoryPoints[date] = updatedPoints
            }
            
            saveCategories()
            saveCategoryPoints()
            objectWillChange.send()
        }
    }
    
    func getActiveCategories() -> [Category] {
        let calendar = Calendar.current
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        
        return categories.filter { category in
            if let deletedDate = category.deletedDate {
                return deletedDate > oneWeekAgo
            }
            return true
        }
    }
    
    func resetPoints() {
        dailyPoints.removeAll()
        categoryPoints.removeAll()
        saveDailyPoints()
        saveCategoryPoints()
        objectWillChange.send()
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
    
    func updateCategory(_ category: Category) {
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
            saveCategories()
            objectWillChange.send()
        }
    }
    
    func addCategory(_ category: Category) {
        categories.append(category)
        saveCategories()
        objectWillChange.send()
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
    
    func isTimeSlotLogged(start: Date, end: Date) -> Bool {
        let calendar = Calendar.current
        return loggedTimeSlots.contains { slot in
            calendar.isDate(slot.start, inSameDayAs: start) &&
            slot.start <= end && slot.end >= start
        }
    }
    
    func logTimeSlot(start: Date, end: Date) {
        loggedTimeSlots.append(TimeSlot(start: start, end: end))
        // Clean up old entries (optional)
        let calendar = Calendar.current
        let oldestToKeep = calendar.date(byAdding: .day, value: -7, to: Date())!
        loggedTimeSlots = loggedTimeSlots.filter { $0.start >= oldestToKeep }
        saveLoggedTimeSlots()
    }
    
    func resetTodayPoints() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Remove today's points and completed cards
        dailyPoints.removeValue(forKey: today)
        categoryPoints.removeValue(forKey: today)
        completedCards.removeAll { card in
            calendar.isDateInToday(card.startTime)
        }
        
        // Remove today's logged time slots
        loggedTimeSlots = loggedTimeSlots.filter { slot in
            !calendar.isDateInToday(slot.start)
        }
        
        // Save all changes
        saveDailyPoints()
        saveCategoryPoints()
        saveLoggedTimeSlots()
        saveCompletedCards()
        objectWillChange.send()
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
    
    private func saveDailyPoints() {
        if let encoded = try? JSONEncoder().encode(dailyPoints) {
            UserDefaults.standard.set(encoded, forKey: "dailyPoints")
        }
    }
    
    private func loadDailyPoints() {
        if let saved = UserDefaults.standard.data(forKey: "dailyPoints"),
           let decoded = try? JSONDecoder().decode([Date: Int].self, from: saved) {
            dailyPoints = decoded
        }
    }
    
    private func saveCategoryPoints() {
        if let encoded = try? JSONEncoder().encode(categoryPoints) {
            UserDefaults.standard.set(encoded, forKey: "categoryPoints")
        }
    }
    
    private func loadCategoryPoints() {
        if let saved = UserDefaults.standard.data(forKey: "categoryPoints"),
           let decoded = try? JSONDecoder().decode([Date: [Category: Int]].self, from: saved) {
            categoryPoints = decoded
        }
    }
    
    private func loadLoggedTimeSlots() {
        if let data = UserDefaults.standard.data(forKey: "loggedTimeSlots"),
           let decoded = try? JSONDecoder().decode([TimeSlot].self, from: data) {
            loggedTimeSlots = decoded
        }
    }
    
    private func saveLoggedTimeSlots() {
        if let encoded = try? JSONEncoder().encode(loggedTimeSlots) {
            UserDefaults.standard.set(encoded, forKey: "loggedTimeSlots")
        }
    }
    
    private func loadCompletedCards() {
        if let data = UserDefaults.standard.data(forKey: "completedCards"),
           let decoded = try? JSONDecoder().decode([LogCard].self, from: data) {
            completedCards = decoded
        }
    }
    
    private func saveCompletedCards() {
        if let encoded = try? JSONEncoder().encode(completedCards) {
            UserDefaults.standard.set(encoded, forKey: "completedCards")
        }
    }
    
    func addCompletedCard(_ card: LogCard) {
        completedCards.append(card)
        saveCompletedCards()
    }
    
    func getCompletedCards(for date: Date) -> [LogCard] {
        let calendar = Calendar.current
        return completedCards.filter { card in
            calendar.isDate(card.startTime, inSameDayAs: date)
        }
    }
    
    func getAllCompletedCards() -> [LogCard] {
        return completedCards.sorted { $0.startTime > $1.startTime }
    }
} 