//
//  ObjektTabRoot.swift
//  NebenkostenApp — UI/Objekt
//

import SwiftUI
import SwiftData

struct ObjektTabRoot: View {
    @Query(sort: \Immobilie.erstelltAm) private var immobilien: [Immobilie]

    var body: some View {
        NavigationStack {
            if let immobilie = immobilien.first {
                ObjektDashboardView(immobilie: immobilie)
            } else {
                TabPlatzhalterView(titel: "Objekt", symbol: "house")
                    .navigationTitle("Objekt")
            }
        }
    }
}

#Preview {
    ObjektTabRoot()
}
