//
//  NaechsterSchrittCard.swift
//  NebenkostenApp — UI/Home
//
//  Eigene Card fuer den "Naechsten Schritt" der Periode. War zuvor
//  Teil der HomeStatusCard — ausgelagert, damit sie visuell gleich
//  gewichtet ist wie die uebrigen Home-Cards (gleiche Breite, gleiche
//  Tiefe) und das Sprungziel als eigenstaendige Handlungs-Karte
//  erkennbar bleibt.
//
//  Die Card zeigt die erste offene (oder teilweise erfuellte)
//  Anforderung aus der Vollstaendigkeitspruefung samt Hinweis und
//  ruft bei Tap `onSprung` mit dem zugehoerigen Sprungziel.
//  Keine Anforderung → Card rendert EmptyView (die View stellt
//  also selbst sicher, dass sie nur erscheint, wenn es was zu tun
//  gibt).
//

import SwiftUI

struct NaechsterSchrittCard: View {
    let anforderungen: [AnforderungMitStatus]
    let onSprung: (Sprungziel) -> Void

    var body: some View {
        if let anf = naechsterSchritt, let ziel = anf.sprungZiel {
            Card(tiefe: .erhoben) {
                Button {
                    onSprung(ziel)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "arrow.forward.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(DesignTokens.accent)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Nächster Schritt")
                                .appFont(AppFont.Basis.micro())
                                .foregroundStyle(DesignTokens.textTertiary)
                                .textCase(.uppercase)
                            Text(anf.anforderung.titel)
                                .appFont(AppFont.Abrechnung.kopfName())
                                .foregroundStyle(DesignTokens.text)
                                .multilineTextAlignment(.leading)
                            if let hinweis = anf.hinweis {
                                Text(hinweis)
                                    .appFont(AppFont.Basis.caption())
                                    .foregroundStyle(DesignTokens.textSecondary)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                            }
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(DesignTokens.textTertiary)
                            .padding(.top, 6)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var offeneAnforderungen: [AnforderungMitStatus] {
        anforderungen.filter { $0.status == .offen && $0.sprungZiel != nil }
    }

    private var teilweiseAnforderungen: [AnforderungMitStatus] {
        anforderungen.filter { $0.status == .teilweise && $0.sprungZiel != nil }
    }

    private var naechsterSchritt: AnforderungMitStatus? {
        offeneAnforderungen.first ?? teilweiseAnforderungen.first
    }
}
