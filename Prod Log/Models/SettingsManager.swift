import SwiftUI

class SettingsManager: ObservableObject {
    @Published var timeInterval: Double {
        didSet {
            UserDefaults.standard.set(timeInterval, forKey: "timeInterval")
        }
    }
    @Published var use24HourTime: Bool {
        didSet {
            UserDefaults.standard.set(use24HourTime, forKey: "use24HourTime")
        }
    }
    @Published var categories: [Category]
    @Published private var dailyPoints: [Date: Int] {
        didSet {
            saveDailyPoints()
        }
    }
    @Published private var categoryPoints: [Date: [String: Int]] {
        didSet {
            saveCategoryPoints()
        }
    }
    
    static let autoInterval: Double = -1  // Special value to indicate auto mode
    let availableIntervals = [-1.0, 1.0, 2.0, 3.0, 4.0, 6.0, 12.0]  // Add auto option (-1)
    
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
    
    static let defaultCategories = [
        Category(name: "Sleep", color: .blue, pointsPerMinute: 5, isDefault: true),
        Category(name: "Work", color: .green, pointsPerMinute: 5, isDefault: true),
        Category(name: "Physical Activity", color: .orange, pointsPerMinute: 5, isDefault: true),
        Category(name: "Relax", color: .purple, pointsPerMinute: 5, isDefault: true),
        Category(name: "Learning", color: .red, pointsPerMinute: 5, isDefault: true)
    ]
    
    init() {
        self.categories = []
        self.dailyPoints = [:]
        self.categoryPoints = [:]
        self.timeInterval = UserDefaults.standard.double(forKey: "timeInterval")
        self.use24HourTime = UserDefaults.standard.bool(forKey: "use24HourTime")
        
        if self.timeInterval == 0 {
            self.timeInterval = 3.0
            UserDefaults.standard.set(self.timeInterval, forKey: "timeInterval")
        }
        
        loadCategories()
        loadDailyPoints()
        loadCategoryPoints()
        loadLoggedTimeSlots()
        loadCompletedCards()
    }
    
