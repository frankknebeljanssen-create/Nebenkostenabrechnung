import SwiftUI
import SwiftData
import UIKit

@main
struct NebenkostenAppApp: App {
    let container: ModelContainer
    @State private var objektWahl = ObjektWahl()
    @State private var scopeManager = ScopeManager()

    init() {
        do {
            container = try .app()
        } catch {
            fatalError("ModelContainer konnte nicht erzeugt werden: \(error)")
        }
        MainActor.assumeIsolated {
            SeedData.seedeWennLeer(in: container.mainContext)
            // Strikte-Daten: Bestands-Marker einmalig setzen
            // (Zaehlerstand.erfasstAm, Mietverhaeltnis.vorauszahlungErfasst).
            // Ohne diesen Schritt würde der PreFlight-Check nach dem
            // Update sämtliche bestehenden Daten als „offen"
            // blockieren.
            StrikteDatenMigration.fuehrAusWennNoetig(in: container.mainContext)
        }

        // TabBar-Kontrast manuell setzen: SwiftUI-tint() wird in
        // iOS 18 teils von einem hell-blauen Pill überzeichnet —
        // UITabBarAppearance zwingt den dunklen accentHover-Ton
        // für aktive Icons + Titel.
        Self.konfiguriereTabBar()
    }

    private static func konfiguriereTabBar() {
        let app = UITabBarAppearance()
        app.configureWithOpaqueBackground()
        app.backgroundColor = UIColor(DesignTokens.bgAppCompact)

        let aktiv = UIColor(DesignTokens.accentHover)
        let inaktiv = UIColor(DesignTokens.textTertiary)

        for item in [app.stackedLayoutAppearance,
                     app.inlineLayoutAppearance,
                     app.compactInlineLayoutAppearance] {
            item.normal.iconColor = inaktiv
            item.normal.titleTextAttributes = [
                .foregroundColor: inaktiv,
                .font: UIFont.systemFont(ofSize: 10, weight: .medium)
            ]
            item.selected.iconColor = aktiv
            item.selected.titleTextAttributes = [
                .foregroundColor: aktiv,
                .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
            ]
        }

        UITabBar.appearance().standardAppearance = app
        UITabBar.appearance().scrollEdgeAppearance = app
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(objektWahl)
                .environment(scopeManager)
                .modelContainer(container)
        }
    }
}
