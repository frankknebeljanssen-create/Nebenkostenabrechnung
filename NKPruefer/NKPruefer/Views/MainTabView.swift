import SwiftUI

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

            NavigationStack {
                HilfeView()
            }
            .tabItem {
                Label("Hilfe", systemImage: "questionmark.circle")
            }
            .tag(2)

            NavigationStack {
                MehrView()
            }
            .tabItem {
                Label("Mehr", systemImage: "ellipsis.circle")
            }
            .tag(3)
        }
        .onReceive(NotificationCenter.default.publisher(for: .nkResetToHome)) { _ in
            selectedTab = 0
        }
    }
}
