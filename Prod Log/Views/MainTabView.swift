import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        TabView(selection: $selectedTab) {
            LoggerView()
                .environmentObject(settingsManager)
                .tabItem {
                    Label("Logger", systemImage: "list.bullet.clipboard")
                }
                .tag(0)
            
            DashboardView()
                .environmentObject(settingsManager)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(1)
            
            SettingsView()
                .environmentObject(settingsManager)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
    }
} 