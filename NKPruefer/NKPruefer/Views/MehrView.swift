import SwiftUI

struct MehrView: View {
    var body: some View {
        Text("Mehr — Coming Soon")
            .navigationTitle("Mehr")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { MehrView() }
}
