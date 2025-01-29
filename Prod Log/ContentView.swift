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
    
    var body: some View {
        if !hasCompletedOnboarding {
            OnboardingView()
                .environmentObject(settingsManager)
        } else {
            MainTabView()
                .environmentObject(settingsManager)
        }
    }
}

#Preview {
    ContentView()
}
