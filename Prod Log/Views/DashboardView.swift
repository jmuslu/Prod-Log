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
                    
                    CategoryLegend()
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
    @EnvironmentObject var settingsManager: SettingsManager
    
    // This would be calculated from actual logged data
    var dailyPoints: Int = 0
    var categoryData: [Category: Double] = [:]
    
    var dayName: String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let date = calendar.date(byAdding: .day, value: -dayIndex, to: today) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dayName)
                .font(.subheadline)
            
            if categoryData.isEmpty {
                Text("No activities logged")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        ForEach(settingsManager.categories) { category in
                            if let width = categoryData[category] {
                                Rectangle()
                                    .fill(category.color)
                                    .frame(width: geometry.size.width * width)
                            }
                        }
                    }
                }
                .frame(height: 20)
                .cornerRadius(5)
            }
            
            Text("Total: \(dailyPoints) points")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct CategoryLegend: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Categories")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(settingsManager.categories) { category in
                    HStack {
                        Circle()
                            .fill(category.color)
                            .frame(width: 12, height: 12)
                        Text(category.name)
                            .font(.caption)
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
    }
} 