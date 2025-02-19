//import SwiftUI
//import UserNotifications
//
//struct NotificationDebugView: View {
//    @EnvironmentObject var settingsManager: SettingsManager
//    @State private var isAuthorized: Bool = false
//    
//    var body: some View {
//        List {
//            Section("Notification Testing") {
//                Button("Send Test Notification (5s)") {
//                    sendTestNotification()
//                }
//                
//                Button("Print Debug Info") {
//                    debugNotificationStatus()
//                }
//                
//                Button("Schedule Next Notification") {
//                    settingsManager.scheduleNextNotification()
//                }
//            }
//            
//            Section("Status") {
//                Text("Notifications Enabled: \(settingsManager.notificationsEnabled ? "Yes" : "No")")
//                Text("Authorization: \(isAuthorized ? "Granted" : "Not Granted")")
//                
//                if !isAuthorized {
//                    Button("Open Settings") {
//                        if let url = URL(string: UIApplication.openSettingsURLString) {
//                            UIApplication.shared.open(url)
//                        }
//                    }
//                }
//            }
//        }
//        .navigationTitle("Notification Debug")
//        .onAppear {
//            checkAuthStatus()
//        }
//    }
//    
//    private func checkAuthStatus() {
//        UNUserNotificationCenter.current().getNotificationSettings { settings in
//            DispatchQueue.main.async {
//                isAuthorized = settings.authorizationStatus == .authorized
//            }
//        }
//    }
//    
//    private func sendTestNotification() {
//        let content = UNMutableNotificationContent()
//        content.title = "Test Notification"
//        content.body = "This is a test notification"
//        content.sound = .default
//        
//        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
//        let request = UNNotificationRequest(
//            identifier: "testNotification",
//            content: content,
//            trigger: trigger
//        )
//        
//        UNUserNotificationCenter.current().add(request)
//    }
//    
//    private func debugNotificationStatus() {
//        UNUserNotificationCenter.current().getNotificationSettings { settings in
//            print("Notification Settings:")
//            print("Authorization Status: \(settings.authorizationStatus.rawValue)")
//            print("Alert Setting: \(settings.alertSetting.rawValue)")
//            print("Sound Setting: \(settings.soundSetting.rawValue)")
//            print("Badge Setting: \(settings.badgeSetting.rawValue)")
//            
//            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
//                print("\nPending Notifications: \(requests.count)")
//                for request in requests {
//                    print("- ID: \(request.identifier)")
//                    if let trigger = request.trigger as? UNCalendarNotificationTrigger {
//                        print("  Next trigger date: \(trigger.nextTriggerDate() ?? Date())")
//                    }
//                }
//            }
//        }
//    }
//}
