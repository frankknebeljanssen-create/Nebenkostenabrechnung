import SwiftUI

struct HilfeView: View {
    var body: some View {
        Text("Hilfe — Coming Soon")
            .navigationTitle("Hilfe")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { HilfeView() }
}
