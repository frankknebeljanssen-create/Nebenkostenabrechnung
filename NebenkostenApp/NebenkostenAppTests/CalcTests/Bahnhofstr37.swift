//
//  Bahnhofstr37.swift
//  NebenkostenAppTests — CalcTests
//
//  Decodable-Hülle über Testdaten/Bahnhofstr37_2025.json im App-Bundle.
//  Nur die für Calc-Layer-Tests benötigten Felder — JSONDecoder ignoriert
//  den Rest. Source of Truth ist die JSON, nicht dieser Code.
//

import Foundation

struct Bahnhofstr37: Decodable {
    let objekt: Objekt
    let wohneinheiten: [WohneinheitDaten]
    let rechnungen: [RechnungDaten]
    let zaehlerstaende: Zaehlerstaende
    let heiz_nebenkosten_zusammensetzung: HeizNebenkostenZusammensetzung?
    let erwartete_ergebnisse: ErwarteteErgebnisse?

    struct Objekt: Decodable {
        let gesamtflaeche_qm: Decimal
        let heizung: HeizungParameter?

        struct HeizungParameter: Decodable {
            let ww_gas_faktor_m3_pro_m3: Double?
            let brennwert_z_zahl_kwh_pro_m3: Double?
            let strom_hilfsenergie_prozent: Double?
            let grundkosten_anteil_prozent: Double?
        }
    }

    struct WohneinheitDaten: Decodable {
        /// "KG", "EG", "OG"
        let id: String
        let flaeche_qm: Decimal
    }

    struct RechnungDaten: Decodable {
        /// z.B. "gasag_2024_2025"
        let id: String
        let gesamt_brutto: Decimal
        /// Nur bei GASAG: Heizgas-Verbrauch in kWh über die Jahresperiode.
        let verbrauch_kwh: Decimal?
        /// Nur bei GASAG: In der User-Excel-Berechnung verwendeter
        /// interner Arbeitspreis (vs. offizielle GASAG-Brutto-Preis).
        /// Wenn gesetzt, werden WW- und Heizgaskosten daraus abgeleitet.
        let interner_arbeitspreis_berechnung: Decimal?
        /// Nur bei BWB: aufgeschlüsselte Positionen (Trinkwasser,
        /// Schmutzwasser inkl. Grundgebühr).
        let positionen: [RechnungPosition]?
        /// Nur bei BWB: kombinierter Mischpreis aus User-Excel (€/m³).
        let wasserpreis_kombiniert_pro_m3: Decimal?

        struct RechnungPosition: Decodable {
            let art: String
            let menge_m3: Decimal?
            let gesamt: Decimal?
        }
    }

    struct Zaehlerstaende: Decodable {
        let verbraeuche_berechnet: VerbraucheBerechnet

        struct VerbraucheBerechnet: Decodable {
            // Heiz-/Warmwasser
            let wmz_kg_kwh: Decimal?
            let wmz_og_kwh: Decimal?
            let wmz_eg_kwh: Decimal?
            let wmz_total_kwh: Decimal?
            let ww_kg_m3: Decimal?
            let ww_eg_m3: Decimal?
            let ww_og_m3: Decimal?
            let ww_total_m3: Decimal?
            // Kaltwasser (neu in v1.1)
            let kw_kg_m3: Decimal?
            let kw_eg_m3: Decimal?
            let kw_eg_garten_m3: Decimal?
            let kw_og_m3: Decimal?
        }
    }

    struct HeizNebenkostenZusammensetzung: Decodable {
        let summe_2024_2025: Decimal
    }

    struct ErwarteteErgebnisse: Decodable {
        let og_gesamtabrechnung_2024_2025: OgGesamt

        struct OgGesamt: Decodable {
            let be_entwaesserung: Decimal
            let ww_heizung: Decimal
            let grundsteuer: Decimal
            let versicherung: Decimal
            let vorgartenpflege: Decimal
            let schnee_eis: Decimal
            let allgemeinstrom: Decimal
            let reinigung: Decimal
            let bsr: Decimal
            let gesamtkosten: Decimal
            let vorauszahlung_monat: Decimal
            let vorauszahlung_jahr: Decimal
            let erstattung: Decimal
            let paragraph_35a_anteil: Decimal
        }
    }

    // MARK: - Laden

    static func laden() throws -> Bahnhofstr37 {
        guard let url = Bundle.main.url(forResource: "Bahnhofstr37_2025", withExtension: "json") else {
            throw TestdatenFehler.resourceNichtGefunden
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Bahnhofstr37.self, from: data)
    }

    // MARK: - Lookup-Helfer

    func einheit(_ id: String) -> WohneinheitDaten {
        guard let treffer = wohneinheiten.first(where: { $0.id == id }) else {
            fatalError("Wohneinheit \(id) nicht in Testdaten.")
        }
        return treffer
    }

    func rechnung(_ id: String) -> RechnungDaten {
        guard let treffer = rechnungen.first(where: { $0.id == id }) else {
            fatalError("Rechnung \(id) nicht in Testdaten.")
        }
        return treffer
    }

    /// Liefert den Gesamtbetrag einer einzelnen Position (nach art).
    func rechnungsposition(_ rechnungID: String, art: String) -> Decimal {
        let r = rechnung(rechnungID)
        guard let pos = r.positionen?.first(where: { $0.art == art }) else {
            fatalError("Position \"\(art)\" in Rechnung \(rechnungID) nicht gefunden.")
        }
        return pos.gesamt ?? 0
    }
}

enum TestdatenFehler: Error {
    case resourceNichtGefunden
}
