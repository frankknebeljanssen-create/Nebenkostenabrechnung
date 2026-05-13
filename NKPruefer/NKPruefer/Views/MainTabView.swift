import SwiftUI

/// Haupt-Tab-Bar der App.
///
/// Wir nutzen das native SwiftUI `TabView` mit `.tabItem`. iOS sorgt
/// damit automatisch für:
///   • Korrekte Tab-Bar-Höhe (~49pt + Safe-Area-Inset)
///   • Bottom-Anchoring an der unteren Bildschirmkante
///   • Standard-Icon-Größe (≤22pt) und Label-Größe (10pt)
///
/// Die globale UIKit-Appearance wird beim App-Start in
/// `NKPrueferApp.init()` einmalig auf eine flache, opake Variante
/// gesetzt — das neutralisiert insbesondere die iOS-26-Liquid-Glass-
/// und Glow-Effekte, die sonst System-default wären.
struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("Start", systemImage: "house")
            }
            .tag(0)

            NavigationStack {
                PruefungenListView()
            }
            .tabItem {
                Label("Prüfungen", systemImage: "doc.text.magnifyingglass")
            }
            .tag(1)

            // v4-19b: Glossar als eigener Tab — durchsuchbare Vollansicht
            // aller 130 Begriffe (8 Kategorien). Ersetzt den Hilfe-Link.
            NavigationStack {
                GlossarBrowseView()
            }
            .tabItem {
                Label("Glossar", systemImage: "character.book.closed.fill")
            }
            .tag(2)

            NavigationStack {
                HilfeView()
            }
            .tabItem {
                Label("Hilfe", systemImage: "questionmark.circle")
            }
            .tag(3)

            NavigationStack {
                MehrView()
            }
            .tabItem {
                Label("Mehr", systemImage: "ellipsis.circle")
            }
            .tag(4)
        }
        .tint(AppTheme.accent)
        .onReceive(NotificationCenter.default.publisher(for: .nkResetToHome)) { _ in
            selectedTab = 0
        }
    }
}
