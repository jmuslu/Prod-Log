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
                    
                    ForEach(activeCategories) { category in
                        CategoryRowView(
                            category: category,
                            percentage: categoryPercentages[category] ?? 0,
                            isExpanded: expandedCategory == category,
                            onTap: { toggleCategory(category) },
                            onSliderChange: { updatePercentage(for: category, value: $0) }
                        )
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
            var updatedCard = logCards[index]
            updatedCard.categories = categoryPercentages
            updatedCard.isComplete = true
            logCards[index] = updatedCard
            
            // Calculate and save points
            let points = settingsManager.calculatePoints(for: updatedCard)
            settingsManager.savePoints(points, for: updatedCard.startTime, categories: categoryPercentages)
        }
        dismiss()
    }
} 