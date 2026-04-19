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

    struct Objekt: Decodable {
        let gesamtflaeche_qm: Decimal
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
    }

    struct Zaehlerstaende: Decodable {
        let verbraeuche_berechnet: VerbraucheBerechnet

        struct VerbraucheBerechnet: Decodable {
            let wmz_kg_kwh: Decimal?
            let wmz_og_kwh: Decimal?
            let wmz_eg_kwh: Decimal?   // null in der Testdaten-JSON
            let ww_kg_m3: Decimal?
            let ww_eg_m3: Decimal?
            let ww_og_m3: Decimal?
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
}

enum TestdatenFehler: Error {
    case resourceNichtGefunden
}
