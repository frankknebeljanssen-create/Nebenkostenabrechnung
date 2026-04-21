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
        // Window-Hintergrund explizit auf bgApp setzen. Der Streifen
        // zwischen Content-Ende und TabBar war nicht in einem
        // einzelnen SwiftUI-View, sondern lag auf der UIWindow-
        // Ebene durch — iOS defaultet UIWindow.backgroundColor bei
        // kaltem Start auf Schwarz. Mit `UIWindow.appearance()` setzen
        // wir den Default fuer alle zukuenftig erzeugten Windows und
        // iterieren zusaetzlich ueber bereits verbundene Scenes, um
        // den Fall „Scene ist schon da, Appearance nicht" abzudecken.
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

    private static func konfiguriereTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()

        // Explizite RGB-UIColors statt `UIColor(SwiftUI.Color)` —
        // der SwiftUI→UIKit-Converter hat unter iOS 26 in manchen
        // Konstellationen den sRGB-Colorspace verloren und die
        // TabBar schwarz gezeichnet. Werte sind 1:1 aus den
        // DesignTokens (Hex → dezimal / 255).
        let bgCompact   = UIColor(red: 239/255, green: 234/255, blue: 224/255, alpha: 1.0) // #EFEAE0
        let akzentBlau  = UIColor(red:  58/255, green:  85/255, blue: 120/255, alpha: 1.0) // #3A5578
        let inaktiv     = UIColor(red: 138/255, green: 133/255, blue: 120/255, alpha: 1.0) // #8A8578
        let trenner     = UIColor(red:  60/255, green:  50/255, blue:  40/255, alpha: 0.12) // #3C3228 @12%

        appearance.backgroundColor = bgCompact
        // Keine Translucency, kein Blur — iOS-Defaults wuerden sonst
        // beim Scrollen die Hintergrundfarbe „aufhellen".
        appearance.backgroundEffect = nil
        appearance.shadowColor = trenner

        // Selected rendert jetzt als weisse Schrift+Icon auf blauer
        // Pill (Accent #3A5578). Die Pill haengt an der TabBar-
        // Appearance selbst (UITabBarAppearance.
        // selectionIndicatorImage) — nicht am Item-State — und ist
        // stretchable, damit iOS sie auf die jeweilige Item-Breite
        // skaliert.
        appearance.selectionIndicatorImage = Self.pillBild(
            farbe: akzentBlau,
            radius: 10,
            hoehe: 32
        )

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = inaktiv
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: inaktiv,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]
        itemAppearance.selected.iconColor = .white
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.white,
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
        UITabBar.appearance().tintColor = .white
        UITabBar.appearance().unselectedItemTintColor = inaktiv
        UITabBar.appearance().isTranslucent = false
    }

    /// Erzeugt ein stretchbares Pill-Image in der uebergebenen Farbe.
    /// Die `capInsets` sind so gesetzt, dass die Rundung erhalten
    /// bleibt, wenn iOS das Bild auf die Item-Breite skaliert.
    private static func pillBild(farbe: UIColor, radius: CGFloat, hoehe: CGFloat) -> UIImage {
        let breite = radius * 2 + 2
        let groesse = CGSize(width: breite, height: hoehe)
        let renderer = UIGraphicsImageRenderer(size: groesse)
        let bild = renderer.image { _ in
            let rect = CGRect(origin: .zero, size: groesse)
            let pfad = UIBezierPath(roundedRect: rect, cornerRadius: radius)
            farbe.setFill()
            pfad.fill()
        }
        return bild.resizableImage(
            withCapInsets: UIEdgeInsets(top: radius, left: radius, bottom: radius, right: radius),
            resizingMode: .stretch
        )
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
