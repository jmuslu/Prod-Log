import SwiftUI

struct LoggerView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var logCards: [LogCard] = []
    @State private var selectedCard: LogCard?
    @State private var showingCategorySheet = false
    @State private var cardTimer: Timer?
    @State private var nextCardDate: Date?
    @State private var timerString: String = ""
    private let displayTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Text("Next card in:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(timerString)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                }
                
                // Available time slots
                if !incompletedCards.isEmpty {
                    Section(header: Text("Available Time Slots")) {
                        ForEach(incompletedCards) { card in
                            LogCardView(card: card)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedCard = card
                                    showingCategorySheet = true
                                }
                        }
                    }
                }
                
                // Completed cards inline with transparency
                if !completedCards.isEmpty {
                    Section(header: Text("Completed")) {
                        ForEach(completedCards) { card in
                            CompletedLogCardView(card: card)
                                .opacity(0.7)
                        }
                    }
                }
            }
            .navigationTitle("Logger")
        }
        .sheet(isPresented: $showingCategorySheet) {
            if let card = selectedCard {
                CategorySelectionView(card: card, logCards: $logCards)
            }
        }
        .onAppear {
            startLogging()
            updateTimerDisplay()
        }
        .onReceive(displayTimer) { _ in
            updateTimerDisplay()
        }
        .onDisappear {
            cardTimer?.invalidate()
        }
        .onChange(of: settingsManager.timeInterval) { _ in
            restartLogging()
        }
        .onReceive(NotificationCenter.default.publisher(for: .resetLogCards)) { _ in
            handleReset()
        }
    }
    
    private var incompletedCards: [LogCard] {
        let now = Date()
        let calendar = Calendar.current
        let thirtySixHoursAgo = calendar.date(byAdding: .hour, value: -36, to: now)!
        
        return logCards
            .filter { !$0.isComplete }
            .filter { card in
                return card.startTime >= thirtySixHoursAgo && 
                       card.endTime <= now // Only show completely elapsed time slots
            }
            .sorted { $0.startTime < $1.startTime }
    }
    
    private var completedCards: [LogCard] {
        let calendar = Calendar.current
        let now = Date()
        let thirtySixHoursAgo = calendar.date(byAdding: .hour, value: -36, to: now)!
        
        return settingsManager.getAllCompletedCards()
            .filter { $0.startTime >= thirtySixHoursAgo }
            .sorted { $0.startTime > $1.startTime }
    }
    
    private func isCardInCurrentOrFutureSlot(_ card: LogCard) -> Bool {
        let now = Date()
        return card.endTime > now
    }
    
    private func saveCard(_ card: LogCard) {
        if let index = logCards.firstIndex(where: { $0.id == card.id }) {
            var updatedCard = card
            updatedCard.isComplete = true
            
            // Add to completed cards in SettingsManager
            settingsManager.addCompletedCard(updatedCard)
            
            // Remove from active cards
            logCards.remove(at: index)
            
            // Refresh the card list to update available slots
            startLogging()
        }
    }
    
    private func updateTimerDisplay() {
        guard let nextDate = nextCardDate else {
            timerString = "No upcoming cards"
            return
        }
        
        let interval = nextDate.timeIntervalSinceNow
        if interval <= 0 {
            startLogging() // Refresh if we've passed the next card time
            return
        }
        
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        
        if hours > 0 {
            timerString = String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            timerString = String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func startLogging() {
        let calendar = Calendar.current
        let now = Date()
        
        // Calculate yesterday's noon (12 PM)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let yesterdayNoon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: yesterday)!
        
        // Get completed cards since yesterday noon
        let completedTimeSlots = settingsManager.getAllCompletedCards()
            .filter { $0.startTime >= yesterdayNoon }
            .map { (start: $0.startTime, end: $0.endTime) }
        
        // Generate new cards for elapsed time slots
        var newCards: [LogCard] = []
        let intervalHours = Int(settingsManager.timeInterval)
        
        // Start from yesterday noon
        var currentTime = yesterdayNoon
        
        while currentTime <= now {
            let endTime = calendar.date(byAdding: .hour, value: intervalHours, to: currentTime)!
            
            // Only create cards for elapsed time slots
            if endTime <= now {
                // Check if this time slot overlaps with any completed cards
                let isTimeSlotCompleted = completedTimeSlots.contains { completedSlot in
                    let slotStart = completedSlot.start
                    let slotEnd = completedSlot.end
                    return !(endTime <= slotStart || currentTime >= slotEnd)
                }
                
                if !isTimeSlotCompleted {
                    let newCard = LogCard(startTime: currentTime, endTime: endTime)
                    newCards.append(newCard)
                }
            }
            
            currentTime = endTime
        }
        
        // Update the cards list
        logCards = newCards.sorted { $0.startTime > $1.startTime }
        
        scheduleNextCard()
    }
    
    private func scheduleNextCard() {
        let nextSlot = settingsManager.getNextTimeSlot()
        nextCardDate = nextSlot
        
        cardTimer?.invalidate()
        cardTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            updateTimerDisplay()
        }
    }
    
    private func restartLogging() {
        cardTimer?.invalidate()
        startLogging()
        updateTimerDisplay()
    }
    
    private func handleReset() {
        let calendar = Calendar.current
        let now = Date()
        let thirtySixHoursAgo = calendar.date(byAdding: .hour, value: -36, to: now)!
        
        // Clear all completed cards from the last 36 hours
        settingsManager.clearCompletedCards(since: thirtySixHoursAgo)
        
        // Regenerate all cards for the last 36 hours
        startLogging()
    }
}

// Add a new view for completed cards
struct CompletedLogCardView: View {
    let card: LogCard
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(timeText)
                    .font(.headline)
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            
            ForEach(Array(card.categories.keys.sorted(by: { $0.name < $1.name })), id: \.id) { category in
                if let percentage = card.categories[category] {
                    HStack {
                        Circle()
                            .fill(category.color)
                            .frame(width: 12, height: 12)
                        Text(category.name)
                        Spacer()
                        Text("\(Int(percentage))%")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var timeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: card.startTime)) - \(formatter.string(from: card.endTime))"
    }
} 