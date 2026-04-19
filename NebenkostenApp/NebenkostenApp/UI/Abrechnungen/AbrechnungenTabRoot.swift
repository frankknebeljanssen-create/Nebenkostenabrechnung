//
//  AbrechnungenTabRoot.swift
//  NebenkostenApp — UI/Abrechnungen
//

import SwiftUI

struct AbrechnungenTabRoot: View {
    var body: some View {
        NavigationStack {
            TabPlatzhalterView(
                titel: "Abrechnungen",
                symbol: "doc.text.magnifyingglass"
            )
            .navigationTitle("Abrechnungen")
        }
    }
}

#Preview {
    AbrechnungenTabRoot()
}
