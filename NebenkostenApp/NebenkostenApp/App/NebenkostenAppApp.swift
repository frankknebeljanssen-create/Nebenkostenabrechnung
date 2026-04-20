import SwiftUI
import SwiftData

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
        }
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
