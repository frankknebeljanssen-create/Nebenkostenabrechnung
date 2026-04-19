import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "house.and.flag.fill")
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(.tint)

            Text("NebenkostenApp")
                .font(.largeTitle.bold())

            Text("Phase 0 – MVP Setup")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Task 0.1 abgeschlossen · App startet")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    ContentView()
}
