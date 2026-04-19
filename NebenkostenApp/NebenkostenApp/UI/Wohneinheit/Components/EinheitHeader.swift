//
//  EinheitHeader.swift
//  NebenkostenApp — UI/Wohneinheit/Components
//

import SwiftUI

struct EinheitHeader: View {
    let wohneinheit: Wohneinheit
    let gesamtflaeche: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(wohneinheit.bezeichnung.isEmpty ? "Unbenannte Einheit" : wohneinheit.bezeichnung)
                .font(.largeTitle.bold())
            Text(untertitel)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(anteilsText)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var untertitel: String {
        let nutzung = wohneinheit.nutzungsart.rawValue.capitalized
        let flaeche = ganzzahlFormatiert(wohneinheit.flaecheM2)
        return "\(nutzung) · \(flaeche) m²"
    }

    private var anteilsText: String {
        guard gesamtflaeche > 0 else {
            return "\(ganzzahlFormatiert(wohneinheit.flaecheM2)) m²"
        }
        return "\(ganzzahlFormatiert(wohneinheit.flaecheM2))/\(ganzzahlFormatiert(gesamtflaeche)) Anteil"
    }

    private func ganzzahlFormatiert(_ wert: Decimal) -> String {
        let abgeschnitten = wert.gerundet(auf: 0, modus: .abrunden)
        if wert == abgeschnitten {
            return NSDecimalNumber(decimal: abgeschnitten).stringValue
        }
        return NSDecimalNumber(decimal: wert.gerundet(auf: 1, modus: .bankers)).stringValue
    }
}
