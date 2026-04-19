import SwiftUI
import SwiftData

@main
struct NebenkostenAppApp: App {
    let container: ModelContainer

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
                .modelContainer(container)
        }
    }
}
