import SwiftUI

struct CategorySelectionView: View {
    let card: LogCard
    @Binding var logCards: [LogCard]
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var categoryPercentages: [Category: Double] = [:]
    @State private var expandedCategory: Category?
    
    var activeCategories: [Category] {
        settingsManager.getActiveCategories()
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Time slot header
                HeaderView(timeSlotText: timeSlotText)
                
                // Pie chart
                PieChartView(data: categoryPercentages)
                    .frame(height: 200)
                    .padding()
                
                // Category list
                CategoryListView(
                    totalPercentage: totalPercentage,
                    activeCategories: activeCategories,
                    categoryPercentages: categoryPercentages,
                    expandedCategory: expandedCategory,
                    timeInterval: card.endTime.timeIntervalSince(card.startTime) / 3600,
                    onToggle: toggleCategory,
                    onPercentageChange: updatePercentage
                )
            }
            .navigationTitle("Log Activities")
            .navigationBarItems(
                trailing: SaveButton(
                    isEnabled: totalPercentage == 100,
                    action: saveCategories
                )
            )
        }
        .onAppear {
            initializeCategories()
        }
    }
    
    private func initializeCategories() {
        // Keep existing percentages only for active categories
        var newPercentages: [Category: Double] = [:]
        for category in activeCategories {
            if let existing = card.categories.first(where: { $0.key.id == category.id }) {
                newPercentages[category] = existing.value
            }
        }
        categoryPercentages = newPercentages
    }
    
    private func toggleCategory(_ category: Category) {
        withAnimation {
            if expandedCategory == category {
                expandedCategory = nil
            } else {
                expandedCategory = category
            }
        }
    }
    
    private func updatePercentage(for category: Category, value: Double) {
        categoryPercentages[category] = value
    }
    
    private var timeSlotText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: card.startTime)) - \(formatter.string(from: card.endTime))"
    }
    
    private var totalPercentage: Double {
        categoryPercentages.values.reduce(0, +)
    }
    
    private func saveCategories() {
        if let index = logCards.firstIndex(where: { $0.id == card.id }) {
            var updatedCard = card
            updatedCard.categories = categoryPercentages
            updatedCard.isComplete = true
            
            // Save to completed cards in SettingsManager
            settingsManager.addCompletedCard(updatedCard)
            
            // Remove from active cards list
            logCards.remove(at: index)
            
            // Calculate and save points
            let points = settingsManager.calculatePoints(for: updatedCard)
            settingsManager.savePoints(points, for: updatedCard.startTime, categories: categoryPercentages)
        }
        dismiss()
    }
}

// Break out sub-views
private struct HeaderView: View {
    let timeSlotText: String
    
    var body: some View {
        Text(timeSlotText)
            .font(.headline)
            .foregroundColor(.primary)
    }
}

private struct SaveButton: View {
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button("Save", action: action)
            .disabled(!isEnabled)
    }
}

private struct CategoryListView: View {
    let totalPercentage: Double
    let activeCategories: [Category]
    let categoryPercentages: [Category: Double]
    let expandedCategory: Category?
    let timeInterval: Double
    let onToggle: (Category) -> Void
    let onPercentageChange: (Category, Double) -> Void
    
    var body: some View {
        List {
            Text("Total: \(Int(totalPercentage))%")
                .font(.headline)
                .foregroundColor(totalPercentage == 100 ? .green : .red)
            
            ForEach(activeCategories) { category in
                CategoryRowView(
                    category: category,
                    percentage: categoryPercentages[category] ?? 0,
                    isExpanded: expandedCategory == category,
                    timeInterval: timeInterval,
                    onTap: { onToggle(category) },
                    onSliderChange: { value in
                        onPercentageChange(category, value)
                    }
                )
            }
        }
    }
} 