import SwiftUI
import Combine

class AppSettings: ObservableObject {
    /// 0 = System, 1 = Hell, 2 = Dunkel
    @Published var appearanceMode: Int {
        didSet { UserDefaults.standard.set(appearanceMode, forKey: "appearance_mode") }
    }

    /// Face ID / Touch ID Lock
    @Published var appLockEnabled: Bool {
        didSet { UserDefaults.standard.set(appLockEnabled, forKey: "app_lock_enabled") }
    }

    var colorScheme: ColorScheme? {
        switch appearanceMode {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    init() {
        self.appearanceMode = UserDefaults.standard.integer(forKey: "appearance_mode")
        self.appLockEnabled = UserDefaults.standard.bool(forKey: "app_lock_enabled")
    }
}
