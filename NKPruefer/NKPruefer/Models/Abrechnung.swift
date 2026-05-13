import Foundation

// MARK: - Abrechnung (Parser-Output)
//
// v4-16c: Fast alle Felder sind optional. Der Parser-LLM liefert `null`
// für Werte, die nicht auf der Abrechnung stehen — das ist korrektes
// Verhalten. Required bleiben nur die Felder, ohne die die Pipeline
// gar nicht laufen kann (`zeitraum.von/bis`, Kostenpositions-Kern).

struct Abrechnung: Codable, Sendable {
    let meta: AbrechnungMeta
    let kostenpositionen: [Kostenposition]
    let summeAnteile: Decimal?
    let confidenceGesamt: Confidence?
    let warnungen: [String]?

    enum CodingKeys: String, CodingKey {
        case meta
        case kostenpositionen
        case summeAnteile = "summe_mieter_anteile"
        case confidenceGesamt = "confidence_gesamt"
        case warnungen
    }
}

// MARK: - Meta

struct AbrechnungMeta: Codable, Sendable {
    let vermieter: ParsedVermieter
    let objekt: ParsedObjekt
    let zeitraum: Zeitraum
    let mieterEinheit: MieterEinheit
    let vorauszahlungenGesamt: Decimal?
    let nachzahlungOderGuthaben: Decimal?
    let typ: AbrechnungsTyp?

    enum CodingKeys: String, CodingKey {
        case vermieter
        case objekt
        case zeitraum
        case mieterEinheit = "mieter_einheit"
        case vorauszahlungenGesamt = "vorauszahlungen_gesamt"
        case nachzahlungOderGuthaben = "nachzahlung_oder_guthaben"
        case typ
    }
}

struct ParsedVermieter: Codable, Sendable {
    let name: String?
    let adresse: String?
}

struct ParsedObjekt: Codable, Sendable {
    let adresse: String?
    let gesamtflaecheQm: Decimal?
    let anzahlEinheiten: Int?
    let baujahr: Int?

    enum CodingKeys: String, CodingKey {
        case adresse
        case gesamtflaecheQm = "gesamtflaeche_qm"
        case anzahlEinheiten = "anzahl_einheiten"
        case baujahr
    }
}

struct Zeitraum: Codable, Sendable {
    let von: Date
    let bis: Date
}

struct MieterEinheit: Codable, Sendable {
    let bezeichnung: String?
    let flaecheQm: Decimal?
    let personen: Int?

    enum CodingKeys: String, CodingKey {
        case bezeichnung
        case flaecheQm = "flaeche_qm"
        case personen
    }
}

enum AbrechnungsTyp: String, Codable, Sendable {
    case nachzahlung
    case guthaben
}

// MARK: - Kostenposition

struct Kostenposition: Codable, Identifiable, Sendable {
    let id: Int
    let bezeichnungOriginal: String
    let kostenartNormalisiert: String?
    let gesamtkosten: Decimal?
    let verteilerschluessel: Verteilerschluessel
    let mieterAnteil: Decimal
    let confidence: Confidence?
    let notiz: String?

    enum CodingKeys: String, CodingKey {
        case id
        case bezeichnungOriginal = "bezeichnung_original"
        case kostenartNormalisiert = "kostenart_normalisiert"
        case gesamtkosten
        case verteilerschluessel
        case mieterAnteil = "mieter_anteil"
        case confidence
        case notiz
    }
}

enum Verteilerschluessel: String, Codable, Sendable {
    case wohnflaeche
    case personenzahl
    case einheiten
    case verbrauch
    case miteigentumsanteil
    case unbekannt
}

enum Confidence: String, Codable, Sendable {
    case high
    case medium
    case low
}
