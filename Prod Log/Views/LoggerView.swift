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
                if logCards.isEmpty {
                    Text("Waiting for next log card...")
                        .foregroundColor(.secondary)
                } else {
                    if nextCardDate != nil {
                        TimerRowView(timerString: timerString)
                    }
                    
                    ForEach(logCards.filter { !$0.isComplete }) { card in
                        LogCardView(card: card)
                            .onTapGesture {
                                selectedCard = card
                                showingCategorySheet = true
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
        }
        .onDisappear {
            cardTimer?.invalidate()
        }
        .onChange(of: settingsManager.timeInterval) { _ in
            restartLogging()
        }
    }
    
    private func updateTimerDisplay() {
        guard let next = nextCardDate else {
            timerString = ""
            return
        }
        
        let remaining = next.timeIntervalSinceNow
        if remaining <= 0 {
            timerString = "Due now"
        } else {
            let hours = Int(remaining) / 3600
            let minutes = (Int(remaining) % 3600) / 60
            let seconds = Int(remaining) % 60
            
            if hours > 0 {
                timerString = String(format: "%d:%02d:%02d", hours, minutes, seconds)
            } else {
                timerString = String(format: "%d:%02d", minutes, seconds)
            }
        }
    }
    
    private func startLogging() {
        logCards.removeAll()
        if let timeSlot = settingsManager.getCurrentTimeSlot() {
            createNewLogCard(for: timeSlot)
        }
        scheduleNextCard()
    }
    
    private func restartLogging() {
        cardTimer?.invalidate()
        logCards.removeAll { !$0.isComplete }
        if let timeSlot = settingsManager.getCurrentTimeSlot() {
            createNewLogCard(for: timeSlot)
        }
        scheduleNextCard()
    }
    
    private func scheduleNextCard() {
        let nextSlot = settingsManager.getNextTimeSlot()
        nextCardDate = nextSlot
        
        let interval = nextSlot.timeIntervalSinceNow
        cardTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [self] _ in
            if let timeSlot = settingsManager.getCurrentTimeSlot() {
                createNewLogCard(for: timeSlot)
            }
            scheduleNextCard()
        }
    }
    
    private func createNewLogCard(for timeSlot: (start: Date, end: Date)) {
        let exists = logCards.contains { card in
            Calendar.current.isDate(card.startTime, inSameDayAs: timeSlot.start) &&
            Calendar.current.compare(card.startTime, to: timeSlot.start, toGranularity: .hour) == .orderedSame
        }
        
        if !exists {
            let newCard = LogCard(startTime: timeSlot.start, endTime: timeSlot.end)
            logCards.insert(newCard, at: 0)
        }
    }
} 