    func getNextTimeSlot() -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        if timeInterval == Self.autoInterval {
            // For auto mode, find the next possible interval
            let completedTimeSlots = getAllCompletedCards()
                .map { (start: $0.startTime, end: $0.endTime) }
            
            // Find the next possible interval from now
            let nextPossibleEnd = findLargestPossibleInterval(from: now, completedSlots: completedTimeSlots, now: now.addingTimeInterval(3600))
            return nextPossibleEnd
        } else {
            // Original fixed interval logic
            let currentHour = calendar.component(.hour, from: now)
            let intervalHours = Int(timeInterval)
            let nextSlotHour = ((currentHour / intervalHours) + 1) * intervalHours
            
            if nextSlotHour >= 24 {
                guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else {
                    return now
                }
                var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                components.hour = 0
                components.minute = 0
                components.second = 0
                return calendar.date(from: components) ?? now
            }
            
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = nextSlotHour
            components.minute = 0
            components.second = 0
            
            return calendar.date(from: components) ?? now
        }
    }
    
    func getCurrentTimeSlot() -> (start: Date, end: Date)? {
        let calendar = Calendar.current
        let now = Date()
        
        if timeInterval == Self.autoInterval {
            // For auto mode, find the current slot by looking at generated cards
            let cards = generateLogCards()
            return cards.first { card in
                now >= card.startTime && now < card.endTime
            }.map { ($0.startTime, $0.endTime) }
        } else {
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
                updatedPoints.removeValue(forKey: category.name)
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
        let duration = card.endTime.timeIntervalSince(card.startTime) / 60.0 // Duration in minutes
        
        var totalPoints = 0
        for (category, percentage) in card.categories {
            let categoryMinutes = duration * (percentage / 100.0)
            let categoryPoints = Int(categoryMinutes * category.pointsPerMinute)
            totalPoints += categoryPoints
        }
        
        return max(0, totalPoints) // Ensure we never return negative points
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
            
            // Update points data with the new category
            for (date, points) in categoryPoints {
                if let value = points[category.name] {
                    var updatedPoints = points
                    updatedPoints.removeValue(forKey: category.name)
                    updatedPoints[category.name] = value
                    categoryPoints[date] = updatedPoints
                }
            }
            
            saveCategories()
            saveCategoryPoints()
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
        
        // Add points to daily total
        dailyPoints[startOfDay, default: 0] += points
        
        // Add points to category totals
        var dayCategories = categoryPoints[startOfDay] ?? [:]
        for (category, percentage) in categories {
            let categoryPoints = Int(Double(points) * (percentage / 100.0))
            dayCategories[category.name, default: 0] += categoryPoints
        }
        categoryPoints[startOfDay] = dayCategories
        
        saveDailyPoints()
        saveCategoryPoints()
        objectWillChange.send()
    }
    
    func getPoints(for date: Date) -> Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return dailyPoints[startOfDay] ?? 0
    }
    
    func getCategoryPoints(for date: Date) -> [Category: Int] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let stringPoints = categoryPoints[startOfDay] ?? [:]
        
        var result: [Category: Int] = [:]
        for category in categories {
            if let points = stringPoints[category.name] {
                result[category] = points
            }
        }
        return result
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
        let now = Date()
        let thirtySixHoursAgo = calendar.date(byAdding: .hour, value: -36, to: now)!
        
        // Remove points and completed cards for the entire 36-hour window
        let startOfWindow = calendar.startOfDay(for: thirtySixHoursAgo)
        
        // Clear points for all affected days
        var currentDate = startOfWindow
        while currentDate <= now {
            let dayStart = calendar.startOfDay(for: currentDate)
            dailyPoints.removeValue(forKey: dayStart)
            categoryPoints.removeValue(forKey: dayStart)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        // Clear completed cards within the window
        completedCards.removeAll { card in
            card.startTime >= thirtySixHoursAgo
        }
        
        // Remove logged time slots within the window
        loggedTimeSlots = loggedTimeSlots.filter { slot in
            slot.start < thirtySixHoursAgo
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
           let decoded = try? JSONDecoder().decode([Date: [String: Int]].self, from: saved) {
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
        // Remove any existing cards that overlap with this one
        completedCards.removeAll { existingCard in
            let overlap = !(card.endTime <= existingCard.startTime || card.startTime >= existingCard.endTime)
            return overlap
        }
        
        // Add the new card
        completedCards.append(card)
        
        // Sort cards by start time
        completedCards.sort { $0.startTime > $1.startTime }
        
        // Save to UserDefaults
        saveCompletedCards()
        
        // Add to logged time slots
        let timeSlot = TimeSlot(start: card.startTime, end: card.endTime)
        loggedTimeSlots.append(timeSlot)
        saveLoggedTimeSlots()
        
        objectWillChange.send()
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
    
    func clearCompletedCards(since date: Date) {
        // Remove completed cards that are newer than the given date
        completedCards = completedCards.filter { $0.startTime < date }
        
        // Also clear points for this period
        let calendar = Calendar.current
        let now = Date()
        
        // Clear points for each day in the range
        var currentDate = date
        while currentDate <= now {
            if let points = dailyPoints[calendar.startOfDay(for: currentDate)] {
                dailyPoints[calendar.startOfDay(for: currentDate)] = 0
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? now
        }
        
        saveCompletedCards()
        saveDailyPoints()
    }
    
    func resetToDefaultCategories() {
        categories = Self.defaultCategories
        saveCategories()
        objectWillChange.send()
    }
    
    func generateLogCards() -> [LogCard] {
        let calendar = Calendar.current
        let now = Date()
        
        // Calculate yesterday's noon (12 PM)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let yesterdayNoon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: yesterday)!
        
        // Get completed cards since yesterday noon
        let completedTimeSlots = getAllCompletedCards()
            .filter { $0.startTime >= yesterdayNoon }
            .map { (start: $0.startTime, end: $0.endTime) }
        
        // Generate new cards for elapsed time slots
        var newCards: [LogCard] = []
        var currentTime = yesterdayNoon
        
        while currentTime <= now {
            if timeInterval == Self.autoInterval {
                // Auto mode: Find the largest possible interval
                let endTime = findLargestPossibleInterval(from: currentTime, completedSlots: completedTimeSlots, now: now)
                if endTime <= now && !isTimeSlotOverlapping(start: currentTime, end: endTime, completedSlots: completedTimeSlots) {
                    newCards.append(LogCard(startTime: currentTime, endTime: endTime))
                }
                currentTime = endTime
            } else {
                // Fixed interval mode (simplified)
                let intervalHours = Int(timeInterval)
                let endTime = calendar.date(byAdding: .hour, value: intervalHours, to: currentTime)!
                
                if endTime <= now && !isTimeSlotOverlapping(start: currentTime, end: endTime, completedSlots: completedTimeSlots) {
                    newCards.append(LogCard(startTime: currentTime, endTime: endTime))
                }
                currentTime = endTime
            }
        }
        
        return newCards.sorted { $0.startTime > $1.startTime }
    }
    
    private func findLargestPossibleInterval(from startTime: Date, completedSlots: [(start: Date, end: Date)], now: Date) -> Date {
        let calendar = Calendar.current
        let possibleIntervals = [12, 8, 6, 4, 3, 2, 1]
        
        // Ensure we're working with clean hour boundaries
        let roundedStartTime = calendar.date(bySetting: .minute, value: 0, of: startTime)!
        
        for intervalHours in possibleIntervals {
            let potentialEndTime = calendar.date(byAdding: .hour, value: intervalHours, to: roundedStartTime)!
            
            if !isTimeSlotOverlapping(start: roundedStartTime, end: potentialEndTime, completedSlots: completedSlots) && potentialEndTime <= now {
                return potentialEndTime
            }
        }
        
        // If no larger interval works, return one hour from the start time
        return calendar.date(byAdding: .hour, value: 1, to: roundedStartTime)!
    }
    
    private func isTimeSlotOverlapping(start: Date, end: Date, completedSlots: [(start: Date, end: Date)]) -> Bool {
        return completedSlots.contains { completedSlot in
            let slotStart = completedSlot.start
            let slotEnd = completedSlot.end
            return !(end <= slotStart || start >= slotEnd)
        }
    }
    
    func getTimeFormatString() -> String {
        return use24HourTime ? "HH:mm" : "h:mm a"
    }
    
    func formatTimeRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = getTimeFormatString()
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
    
    // Add a helper method for formatting single times
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = getTimeFormatString()
        return formatter.string(from: date)
    }
} 