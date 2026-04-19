//
//  TabPlatzhalterView.swift
//  NebenkostenApp — UI
//
//  Gemeinsamer Platzhalter für die noch nicht implementierten Tab-
//  Inhalte. Wird in den Folge-Tasks durch den jeweiligen echten Screen
//  ersetzt.
//

import SwiftUI

struct TabPlatzhalterView: View {
    let titel: String
    let symbol: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: symbol)
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(.tint)

            Text(titel)
                .font(.largeTitle.bold())

            Text("Noch nicht implementiert")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    TabPlatzhalterView(titel: "Objekt", symbol: "house")
}
