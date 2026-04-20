//
//  MeterRow.swift
//  NebenkostenApp — UI/Zaehler/Components
//
//  Eine vollständige Zähler-Row mit zwei Zeilen:
//    Zeile 1: ScopePill + Location (anzeigename) + anzeigetyp rechts
//    Zeile 2: MeterReading(Anfang) → MeterReading(Ende) → VerbrauchAnzeige
//
//  Periode wird als Kontext mitgegeben, damit die drei Ablesungen
//  den passenden Zeitbezug nutzen.
//

import SwiftUI

struct MeterRow: View {
    let zaehler: Zaehler
    let periode: Abrechnungsperiode?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            kopfZeile
            messZeile
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
    }

    // MARK: - Kopfzeile

    private var kopfZeile: some View {
        HStack(spacing: 10) {
            ScopePill(scopeId: zaehler.wohneinheit?.bezeichnung ?? "HAUS")
            Text(zaehler.anzeigename)
                .appFont(AppFont.bodyMedium16())
                .foregroundStyle(DesignTokens.text)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(zaehler.anzeigetyp)
                .appFont(AppFont.captionEmphasis())
                .foregroundStyle(DesignTokens.textTertiary)
                .lineLimit(1)
        }
    }

    // MARK: - Messzeile (3 Spalten + Pfeil + Verbrauch)

    private var messZeile: some View {
        let anfang = anfangsStand
        let ende = endeStand
        return HStack(alignment: .top, spacing: 10) {
            MeterReading(
                art: .anfang,
                datum: anfang?.ablesedatum,
                wert: anfang.map { Formatting.zaehlerstand($0.stand, einheit: zaehler.einheit) },
                status: anfang == nil ? .error : .ok
            )
            Text("→")
                .appFont(AppFont.monoCaption())
                .foregroundStyle(DesignTokens.textTertiary)
                .padding(.top, 18)
            MeterReading(
                art: .ende,
                datum: ende?.ablesedatum,
                wert: ende.map { Formatting.zaehlerstand($0.stand, einheit: zaehler.einheit) },
                status: ende == nil ? .error : .ok
            )
            VerbrauchAnzeige(
                verbrauch: verbrauch,
                einheit: zaehler.einheit
            )
        }
    }

    // MARK: - Datenlogik

    private var staendeInPeriode: [Zaehlerstand] {
        guard let p = periode else {
            return (zaehler.staende ?? []).sorted(by: { $0.ablesedatum < $1.ablesedatum })
        }
        return (zaehler.staende ?? [])
            .filter { $0.ablesedatum >= p.von && $0.ablesedatum <= p.bis }
            .sorted(by: { $0.ablesedatum < $1.ablesedatum })
    }

    private var anfangsStand: Zaehlerstand? {
        staendeInPeriode.first
    }

    private var endeStand: Zaehlerstand? {
        guard staendeInPeriode.count >= 2 else { return nil }
        return staendeInPeriode.last
    }

    private var verbrauch: Decimal? {
        guard let a = anfangsStand, let e = endeStand, e.stand >= a.stand else { return nil }
        return e.stand - a.stand
    }
}
