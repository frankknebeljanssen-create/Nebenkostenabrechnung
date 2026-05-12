import SwiftUI

struct PruefungenListView: View {
    var body: some View {
        Text("Prüfungen — Coming Soon")
            .navigationTitle("Prüfungen")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { PruefungenListView() }
}
