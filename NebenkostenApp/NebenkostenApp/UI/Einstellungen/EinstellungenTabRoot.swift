//
//  EinstellungenTabRoot.swift
//  NebenkostenApp — UI/Einstellungen
//

import SwiftUI

struct EinstellungenTabRoot: View {
    var body: some View {
        NavigationStack {
            Form {
                DatenExportSection()
                DatenLoeschungSection()
                AboutSection()
            }
            .navigationTitle("Einstellungen")
        }
    }
}

#Preview {
    EinstellungenTabRoot()
}
