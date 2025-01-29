import SwiftUI

struct LoggerView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var logCards: [LogCard] = []
    @State private var selectedCard: LogCard?
    @State private var showingCategorySheet = false
    @State private var cardTimer: Timer?
    @State private var nextCardDate: Date?
    @State private var timerString: String = ""
    
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
                
                // Completed cards inline
                if !completedCards.isEmpty {
                    Section(header: Text("Completed")) {
                        ForEach(completedCards) { card in
                            CompletedLogCardView(card: card)
                                .opacity(0.7) // Make completed cards slightly transparent
                        }
                    }
                }
            }
            .navigationTitle("Logger")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        startLogging()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showingCategorySheet) {
                if let card = selectedCard {
                    CategorySelectionView(card: card, logCards: $logCards)
                }
            }
        }
        .onAppear {
            startLogging()
            updateTimerDisplay()
            
            // Add observer for reset notification
            NotificationCenter.default.addObserver(
                forName: .resetLogCards,
                object: nil,
                queue: .main
            ) { _ in
                restartLogging()
            }
        }
        .onDisappear {
            cardTimer?.invalidate()
            // Remove observer
            NotificationCenter.default.removeObserver(self)
        }
        .onChange(of: settingsManager.timeInterval) { _ in
            restartLogging()
        }
    }
    
    private var incompletedCards: [LogCard] {
        let now = Date()
        return logCards
            .filter { !$0.isComplete }
            .filter { card in
                let calendar = Calendar.current
                return calendar.isDateInToday(card.startTime) && 
                       card.endTime <= now // Only show completely elapsed time slots
            }
            .sorted { $0.startTime < $1.startTime }
    }
    
    private var completedCards: [LogCard] {
        let calendar = Calendar.current
        return settingsManager.getCompletedCards(for: Date())
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
        let startOfDay = calendar.startOfDay(for: now)
        
        // Keep completed cards in memory but mark them as reset if needed
        let completedCards = logCards.filter { $0.isComplete }
        
        // Generate new cards for elapsed time slots
        var newCards: [LogCard] = []
        let intervalHours = Int(settingsManager.timeInterval)
        
        for hour in stride(from: 0, to: 24, by: intervalHours) {
            var startComponents = calendar.dateComponents([.year, .month, .day], from: startOfDay)
            startComponents.hour = hour
            let startDate = calendar.date(from: startComponents)!
            let endDate = calendar.date(byAdding: .hour, value: intervalHours, to: startDate)!
            
            if endDate <= now {
                let newCard = LogCard(startTime: startDate, endTime: endDate)
                newCards.append(newCard)
            }
        }
        
        // Update the cards list
        logCards = (completedCards + newCards)
            .sorted { $0.startTime > $1.startTime }
        
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