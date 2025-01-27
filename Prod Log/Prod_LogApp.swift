import SwiftUI

@main
struct Prod_LogApp: App {
    @StateObject private var settingsManager = SettingsManager()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some Scene {
        WindowGroup {
            if !hasCompletedOnboarding {
                OnboardingView()
                    .environmentObject(settingsManager)
            } else {
                MainTabView()
                    .environmentObject(settingsManager)
            }
        }
    }
} 