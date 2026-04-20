//
//  ValidierungsAdapter.swift
//  NebenkostenApp — Services
//
//  Brücke zwischen SwiftData-@Model-Objekten und dem pure Calc/
//  Validierungs-Layer. Baut ValidierungsInput für die 6 Plausi-Checks
//  vor einer Abrechnung.
//

import Foundation
import SwiftData

@MainActor
enum ValidierungsAdapter {

    /// Konstante für die Umrechnung m³ Warmwasser → kWh Wärme. Entspricht
    /// wwGasFaktor × brennwert (Bahnhofstr. 37 Parameter: 12,9 × 11,11
    /// ≈ 143,3 kWh/m³). In Phase 1 aus Immobilie.heizung-Parametern
    /// konfigurierbar.
    private static let wwWaermeFaktorKwhProM3 = Decimal(string: "143.319")!

    static func baueInput(
        fuerPeriode periode: Abrechnungsperiode,
        immobilie: Immobilie,
        allePerioden: [Abrechnungsperiode],
        umlageSummeEuro: Decimal? = nil,
        rechnungGesamtEuro: Decimal? = nil
    ) -> ValidierungsInput {

        // --- Flächen (Check 4) ---
        let einheiten = (immobilie.wohneinheiten ?? []).map {
            ValidierungsInput.EinheitFlaeche(
                id: $0.id,
                bezeichnung: $0.bezeichnung,
                flaecheM2: $0.flaecheM2
            )
        }

        // --- Zählerstände (Check 1) ---
        let alleZaehler = (immobilie.hauptzaehler ?? [])
            + (immobilie.wohneinheiten ?? []).flatMap { $0.zaehler ?? [] }
        let zaehlerstaende: [ValidierungsInput.Zaehlerstand] = alleZaehler.flatMap { z in
            (z.staende ?? []).map { s in
                ValidierungsInput.Zaehlerstand(
                    zaehlerID: z.id,
                    zaehlerBezeichnung: z.bezeichnung,
                    datum: s.ablesedatum,
                    wert: s.stand
                )
            }
        }

        // --- Rechnungen (Check 2) ---
        let rechnungen = (immobilie.rechnungen ?? []).map { r in
            ValidierungsInput.Rechnung(
                id: r.id,
                lieferant: r.lieferant,
                datum: r.rechnungsdatum,
                betrag: r.betragBruttoEuro,
                kostenartID: r.kostenart?.id,
                kostenartName: r.kostenart?.bezeichnung ?? ""
            )
        }

        // --- Perioden (Check 3) ---
        let perioden = allePerioden.map {
            ValidierungsInput.Periode(
                id: $0.id,
                von: $0.von,
                bis: $0.bis,
                abgeschlossen: $0.abgeschlossen
            )
        }

        // --- Gas-Verbrauch und WMZ (Check 5) ---
        let gasKwh = gasVerbrauchKwh(immobilie: immobilie, periode: periode)
        let wmzSumme = wmzSummeKwh(immobilie: immobilie, periode: periode)
        let wwWaerme = warmwasserWaermeKwh(immobilie: immobilie, periode: periode)

        return ValidierungsInput(
            gesamtflaecheM2:     immobilie.gesamtflaecheM2,
            einheiten:           einheiten,
            zaehlerstaende:      zaehlerstaende,
            rechnungen:          rechnungen,
            perioden:            perioden,
            aktuellePeriodeID:   periode.id,
            gasHauptzaehlerKwh:  gasKwh,
            wmzSummeKwh:         wmzSumme,
            warmwasserWaermeKwh: wwWaerme,
            umlageSummeEuro:     umlageSummeEuro,
            rechnungGesamtEuro:  rechnungGesamtEuro
        )
    }

    // MARK: - Gas / WMZ / WW

    /// Gas-Verbrauch in kWh aus dem Gas-Hauptzähler der Liegenschaft.
    /// Stand-Einheit ist m³; Umrechnung über einen gerundeten Brennwert.
    /// Liefert nil, wenn Zähler fehlt oder die Stand-Differenz negativ ist
    /// (z.B. Zählerwechsel innerhalb der Periode) — Check 5 wird dann
    /// sauber übersprungen statt mit falschen Werten zu laufen.
    private static func gasVerbrauchKwh(
        immobilie: Immobilie,
        periode: Abrechnungsperiode
    ) -> Decimal? {
        guard let gas = (immobilie.hauptzaehler ?? [])
            .first(where: { $0.medium == .gas })
        else { return nil }

        guard let diff = monotonDiff(staende: gas.staende ?? [], in: periode) else {
            return nil
        }

        // Gas-Stand ist in m³ (JSON-Einheit). Umrechnung in kWh mit
        // dem gängigen Brennwert · z-Zahl für deutsche Gasnetze ~11,11.
        let brennwert = Decimal(string: "11.11")!
        return diff * brennwert
    }

    /// Summe der WMZ-Differenzen aller Einheiten innerhalb der Periode,
    /// konvertiert zu kWh (WMZ-Stand kann in kWh oder MWh gespeichert sein,
    /// erkennbar an `Zaehler.einheit`).
    private static func wmzSummeKwh(
        immobilie: Immobilie,
        periode: Abrechnungsperiode
    ) -> Decimal {
        let wmzZaehler = (immobilie.wohneinheiten ?? [])
            .flatMap { $0.zaehler ?? [] }
            .filter { $0.medium == .waermeenergie }

        var summe: Decimal = 0
        for z in wmzZaehler {
            guard let diff = monotonDiff(staende: z.staende ?? [], in: periode) else { continue }
            let faktor: Decimal = z.einheit == "MWh" ? 1_000 : 1
            summe += diff * faktor
        }
        return summe
    }

    /// Warmwasser-Wärmemenge in kWh: Σ WW-Verbrauch (m³) × Faktor.
    private static func warmwasserWaermeKwh(
        immobilie: Immobilie,
        periode: Abrechnungsperiode
    ) -> Decimal {
        let wwZaehler = (immobilie.wohneinheiten ?? [])
            .flatMap { $0.zaehler ?? [] }
            .filter { $0.medium == .warmwasser }

        var mGesamt: Decimal = 0
        for z in wwZaehler {
            guard let diff = monotonDiff(staende: z.staende ?? [], in: periode) else { continue }
            mGesamt += diff
        }
        return mGesamt * wwWaermeFaktorKwhProM3
    }

    /// Liefert Stand(last) − Stand(first) für Stände innerhalb der Periode,
    /// nur wenn monoton steigend. Sonst nil (vermeidet falsche Rechnungen
    /// bei Zählerwechsel).
    private static func monotonDiff(
        staende: [Zaehlerstand],
        in periode: Abrechnungsperiode
    ) -> Decimal? {
        let sortiert = staende
            .filter { $0.ablesedatum >= periode.von && $0.ablesedatum <= periode.bis }
            .sorted { $0.ablesedatum < $1.ablesedatum }
        guard sortiert.count >= 2,
              let first = sortiert.first,
              let last = sortiert.last
        else { return nil }
        let diff = last.stand - first.stand
        return diff > 0 ? diff : nil
    }
}
