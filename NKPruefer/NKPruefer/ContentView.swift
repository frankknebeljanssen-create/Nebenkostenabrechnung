import SwiftUI
import SwiftData
import UIKit

extension Notification.Name {
    static let nkResetToHome = Notification.Name("nkResetToHome")
}

struct ContentView: View {
    @AppStorage("hatOnboardingGesehen") private var hatOnboardingGesehen = false
    @EnvironmentObject var appSettings: AppSettings

    @State private var resetId = UUID()
    @State private var isUnlocked = false
    @State private var showLockScreen = true

    var body: some View {
        Group {
            if !hatOnboardingGesehen {
                OnboardingView()
            } else if appSettings.appLockEnabled && showLockScreen && !isUnlocked {
                LockScreenView(isUnlocked: $isUnlocked)
            } else {
                MainTabView()
                    .id(resetId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .nkResetToHome)) { _ in
            resetId = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            if appSettings.appLockEnabled {
                showLockScreen = true
                isUnlocked = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            if appSettings.appLockEnabled && !isUnlocked {
                showLockScreen = true
            }
        }
    }
}
