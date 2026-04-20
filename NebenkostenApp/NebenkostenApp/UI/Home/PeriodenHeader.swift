//
//  PeriodenHeader.swift
//  NebenkostenApp — UI/Home
//
//  Große Perioden-Überschrift am oberen Rand des HomeScreens.
//  Ersetzt die bisherige Begrüßungs-Zeile („Willkommen zurück.")
//  und den generischen Screen-Titel „Start" — die Periode ist
//  jetzt die primäre Hauptorientierung.
//
//  Layout:
//    Abrechnung 2025
//    01.11.2024 – 31.10.2025
//
//  40 pt / 600 für die Hauptzeile (AppFont.Basis.periodenHeader),
//  13 pt mono/400 textTertiary für das Zeitraum-Datum.
//

import SwiftUI

struct PeriodenHeader: View {
    let periode: Abrechnungsperiode?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(hauptzeile)
                .appFont(AppFont.Basis.periodenHeader())
                .foregroundStyle(DesignTokens.text)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            if let zeitraum {
                Text(zeitraum)
                    .appFont(AppFont.Basis.periodenDatum())
                    .foregroundStyle(DesignTokens.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hauptzeile: String {
        guard let p = periode else { return "Abrechnung" }
        let kal = Calendar(identifier: .gregorian)
        let von = kal.component(.year, from: p.von)
        let bis = kal.component(.year, from: p.bis)
        return von == bis ? "Abrechnung \(von)" : "Abrechnung \(von)/\(bis)"
    }

    private var zeitraum: String? {
        guard let p = periode else { return nil }
        return Formatting.periode(p.von, p.bis)
    }
}
