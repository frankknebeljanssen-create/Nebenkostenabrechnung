//
//  EinstellungenTabRoot.swift
//  NebenkostenApp — UI/Einstellungen
//

import SwiftUI

struct EinstellungenTabRoot: View {
    var body: some View {
        NavigationStack {
            TabPlatzhalterView(
                titel: "Einstellungen",
                symbol: "gearshape"
            )
            .navigationTitle("Einstellungen")
        }
    }
}

#Preview {
    EinstellungenTabRoot()
}
