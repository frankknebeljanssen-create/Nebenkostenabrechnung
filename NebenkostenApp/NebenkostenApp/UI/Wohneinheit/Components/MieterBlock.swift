//
//  MieterBlock.swift
//  NebenkostenApp — UI/Wohneinheit/Components
//

import SwiftUI

struct MieterBlock: View {
    let wohneinheit: Wohneinheit
    let mietverhaeltnis: Mietverhaeltnis?

    @State private var zeigeEdit = false
    @State private var zeigeNeu = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mieter")
                .font(.headline)

            if let mv = mietverhaeltnis {
                VStack(alignment: .leading, spacing: 8) {
                    Text(mv.mieterName.isEmpty ? "Mieter ohne Namen" : mv.mieterName)
                        .font(.body.weight(.semibold))

                    HStack(spacing: 8) {
                        Text(mv.mieterTyp.rawValue)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundStyle(.tint)
                            .clipShape(Capsule())

                        if mv.anzahlPersonen > 1 {
                            Text("\(mv.anzahlPersonen) Personen")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Button {
                    zeigeEdit = true
                } label: {
                    Label("Bearbeiten", systemImage: "pencil")
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            } else {
                Text("Kein aktives Mietverhältnis")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    zeigeNeu = true
                } label: {
                    Label("Mietverhältnis anlegen", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .sheet(isPresented: $zeigeEdit) {
            if let mv = mietverhaeltnis {
                MieterEditView(modus: .bearbeiten(mv))
            }
        }
        .sheet(isPresented: $zeigeNeu) {
            if let immobilie = wohneinheit.immobilie {
                MieterEditView(modus: .neu(immobilie: immobilie, vorauswahl: wohneinheit))
            }
        }
    }
}
