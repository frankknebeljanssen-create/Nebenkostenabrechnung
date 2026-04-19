//
//  DokumenteTabRoot.swift
//  NebenkostenApp — UI/Dokumente
//

import SwiftUI

struct DokumenteTabRoot: View {
    var body: some View {
        NavigationStack {
            TabPlatzhalterView(
                titel: "Dokumente",
                symbol: "doc.text"
            )
            .navigationTitle("Dokumente")
        }
    }
}

#Preview {
    DokumenteTabRoot()
}
