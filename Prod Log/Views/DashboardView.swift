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
    
    var dailyPoints: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let date = calendar.date(byAdding: .day, value: -dayIndex, to: today) else { return 0 }
        return settingsManager.getPoints(for: date)
    }
    
    var categoryPoints: [(Category, Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let date = calendar.date(byAdding: .day, value: -dayIndex, to: today) else { return [] }
        return settingsManager.getCategoryPoints(for: date)
    }
    
    var totalPoints: Int {
        categoryPoints.reduce(0) { $0 + $1.1 }
    }
    
    var dayName: String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let date = calendar.date(byAdding: .day, value: -dayIndex, to: today) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(categoryPoints, id: \.0.id) { category, points in
                        if totalPoints > 0 {
                            Rectangle()
                                .fill(category.color)
                                .frame(width: geometry.size.width * CGFloat(points) / CGFloat(totalPoints))
                        }
                    }
                }
            }
            .frame(height: 20)
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            
            HStack {
                Text(dayName)
                    .font(.caption)
                Spacer()
                Text("\(dailyPoints)pts")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
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