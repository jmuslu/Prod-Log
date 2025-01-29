import SwiftUI

struct LogCard: Identifiable, Equatable {
    let id = UUID()
    let startTime: Date
    let endTime: Date
    var categories: [Category: Double] = [:]
    var isComplete: Bool = false
    
    static func == (lhs: LogCard, rhs: LogCard) -> Bool {
        lhs.id == rhs.id
    }
}

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
                    if let next = nextCardDate {
                        HStack {
                            Text("Next log card in:")
                                .font(.subheadline)
                            Spacer()
                            Text(timerString)
                                .font(.subheadline)
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                        }
                        .listRowBackground(Color.clear)
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

struct LogCardView: View {
    let card: LogCard
    
    var timeSlotText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: card.startTime)) - \(formatter.string(from: card.endTime))"
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(card.startTime, style: .date)
                    .font(.headline)
                Spacer()
                Text(timeSlotText)
                    .font(.subheadline)
            }
            .foregroundColor(.primary)
            
            if !card.categories.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(card.categories.keys), id: \.id) { category in
                        if let percentage = card.categories[category] {
                            Text("\(category.name): \(Int(percentage))%")
                                .font(.caption)
                                .foregroundColor(.primary)
                                .padding(4)
                                .background(category.color.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
        .opacity(card.isComplete ? 0.6 : 1.0)
    }
}

struct CategorySelectionView: View {
    let card: LogCard
    @Binding var logCards: [LogCard]
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var categoryPercentages: [Category: Double] = [:]
    @State private var expandedCategory: Category?
    
    var body: some View {
        NavigationView {
            VStack {
                Text(timeSlotText)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                PieChartView(data: categoryPercentages)
                    .frame(height: 200)
                    .padding()
                
                List {
                    Text("Total: \(Int(totalPercentage))%")
                        .font(.headline)
                        .foregroundColor(totalPercentage == 100 ? .green : .red)
                    
                    ForEach(settingsManager.categories) { category in
                        VStack {
                            Button(action: {
                                withAnimation {
                                    if expandedCategory == category {
                                        expandedCategory = nil
                                    } else {
                                        expandedCategory = category
                                    }
                                }
                            }) {
                                HStack {
                                    Circle()
                                        .fill(category.color)
                                        .frame(width: 20, height: 20)
                                    Text(category.name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("\(Int(categoryPercentages[category] ?? 0))%")
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            if expandedCategory == category {
                                Slider(value: binding(for: category), in: 0...100, step: 1)
                                    .padding(.vertical)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Log Activities")
            .navigationBarItems(
                trailing: Button("Save") {
                    saveCategories()
                }
                .disabled(totalPercentage != 100)
            )
        }
        .onAppear {
            categoryPercentages = card.categories
        }
    }
    
    private var totalPercentage: Double {
        categoryPercentages.values.reduce(0, +)
    }
    
    private func binding(for category: Category) -> Binding<Double> {
        Binding(
            get: { categoryPercentages[category] ?? 0 },
            set: { categoryPercentages[category] = $0 }
        )
    }
    
    private func saveCategories() {
        if let index = logCards.firstIndex(where: { $0.id == card.id }) {
            var updatedCard = card
            updatedCard.categories = categoryPercentages
            updatedCard.isComplete = true
            logCards[index] = updatedCard
            
            // Calculate and save points with category distribution
            let points = settingsManager.calculatePoints(for: updatedCard)
            settingsManager.savePoints(points, for: updatedCard.startTime, categories: categoryPercentages)
            
            // Remove the completed card
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                logCards.removeAll { $0.id == card.id }
            }
        }
        dismiss()
    }
    
    private var timeSlotText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: card.startTime)) - \(formatter.string(from: card.endTime))"
    }
}

struct PieChartView: View {
    let data: [Category: Double]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(data.keys), id: \.id) { category in
                    if let value = data[category], value > 0 {
                        PieSlice(
                            startAngle: startAngle(for: category),
                            endAngle: endAngle(for: category)
                        )
                        .fill(category.color)
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private func startAngle(for category: Category) -> Angle {
        let priorCategories = Array(data.keys).prefix(while: { $0.id != category.id })
        let priorTotal = priorCategories.reduce(0.0) { $0 + (data[$1] ?? 0) }
        return .degrees(priorTotal * 360.0 / 100.0)
    }
    
    private func endAngle(for category: Category) -> Angle {
        let start = startAngle(for: category)
        let value = data[category] ?? 0
        return start + .degrees(value * 360.0 / 100.0)
    }
}

struct PieSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.move(to: center)
        path.addArc(center: center,
                   radius: radius,
                   startAngle: Angle(degrees: -90) + startAngle,
                   endAngle: Angle(degrees: -90) + endAngle,
                   clockwise: false)
        path.closeSubpath()
        return path
    }
} 