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
                
                // Current and upcoming time slots
                Section(header: Text("Current & Upcoming")) {
                    ForEach(incompletedCards) { card in
                        if isCardInCurrentOrFutureSlot(card) {
                            LogCardView(card: card)
                                .onTapGesture {
                                    selectedCard = card
                                    showingCategorySheet = true
                                }
                        }
                    }
                }
                
                if !completedCards.isEmpty {
                    Section("Completed") {
                        ForEach(completedCards) { card in
                            LogCardView(card: card)
                        }
                    }
                }
            }
            .navigationTitle("Activity Log")
            .sheet(isPresented: $showingCategorySheet) {
                if let card = selectedCard {
                    CategorySelectionView(card: card, logCards: $logCards)
                }
            }
            .onReceive(displayTimer) { _ in
                updateTimerDisplay()
            }
        }
        .onAppear {
            startLogging()
            updateTimerDisplay()
        }
        .onDisappear {
            cardTimer?.invalidate()
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
                return calendar.isDateInToday(card.startTime)
            }
            .sorted { $0.startTime < $1.startTime }
    }
    
    private var completedCards: [LogCard] {
        logCards
            .filter { $0.isComplete }
            .sorted { $0.startTime > $1.startTime }
    }
    
    private func isCardInCurrentOrFutureSlot(_ card: LogCard) -> Bool {
        let now = Date()
        return card.endTime > now
    }
    
    private func saveCard(_ card: LogCard) {
        if let index = logCards.firstIndex(where: { $0.id == card.id }) {
            logCards[index] = card
            // Remove the card from view if it's complete
            if card.isComplete {
                startLogging() // Refresh the card list
            }
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
        
        // Keep completed cards
        let completedCards = logCards.filter { $0.isComplete }
        
        // Generate all time slots for today
        var newCards: [LogCard] = []
        let intervalHours = Int(settingsManager.timeInterval)
        
        for hour in stride(from: 0, to: 24, by: intervalHours) {
            var startComponents = calendar.dateComponents([.year, .month, .day], from: startOfDay)
            startComponents.hour = hour
            let startDate = calendar.date(from: startComponents)!
            let endDate = calendar.date(byAdding: .hour, value: intervalHours, to: startDate)!
            
            // Add cards for all time slots that haven't been completed
            if !completedCards.contains(where: { card in
                calendar.isDate(card.startTime, inSameDayAs: startDate) &&
                calendar.compare(card.startTime, to: startDate, toGranularity: .hour) == .orderedSame
            }) {
                let newCard = LogCard(startTime: startDate, endTime: endDate)
                newCards.append(newCard)
            }
        }
        
        // Add all cards in chronological order
        logCards = (completedCards + newCards).sorted { $0.startTime > $1.startTime }
        
        // Schedule next card
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