import SwiftUI
import SwiftData
import UIKit

@main
struct NebenkostenAppApp: App {
    let container: ModelContainer
    @State private var objektWahl = ObjektWahl()
    @State private var scopeManager = ScopeManager()
    @State private var router = AppShellRouter()

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

        // TabBar-Konfiguration: UITabBarAppearance ist die EINZIGE
        // Wahrheit. SwiftUI-Modifier (.tint, .toolbarBackground)
        // wurden entfernt, damit sie nicht mit der UIKit-Appearance
        // kollidieren (das war die Ursache des Farb-Flash beim
        // Tab-Wechsel und des inkonsistenten Selected-State).
        Self.konfiguriereTabBar()
    }

    private static func konfiguriereTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(DesignTokens.bgAppCompact)
        // Keine Translucency, kein Blur — iOS-Defaults wuerden sonst
        // beim Scrollen die Hintergrundfarbe „aufhellen".
        appearance.backgroundEffect = nil
        appearance.shadowColor = UIColor(DesignTokens.separator)

        // Selected-Farbe laut Task-Brief: Accent #3A5578 (Product-
        // Owner-Wahl), NICHT accentHover. accentHover war ein
        // Relikt aus UI-Fix-2.
        let aktiv = UIColor(DesignTokens.accent)
        let inaktiv = UIColor(DesignTokens.textTertiary)

        // EINE UITabBarItemAppearance-Instanz fuer alle drei
        // Layout-Varianten. Alle vier state-abhaengigen Attribute
        // (iconColor + titleTextAttributes fuer normal + selected)
        // sind explizit gesetzt — keine Luecke, die iOS mit dem
        // System-Accent fuellen koennte.
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = inaktiv
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: inaktiv,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]
        itemAppearance.selected.iconColor = aktiv
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: aktiv,
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        // scrollEdgeAppearance MUSS identisch zu standardAppearance
        // sein — sonst nutzt iOS beim Scroll-Edge einen translucenten
        // Fallback, was das gemeldete Farb-Flash ausloest.
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = aktiv
        UITabBar.appearance().unselectedItemTintColor = inaktiv
        UITabBar.appearance().isTranslucent = false
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(objektWahl)
                .environment(scopeManager)
                .environment(router)
                .modelContainer(container)
        }
    }
}
