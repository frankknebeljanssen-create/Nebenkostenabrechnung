import SwiftUI
import SwiftData

/// App-Entry-Point.
///
/// Hinweis zur Tab-Bar / Nav-Bar:
/// In `Info.plist` ist `UIDesignRequiresCompatibility = YES` gesetzt —
/// das zwingt iOS 26 in den klassischen iOS-18-Renderer für die ganze
/// App. Damit ist die Tab Bar opak am Bottom geankert, ohne Glow oder
/// Liquid Glass, mit korrekt vertikal zentrierten Icons + Labels.
///
/// Daher kein zusätzliches `UITabBarAppearance` mehr — der System-
/// Default unter `UIDesignRequiresCompatibility` ist genau, was wir
/// wollen.
@main
struct NKPrueferApp: App {
    @StateObject private var userProfile = UserProfile()
    @StateObject private var appSettings = AppSettings()
    @StateObject private var privacyConsent = PrivacyConsent()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(userProfile)
                .environmentObject(appSettings)
                .environmentObject(privacyConsent)
                .tint(AppTheme.accent)
                .preferredColorScheme(appSettings.colorScheme)
        }
        .modelContainer(for: [Mietobjekt.self, GespeicherteAbrechnung.self, APIAuditEntry.self])
    }
}
