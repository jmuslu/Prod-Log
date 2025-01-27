import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    WeeklyPointsCard()
                    
                    ForEach(0..<7) { dayIndex in
                        DailyActivityBar(dayIndex: dayIndex)
                    }
                }
                .padding()
            }
            .navigationTitle("Dashboard")
        }
    }
}

struct WeeklyPointsCard: View {
    var totalPoints: Int = 0 // This will be calculated later
    
    var body: some View {
        VStack {
            Text("Weekly Points")
                .font(.headline)
            Text("\(totalPoints)")
                .font(.system(size: 40, weight: .bold))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(10)
    }
}

struct DailyActivityBar: View {
    let dayIndex: Int
    
    var dayName: String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let date = calendar.date(byAdding: .day, value: -dayIndex, to: today) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(dayName)
                .font(.subheadline)
            
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // This will be replaced with actual category data
                    ForEach(Category.defaultCategories) { category in
                        Rectangle()
                            .fill(category.color)
                            .frame(width: geometry.size.width / CGFloat(Category.defaultCategories.count))
                    }
                }
            }
            .frame(height: 20)
            .cornerRadius(5)
        }
    }
} 