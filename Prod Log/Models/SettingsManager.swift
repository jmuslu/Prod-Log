import SwiftUI
import UserNotifications

class SettingsManager: ObservableObject {
    @Published var timeInterval: Double = 3.0 {  // Default value
        didSet {
            UserDefaults.standard.set(timeInterval, forKey: "timeInterval")
            if notificationsEnabled {
                scheduleNextNotification()  // Reschedule when interval changes
            }
        }
    }
    @Published var use24HourTime: Bool = false {
        didSet {
            UserDefaults.standard.set(use24HourTime, forKey: "use24HourTime")
        }
    }
    @Published var categories: [Category] = []
    @Published private var dailyPoints: [Date: Int] = [:]
    @Published private var categoryPoints: [Date: [String: Int]] = [:]
    
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
        Category(name: "Commute", color: .red, pointsPerMinute: 5, isDefault: true)
    ]
    
    @Published var notificationsEnabled: Bool = false {
        didSet {
            DispatchQueue.main.async {
                UserDefaults.standard.set(self.notificationsEnabled, forKey: "notificationsEnabled")
                
                if self.notificationsEnabled {
                    self.scheduleNextNotification()
                } else {
                    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                }
            }
        }
    }
    @Published var notificationMode: NotificationMode = .single {
        didSet {
            UserDefaults.standard.set(notificationMode.rawValue, forKey: "notificationMode")
        }
    }
    
    public enum NotificationMode: String, CaseIterable {
        case single = "single"    // Only one notification until app is opened
        case every = "every"      // Notification for every card
    }
    
    init() {
        // Load saved settings
        timeInterval = UserDefaults.standard.double(forKey: "timeInterval")
        if timeInterval == 0 { timeInterval = 6.0 } // Changed default to 6.0
        
        use24HourTime = UserDefaults.standard.bool(forKey: "use24HourTime")
        notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        
        if let mode = UserDefaults.standard.string(forKey: "notificationMode") {
            notificationMode = NotificationMode(rawValue: mode) ?? .single
        }
        
        // Load categories first
        loadCategories()
        
        // If no categories exist, set defaults BEFORE loading other data
        if categories.isEmpty {
            categories = Category.defaultCategories
            saveCategories() // Save immediately
        }
        
        // Then load the rest of the data
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
                .filter { $0.startTime >= calendar.startOfDay(for: now) } // Only consider today's cards
                .map { (start: $0.startTime, end: $0.endTime) }
            
            // First, check if we're currently in a time slot
            if let currentSlot = getCurrentTimeSlot() {
                // If we're in a slot, the next slot should start at the end of the current one
                return currentSlot.end
            }
            
            // If we're not in a slot, find the next clean hour boundary
            let nextHour = calendar.date(
                bySetting: .minute,
                value: 0,
                of: calendar.date(byAdding: .hour, value: 1, to: now) ?? now
            ) ?? now
            
            return nextHour
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
        
        DispatchQueue.main.async {
            // Update daily points
            self.dailyPoints[startOfDay] = (self.dailyPoints[startOfDay] ?? 0) + points
            
            // Update category points
            var updatedCategoryPoints = self.categoryPoints[startOfDay] ?? [:]
            var totalPercentage: Double = categories.values.reduce(0, +)
            var remainingPoints = points
            
            // Sort categories for consistent distribution
            let sortedCategories = categories.sorted { $0.key.name < $1.key.name }
            
            // Handle all but the last category
            for (index, (category, percentage)) in sortedCategories.enumerated() {
                if index == sortedCategories.count - 1 {
                    // Last category gets remaining points to avoid rounding errors
                    updatedCategoryPoints[category.name] = (updatedCategoryPoints[category.name] ?? 0) + remainingPoints
                } else {
                    // Calculate exact points based on percentage
                    let exactPoints = Int(round(Double(points) * (percentage / totalPercentage)))
                    updatedCategoryPoints[category.name] = (updatedCategoryPoints[category.name] ?? 0) + exactPoints
                    remainingPoints -= exactPoints
                }
            }
            
            self.categoryPoints[startOfDay] = updatedCategoryPoints
            self.saveDailyPoints()
            self.saveCategoryPoints()
            self.objectWillChange.send()
        }
    }
    
    func getPoints(for date: Date) -> Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return dailyPoints[startOfDay] ?? 0
    }
    
    func getDetailedPoints(for date: Date) -> (daily: Int, category: [String: Int]) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return (
            daily: dailyPoints[startOfDay] ?? 0,
            category: categoryPoints[startOfDay] ?? [:]
        )
    }
    
    func getCategoryPoints(for date: Date) -> [(Category, Int)] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let pointsDict = categoryPoints[startOfDay] ?? [:]
        
        // Convert string-based dictionary to array of category-point pairs
        return categories
            .filter { category in
                // Only include active categories or recently deleted ones
                if let deletedDate = category.deletedDate {
                    return deletedDate > date
                }
                return true
            }
            .compactMap { category in
                if let points = pointsDict[category.name] {
                    return (category, points)
                }
                return nil
            }
    }
    
    private func getCategoryPointsDict(for date: Date) -> [String: Int] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return categoryPoints[startOfDay] ?? [:]
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
        let fortyEightHoursAgo = calendar.date(byAdding: .hour, value: -48, to: now)!
        
        // Remove points and completed cards for the entire 48-hour window
        let startOfWindow = calendar.startOfDay(for: fortyEightHoursAgo)
        
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
            card.startTime >= fortyEightHoursAgo
        }
        
        // Remove logged time slots within the window
        loggedTimeSlots = loggedTimeSlots.filter { slot in
            slot.start < fortyEightHoursAgo
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
        if let data = try? JSONEncoder().encode(dailyPoints) {
            UserDefaults.standard.set(data, forKey: "dailyPoints")
        }
    }
    
    private func loadDailyPoints() {
        if let saved = UserDefaults.standard.data(forKey: "dailyPoints"),
           let decoded = try? JSONDecoder().decode([Date: Int].self, from: saved) {
            dailyPoints = decoded
        }
    }
    
    private func saveCategoryPoints() {
        if let data = try? JSONEncoder().encode(categoryPoints) {
            UserDefaults.standard.set(data, forKey: "categoryPoints")
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
        if let data = UserDefaults.standard.data(forKey: "completedCards") {
            do {
                let decoder = JSONDecoder()
                completedCards = try decoder.decode([LogCard].self, from: data)
                completedCards = sortCompletedCards(completedCards)
            } catch {
                print("Error decoding completed cards: \(error)")
                completedCards = []
            }
        }
    }
    
    private func saveCompletedCards() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(completedCards)
            UserDefaults.standard.set(data, forKey: "completedCards")
        } catch {
            print("Error encoding completed cards: \(error)")
        }
    }
    
    private func sortCompletedCards(_ cards: [LogCard]) -> [LogCard] {
        // Always sort most recent first
        cards.sorted { first, second in
            first.startTime > second.startTime
        }
    }
    
    func addCompletedCard(_ card: LogCard) {
        // Remove any existing cards that overlap with this one
        completedCards.removeAll { existingCard in
            let overlap = !(card.endTime <= existingCard.startTime || card.startTime >= existingCard.endTime)
            return overlap
        }
        
        completedCards.append(card)
        completedCards = sortCompletedCards(completedCards)
        saveCompletedCards()
        
        // Add to logged time slots
        let timeSlot = TimeSlot(start: card.startTime, end: card.endTime)
        loggedTimeSlots.append(timeSlot)
        saveLoggedTimeSlots()
        
        // Schedule next notification if enabled
        if notificationsEnabled {
            scheduleNextNotification()
        }
        
        // Notify observers of the change
        objectWillChange.send()
    }
    
    func getCompletedCards(for date: Date) -> [LogCard] {
        let calendar = Calendar.current
        return completedCards.filter { card in
            calendar.isDate(card.startTime, inSameDayAs: date)
        }
    }
    
    func getAllCompletedCards() -> [LogCard] {
        return sortCompletedCards(completedCards)
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
                
                // Only add the card if it's a valid time slot
                if endTime > currentTime && endTime <= now {
                    // Check if this slot would be valid
                    if !isTimeSlotOverlapping(start: currentTime, end: endTime, completedSlots: completedTimeSlots) {
                        newCards.append(LogCard(startTime: currentTime, endTime: endTime))
                    }
                }
                currentTime = endTime
            } else {
                // Fixed interval mode remains unchanged
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
        
        // Find any existing completed slots that start at our start time
        let existingSlots = completedSlots.filter { slot in
            calendar.isDate(slot.start, equalTo: roundedStartTime, toGranularity: .hour)
        }
        
        if !existingSlots.isEmpty {
            // If we have existing slots, use their end time as our constraint
            let latestEnd = existingSlots.map { $0.end }.max()!
            return latestEnd
        }
        
        // Check each possible interval
        for intervalHours in possibleIntervals {
            let potentialEndTime = calendar.date(byAdding: .hour, value: intervalHours, to: roundedStartTime)!
            
            // Don't go beyond the current time for historical slots
            if potentialEndTime > now {
                continue
            }
            
            // Check if this interval would overlap with any completed slots
            let wouldOverlap = completedSlots.contains { slot in
                // Exclude exact matches at start or end
                if calendar.isDate(slot.start, equalTo: roundedStartTime, toGranularity: .hour) ||
                   calendar.isDate(slot.end, equalTo: potentialEndTime, toGranularity: .hour) {
                    return false
                }
                // Check for any other overlap
                return !(potentialEndTime <= slot.start || roundedStartTime >= slot.end)
            }
            
            if !wouldOverlap {
                return potentialEndTime
            }
        }
        
        // If no larger interval works, find the next completed slot
        let nextCompletedSlot = completedSlots
            .filter { $0.start > roundedStartTime }
            .min(by: { $0.start < $1.start })
        
        if let nextSlot = nextCompletedSlot {
            return nextSlot.start
        }
        
        // If nothing else works, return one hour from the start time
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
    
    func requestNotificationPermissions() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    DispatchQueue.main.async {
                        if granted {
                            self.notificationsEnabled = true
                            self.scheduleNextNotification()
                        } else {
                            self.notificationsEnabled = false
                        }
                    }
                }
            case .authorized:
                DispatchQueue.main.async {
                    if self.notificationsEnabled {
                        self.scheduleNextNotification()
                    }
                }
            case .denied:
                DispatchQueue.main.async {
                    self.notificationsEnabled = false
                }
            default:
                DispatchQueue.main.async {
                    self.notificationsEnabled = false
                }
            }
        }
    }
    
    func scheduleNextNotification() {
        guard notificationsEnabled else {
            print("DEBUG: Notifications are disabled")
            return 
        }
        
        // Remove existing notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        let nextSlot = getNextTimeSlot()
        let now = Date()
        
        // Only schedule if the next slot is in the future
        guard nextSlot > now else {
            print("DEBUG: Next slot (\(formatTimeRange(start: nextSlot, end: nextSlot))) is in the past")
            return
        }
        
        print("DEBUG: Scheduling notification for next time slot: \(formatTimeRange(start: nextSlot, end: nextSlot))")
        
        let content = UNMutableNotificationContent()
        content.title = "Time to Log Your Activities"
        content.body = "A new time slot is available for logging: \(formatTime(nextSlot))"
        content.sound = .default
        
        // Create trigger for exactly at the next slot time
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: nextSlot)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "logReminder-\(nextSlot.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("DEBUG: Error scheduling card notification for \(self.formatTime(nextSlot)): \(error)")
            } else {
                print("DEBUG: Successfully scheduled card notification for \(self.formatTime(nextSlot))")
            }
        }
        
        // If notification mode is set to 'every', schedule the next one too
        if notificationMode == .every {
            let futureSlot = getNextTimeSlot(after: nextSlot)
            if futureSlot > nextSlot {
                print("DEBUG: Also scheduling future notification for: \(formatTime(futureSlot))")
                let futureContent = UNMutableNotificationContent()
                futureContent.title = "Time to Log Your Activities"
                futureContent.body = "A new time slot is available for logging: \(formatTime(futureSlot))"
                futureContent.sound = .default
                
                let futureComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: futureSlot)
                let futureTrigger = UNCalendarNotificationTrigger(dateMatching: futureComponents, repeats: false)
                
                let futureRequest = UNNotificationRequest(
                    identifier: "logReminder-\(futureSlot.timeIntervalSince1970)",
                    content: futureContent,
                    trigger: futureTrigger
                )
                
                UNUserNotificationCenter.current().add(futureRequest) { error in
                    if let error = error {
                        print("DEBUG: Error scheduling future card notification for \(self.formatTime(futureSlot)): \(error)")
                    } else {
                        print("DEBUG: Successfully scheduled future card notification for \(self.formatTime(futureSlot))")
                    }
                }
            }
        }
    }
    
    // Helper function to get the next time slot after a specific date
    private func getNextTimeSlot(after date: Date) -> Date {
        let calendar = Calendar.current
        if timeInterval == Self.autoInterval {
            return calendar.date(byAdding: .hour, value: 1, to: date) ?? date
        } else {
            let intervalHours = Int(timeInterval)
            return calendar.date(byAdding: .hour, value: intervalHours, to: date) ?? date
        }
    }
    
    // Add a function to toggle notifications
    func toggleNotifications() {
        if notificationsEnabled {
            // Turning off notifications
            notificationsEnabled = false
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        } else {
            // Turning on notifications
            requestNotificationPermissions()
        }
    }
    
    func sendTestNotification() {
        print("DEBUG: Attempting to send test notification")
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "This is a test notification (should appear in 5 seconds)"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "testNotification-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("DEBUG: Error sending test notification: \(error)")
            } else {
                print("DEBUG: Test notification scheduled successfully")
            }
        }
    }
} 