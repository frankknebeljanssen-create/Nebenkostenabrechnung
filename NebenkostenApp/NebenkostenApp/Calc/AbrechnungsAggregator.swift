//
//  AbrechnungsAggregator.swift
//  NebenkostenApp — Calc-Layer
//
//  Führt die Einzelrechner (Heizkosten, Wasser, Flächenumlage) zu
//  Abrechnungs-Positionen pro Wohneinheit zusammen. Pro Einheit fällt
//  eine Liste aus Positionen an, die in der Folge vom PDF-Generator
//  oder UI-Layer verwendet wird. Der Aggregator selbst rundet NICHT;
//  Cent-Rundung macht der Aufrufer.
//
//  Einziger erlaubter Import: Foundation.
//

import Foundation

/// Einzelne Position auf der Mieter-Abrechnung.
struct Abrechnungseintrag: Equatable, Sendable {
    let kostenart: String
    /// Gesamtkosten der Kostenart für die ganze Immobilie (Info-Wert).
    let gesamtkostenEuro: Euro
    /// Anteil, der auf diese Einheit entfällt.
    let mieteranteilEuro: Euro
    let verteilerschluesselText: String
}

/// Eine zu berechnende Kostenart in der Periode.
enum KostenartBerechnung: Sendable {
    case heizkosten(HeizkostenInput)
    case wasser(WasserkostenInput)
    case flaechenumlage(kostenart: String, FlaechenInput)
    /// Direkt-Zuweisung eines Betrags auf eine Einheit (z.B. verursacher-
    /// gerechnete Reparaturkosten). Kein Umlageschlüssel.
    case direkt(kostenart: String, einheitID: String, betrag: Euro, text: String)
}

struct AbrechnungsInput: Sendable {
    /// Feste Reihenfolge der Einheiten. Bestimmt, welche IDs auf der
    /// Abrechnung erscheinen (Einheiten ohne Positionen bekommen eine
    /// leere Liste).
    let einheitIDs: [String]
    let positionen: [KostenartBerechnung]
}

struct AbrechnungsAggregatErgebnis: Sendable {
    /// Einheit-ID → alle Abrechnungs-Positionen.
    let proEinheit: [String: [Abrechnungseintrag]]

    /// Summe aller Mieteranteile einer Einheit (intern unrundiert).
    func summe(fuer einheitID: String) -> Euro {
        proEinheit[einheitID]?.reduce(Decimal(0)) { $0 + $1.mieteranteilEuro } ?? 0
    }
}

enum AbrechnungsAggregator {

    static func aggregiere(_ input: AbrechnungsInput) -> AbrechnungsAggregatErgebnis {
        var pro: [String: [Abrechnungseintrag]] = [:]
        for id in input.einheitIDs { pro[id] = [] }

        for berechnung in input.positionen {
            switch berechnung {

            case .heizkosten(let h):
                let e = HeizkostenRechner.berechne(h)
                for einheit in e.proEinheit where pro[einheit.einheitID] != nil {
                    pro[einheit.einheitID]!.append(Abrechnungseintrag(
                        kostenart: "Heizung",
                        gesamtkostenEuro: e.heizkostenTopfEuro,
                        mieteranteilEuro: einheit.heizung.gesamtEuro,
                        verteilerschluesselText: einheit.heizung.verteilerschluesselText
                    ))
                    pro[einheit.einheitID]!.append(Abrechnungseintrag(
                        kostenart: "Warmwasser",
                        gesamtkostenEuro: e.warmwasserkostenTopfEuro,
                        mieteranteilEuro: einheit.warmwasser.gesamtEuro,
                        verteilerschluesselText: einheit.warmwasser.verteilerschluesselText
                    ))
                }

            case .wasser(let w):
                let e = WasserkostenRechner.berechne(w)
                let preisText = e.kombiPreisEuroProM3.gerundet(auf: 4, modus: .bankers)
                for einheit in e.proEinheit where pro[einheit.einheitID] != nil {
                    pro[einheit.einheitID]!.append(Abrechnungseintrag(
                        kostenart: "Wasser (BWB)",
                        gesamtkostenEuro: e.bwbGesamtkostenEuro,
                        mieteranteilEuro: einheit.anteilEuro,
                        verteilerschluesselText: "\(einheit.verbrauchM3) m³ × \(preisText) €/m³"
                    ))
                }

            case .flaechenumlage(let name, let f):
                let e = FlaechenRechner.berechne(f)
                for einheit in e.proEinheit where pro[einheit.einheitID] != nil {
                    pro[einheit.einheitID]!.append(Abrechnungseintrag(
                        kostenart: name,
                        gesamtkostenEuro: e.basisBetragEuro,
                        mieteranteilEuro: einheit.anteilEuro,
                        verteilerschluesselText: einheit.verteilerschluesselText
                    ))
                }

            case .direkt(let name, let einheitID, let betrag, let text):
                if pro[einheitID] != nil {
                    pro[einheitID]!.append(Abrechnungseintrag(
                        kostenart: name,
                        gesamtkostenEuro: betrag,
                        mieteranteilEuro: betrag,
                        verteilerschluesselText: text
                    ))
                }
            }
        }

        return AbrechnungsAggregatErgebnis(proEinheit: pro)
    }
}
