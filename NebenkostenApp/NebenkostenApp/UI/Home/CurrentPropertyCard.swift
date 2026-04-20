//
//  CurrentPropertyCard.swift
//  NebenkostenApp — UI/Home
//
//  Zeigt das aktuell aktive Objekt prominent: Adresse als Hauptzeile
//  (sehr groß), Ort + m² darunter als Zusatz, rechts ein
//  "Objekt wechseln"-Button. Wird tappbar, wenn mehrere Immobilien
//  existieren — aktuell im MVP meist nur eine.
//

import SwiftUI

struct CurrentPropertyCard: View {
    let immobilie: Immobilie
    /// Callback für „Objekt wechseln" — öffnet je nach App-Stand
    /// den Objekt-Picker oder die Einstellungen.
    let onWechsel: () -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Aktuelles Objekt")
                        .appFont(AppFont.Dashboard.kartenKicker())
                        .foregroundStyle(DesignTokens.textTertiary)
                    Spacer()
                    wechselnButton
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(adresse)
                        .appFont(AppFont.Basis.displayTitle())
                        .foregroundStyle(DesignTokens.text)
                        .lineLimit(2)
                    if !zusatzZeile.isEmpty {
                        Text(zusatzZeile)
                            .appFont(AppFont.Rechnungen.subZeile())
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var adresse: String {
        let a = immobilie.adresse.trimmingCharacters(in: .whitespaces)
        return a.isEmpty ? "Ohne Adresse" : a
    }

    private var zusatzZeile: String {
        var parts: [String] = []
        let ort = immobilie.ort.trimmingCharacters(in: .whitespaces)
        if !ort.isEmpty { parts.append(ort) }
        if immobilie.gesamtflaecheM2 > 0 {
            parts.append(Formatting.m2(immobilie.gesamtflaecheM2))
        }
        let einheitenCount = immobilie.wohneinheiten?.count ?? 0
        if einheitenCount > 0 {
            parts.append("\(einheitenCount) Einheit\(einheitenCount == 1 ? "" : "en")")
        }
        return parts.joined(separator: " · ")
    }

    private var wechselnButton: some View {
        Button {
            onWechsel()
        } label: {
            HStack(spacing: 4) {
                Text("Wechseln")
                    .appFont(AppFont.Rechnungen.rechnungManuellHinzu())
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .foregroundStyle(DesignTokens.accent)
        }
        .buttonStyle(.plain)
    }
}
