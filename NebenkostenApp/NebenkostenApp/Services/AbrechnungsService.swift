//
//  AbrechnungsService.swift
//  NebenkostenApp — Services
//
//  Brücke zwischen @Model-SwiftData und Calc-Layer.
//  MVP (Phase 0): Alle Kostenarten flächenbasiert umgelegt — die volle
//  HeizkostenV-Integration mit HeizkostenRechner/WasserkostenRechner kommt
//  in Task 0.22 End-to-End. Ausreichend, um den Abrechnungs-Flow sichtbar
//  zu machen.
//

import Foundation
import SwiftData

struct Mieterposition: Identifiable, Hashable, Sendable {
    let id: UUID
    let kostenart: String
    let gesamtkostenEuro: Decimal
    let mieteranteilEuro: Decimal
    let verteilerschluesselText: String
    let paragraph35aAnteilEuro: Decimal
}

struct Mieterabrechnung: Identifiable, Hashable, Sendable {
    let id: UUID
    let mieterID: UUID
    let mieterName: String
    let mieterAnschrift: String
    let mieterEmail: String
    let einheitBezeichnung: String
    let einheitFlaecheM2: Decimal
    let positionen: [Mieterposition]
    let gesamtkostenEuro: Decimal
    let vorauszahlungenEuro: Decimal
    /// Positiv → Nachzahlung, negativ → Erstattung.
    let saldoEuro: Decimal
    let steuer35aBetragEuro: Decimal
}

@MainActor
enum AbrechnungsService {

    /// Erzeugt für jeden aktiven Mieter der Immobilie eine Mieterabrechnung
    /// für die angegebene Periode.
    static func aggregiere(
        periode: Abrechnungsperiode,
        immobilie: Immobilie
    ) -> [Mieterabrechnung] {
        let aktiveMieter = (immobilie.wohneinheiten ?? [])
            .flatMap { $0.mietverhaeltnisse ?? [] }
            .filter { $0.auszugAm == nil && $0.wohneinheit != nil }

        let periodenRechnungen = (immobilie.rechnungen ?? []).filter { r in
            r.rechnungsdatum >= periode.von && r.rechnungsdatum <= periode.bis
        }
        let monate = monateInPeriode(periode)

        return aktiveMieter
            .sorted { lhs, rhs in
                let lBez = lhs.wohneinheit?.bezeichnung ?? ""
                let rBez = rhs.wohneinheit?.bezeichnung ?? ""
                return sortierrang(lBez) < sortierrang(rBez)
            }
            .map { bauAbrechnung(mieter: $0, rechnungen: periodenRechnungen, immobilie: immobilie, monateInPeriode: monate) }
    }

    // MARK: - Eine Mieterabrechnung

    private static func bauAbrechnung(
        mieter: Mietverhaeltnis,
        rechnungen: [Rechnung],
        immobilie: Immobilie,
        monateInPeriode: Int
    ) -> Mieterabrechnung {
        guard let einheit = mieter.wohneinheit else {
            return leereMieterabrechnung(mieter: mieter)
        }

        let positionen: [Mieterposition] = rechnungen.compactMap { rechnung in
            guard let kostenart = rechnung.kostenart, kostenart.aktiv else { return nil }
            let anteil = berechneAnteil(
                rechnung: rechnung,
                einheit: einheit,
                immobilie: immobilie
            )
            guard anteil > 0 else { return nil }

            let p35a: Decimal
            if kostenart.paragraph35a, let lohn = rechnung.lohnanteilBruttoEuro,
               rechnung.betragBruttoEuro > 0 {
                p35a = lohn * einheit.flaecheM2 / immobilie.gesamtflaecheM2
            } else {
                p35a = 0
            }

            return Mieterposition(
                id: UUID(),
                kostenart: kostenart.bezeichnung,
                gesamtkostenEuro: rechnung.betragBruttoEuro,
                mieteranteilEuro: anteil,
                verteilerschluesselText: verteilerschluessel(einheit: einheit, immobilie: immobilie),
                paragraph35aAnteilEuro: p35a
            )
        }

        let gesamt = positionen.reduce(Decimal(0)) { $0 + $1.mieteranteilEuro }
        let vorauszahlungen = mieter.vorauszahlungMonatEuro * Decimal(monateInPeriode)
        let saldo = gesamt - vorauszahlungen
        let p35aGesamt = positionen.reduce(Decimal(0)) { $0 + $1.paragraph35aAnteilEuro }

        return Mieterabrechnung(
            id: UUID(),
            mieterID: mieter.id,
            mieterName: mieter.mieterName,
            mieterAnschrift: mieter.mieterAnschrift,
            mieterEmail: mieter.mieterEmail,
            einheitBezeichnung: einheit.bezeichnung,
            einheitFlaecheM2: einheit.flaecheM2,
            positionen: positionen,
            gesamtkostenEuro: gesamt,
            vorauszahlungenEuro: vorauszahlungen,
            saldoEuro: saldo,
            steuer35aBetragEuro: p35aGesamt
        )
    }

    private static func leereMieterabrechnung(mieter: Mietverhaeltnis) -> Mieterabrechnung {
        Mieterabrechnung(
            id: UUID(),
            mieterID: mieter.id,
            mieterName: mieter.mieterName,
            mieterAnschrift: mieter.mieterAnschrift,
            mieterEmail: mieter.mieterEmail,
            einheitBezeichnung: "—",
            einheitFlaecheM2: 0,
            positionen: [],
            gesamtkostenEuro: 0,
            vorauszahlungenEuro: 0,
            saldoEuro: 0,
            steuer35aBetragEuro: 0
        )
    }

    // MARK: - Anteilsrechnung

    /// MVP: immer flächenbasiert. Phase 1 / Task 0.22: verzweigen auf
    /// HeizkostenRechner und WasserkostenRechner bei entsprechendem
    /// Umlageschlüssel.
    private static func berechneAnteil(
        rechnung: Rechnung,
        einheit: Wohneinheit,
        immobilie: Immobilie
    ) -> Decimal {
        guard immobilie.gesamtflaecheM2 > 0 else { return 0 }
        return rechnung.betragBruttoEuro * einheit.flaecheM2 / immobilie.gesamtflaecheM2
    }

    private static func verteilerschluessel(einheit: Wohneinheit, immobilie: Immobilie) -> String {
        let e = stringFor(einheit.flaecheM2)
        let g = stringFor(immobilie.gesamtflaecheM2)
        return "\(e) / \(g) m²"
    }

    // MARK: - Helfer

    private static func monateInPeriode(_ p: Abrechnungsperiode) -> Int {
        var kal = Calendar(identifier: .gregorian)
        kal.timeZone = TimeZone(identifier: "UTC")!
        let k = kal.dateComponents([.month], from: p.von, to: p.bis)
        return max((k.month ?? 0) + 1, 1)
    }

    private static func sortierrang(_ bez: String) -> Int {
        let key = bez.uppercased().trimmingCharacters(in: .whitespaces)
        switch key {
        case "KG", "UG":       return 0
        case "EG":             return 1
        case "OG", "1. OG":    return 2
        case "2. OG":          return 3
        case "DG":             return 4
        default:               return 99
        }
    }

    private static func stringFor(_ d: Decimal) -> String {
        let g = d.gerundet(auf: 0, modus: .abrunden)
        if d == g {
            return NSDecimalNumber(decimal: g).stringValue
        }
        return NSDecimalNumber(decimal: d.gerundet(auf: 1, modus: .bankers)).stringValue
    }
}
