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

        // UITabBarAppearance-Konfiguration entfernt — wir benutzen
        // keine SwiftUI-TabView mehr (siehe AppShell ->
        // NebenkostenTabBar). Window-Hintergrund bleibt als
        // Safety-Net, damit kein iOS-Default schwarz durchblitzt.
        Self.konfiguriereWindowHintergrund()
    }

    private static func konfiguriereWindowHintergrund() {
        let bgApp = UIColor(red: 245/255, green: 241/255, blue: 232/255, alpha: 1.0) // #F5F1E8
        UIWindow.appearance().backgroundColor = bgApp
        DispatchQueue.main.async {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .forEach { $0.backgroundColor = bgApp }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(objektWahl)
                .environment(scopeManager)
                .environment(router)
                .modelContainer(container)
                // App-weit Light-Mode erzwingen. Phase 1 ist
                // laut CLAUDE.md ohnehin Light-Only; wir vermeiden
                // damit, dass System-Views (Sheets, Alerts) in
                // Dark-Mode-Systemen auf systemBackgroundColor
                // schwarz auflaufen.
                .preferredColorScheme(.light)
        }
    }
}
