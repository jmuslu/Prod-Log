import SwiftUI

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
    
    private var timeSlotText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: card.startTime)) - \(formatter.string(from: card.endTime))"
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
            var updatedCard = logCards[index]
            updatedCard.categories = categoryPercentages
            logCards[index] = updatedCard
        }
        dismiss()
    }
} 