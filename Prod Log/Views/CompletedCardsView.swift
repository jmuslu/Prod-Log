import SwiftUI

struct CompletedCardsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Array(groupedCards.keys.sorted().reversed()), id: \.self) { date in
                    Section(header: Text(formatDate(date))) {
                        ForEach(groupedCards[date] ?? []) { card in
                            CompletedLogCardView(card: card)
                        }
                    }
                }
            }
            .navigationTitle("Completed Cards")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var groupedCards: [Date: [LogCard]] {
        let calendar = Calendar.current
        let allCards = settingsManager.getAllCompletedCards()
        
        return Dictionary(grouping: allCards) { card in
            calendar.startOfDay(for: card.startTime)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
    }
} 