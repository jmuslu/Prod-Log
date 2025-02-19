//
//  ContentView.swift
//  Prod Log
//
//  Created by Joseph Muslu on 1/27/25.
//






import SwiftUI

struct ContentView: View {
    @StateObject private var settingsManager = SettingsManager()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("initialSettingsTab") private var initialSettingsTab = true
    @State private var selectedTab = 2  // Start with Settings tab
    
    var body: some View {
        if !hasCompletedOnboarding {
            OnboardingView()
                .environmentObject(settingsManager)
        } else {
            TabView(selection: $selectedTab) {
                LoggerView()
                    .tabItem {
                        Label("Logger", systemImage: "clock")
                    }
                    .tag(0)
                
                DashboardView()
                    .tabItem {
                        Label("Dashboard", systemImage: "chart.bar")
                    }
                    .tag(1)
                
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(2)
            }
            .environmentObject(settingsManager)
            .onAppear {
                if initialSettingsTab {
                    selectedTab = 2
                    initialSettingsTab = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
