//
//  ObjektTabRoot.swift
//  NebenkostenApp — UI/Objekt
//

import SwiftUI

struct ObjektTabRoot: View {
    var body: some View {
        NavigationStack {
            TabPlatzhalterView(
                titel: "Objekt",
                symbol: "house"
            )
            .navigationTitle("Objekt")
        }
    }
}

#Preview {
    ObjektTabRoot()
}
