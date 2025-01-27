import SwiftUI

struct LogCard: Identifiable {
    let id = UUID()
    let timestamp: Date
    var categories: [Category: Double] = [:]
    var isComplete: Bool = false
}

struct LoggerView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var logCards: [LogCard] = []
    @State private var selectedCard: LogCard?
    @State private var showingCategorySheet = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(logCards) { card in
                    LogCardView(card: card)
                        .onTapGesture {
                            selectedCard = card
                            showingCategorySheet = true
                        }
                }
            }
            .navigationTitle("Activity Log")
            .sheet(isPresented: $showingCategorySheet) {
                if let card = selectedCard {
                    CategorySelectionView(card: card)
                }
            }
        }
    }
}

struct LogCardView: View {
    let card: LogCard
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(card.timestamp, style: .date)
                .font(.headline)
            Text(card.timestamp, style: .time)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct CategorySelectionView: View {
    let card: LogCard
    @Environment(\.dismiss) private var dismiss
    @State private var categoryPercentages: [Category: Double] = [:]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Array(categoryPercentages.keys)) { category in
                    CategorySliderView(category: category, percentage: binding(for: category))
                }
                
                Text("Total: \(totalPercentage)%")
                    .font(.headline)
                    .foregroundColor(totalPercentage == 100 ? .green : .red)
            }
            .navigationTitle("Log Activities")
            .navigationBarItems(
                trailing: Button("Save") {
                    // Save logic here
                    dismiss()
                }
                .disabled(totalPercentage != 100)
            )
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
}

struct CategorySliderView: View {
    let category: Category
    @Binding var percentage: Double
    
    var body: some View {
        VStack {
            HStack {
                Circle()
                    .fill(category.color)
                    .frame(width: 20, height: 20)
                Text(category.name)
                Spacer()
                Text("\(Int(percentage))%")
            }
            
            Slider(value: $percentage, in: 0...100, step: 1)
        }
        .padding(.vertical, 4)
    }
} 