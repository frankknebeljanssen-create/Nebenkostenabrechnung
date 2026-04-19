//
//  WohneinheitDetailView.swift
//  NebenkostenApp — UI/Objekt
//
//  Platzhalter — die echten Mieter-/Zähler-Details folgen in einer
//  späteren Task.
//

import SwiftUI

struct WohneinheitDetailView: View {
    let wohneinheit: Wohneinheit

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: symbol)
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(.tint)

            Text(wohneinheit.bezeichnung.isEmpty ? "Unbenannte Einheit" : wohneinheit.bezeichnung)
                .font(.largeTitle.bold())

            Text(wohneinheit.nutzungsart.rawValue.capitalized)
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Details folgen in Task 0.12")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .navigationTitle(wohneinheit.bezeichnung.isEmpty ? "Einheit" : wohneinheit.bezeichnung)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var symbol: String {
        switch wohneinheit.nutzungsart {
        case .gewerbe:    return "building.2"
        case .leerstand:  return "questionmark.square.dashed"
        default:          return "house"
        }
    }
}
