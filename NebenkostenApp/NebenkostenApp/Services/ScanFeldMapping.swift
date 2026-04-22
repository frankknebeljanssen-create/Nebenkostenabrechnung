//
//  ScanFeldMapping.swift
//  NebenkostenApp — Services
//
//  Typ → „welche Felder landen im System, und wie heissen sie dem User
//  gegenueber". Wird vom `UniversellerAnalyseScreen` benutzt, um die
//  Sections „WIRD UEBERNOMMEN" vs „NICHT UEBERNOMMEN" aufzuspannen:
//
//    - Ein Feld vom Klassifikator, dessen `quellKey` in `ziele(typ:)`
//      auftaucht, landet in „WIRD UEBERNOMMEN" (inline editierbar).
//    - Alle anderen erkannten Felder sind nur Kontext und erscheinen
//      in „NICHT UEBERNOMMEN" (read-only).
//
//  Das Mapping hat KEINE Auswirkung auf die eigentliche Persistenz —
//  das macht die `uebernehmen`-Logik im Screen abhaengig vom Typ. Hier
//  geht es nur um die UI-Darstellung + Label-Texte.
//

import Foundation

struct ScanZielFeld: Hashable, Sendable {
    /// Key im `ScanKlassifikationsErgebnis.felder`-Dict.
    let quellKey: String
    /// User-sichtbarer Name in der Uebernahme-Liste.
    let anzeige: String
}

enum ScanFeldMapping {

    /// Liefert die Ziel-Felder pro Typ — in einer sinnvollen Reihenfolge
    /// fuer die UI (wichtig zuerst).
    static func ziele(typ: Dokumenttyp) -> [ScanZielFeld] {
        switch typ {
        case .rechnung, .bescheid, .handwerkerbeleg, .winterdienstbeleg:
            return [
                .init(quellKey: "absender",           anzeige: "Lieferant"),
                .init(quellKey: "datum",              anzeige: "Rechnungsdatum"),
                .init(quellKey: "leistungszeitraum",  anzeige: "Leistungszeitraum"),
                .init(quellKey: "betrag",             anzeige: "Betrag"),
                .init(quellKey: "iban",               anzeige: "IBAN"),
                .init(quellKey: "kundennummer",       anzeige: "Kundennummer"),
            ]

        case .erhoehungsschreiben:
            return [
                .init(quellKey: "kaltmieteAlt",       anzeige: "Alte Kaltmiete"),
                .init(quellKey: "kaltmieteNeu",       anzeige: "Neue Kaltmiete"),
                .init(quellKey: "nkVorauszahlungAlt", anzeige: "Alte NK-Vorauszahlung"),
                .init(quellKey: "nkVorauszahlungNeu", anzeige: "Neue NK-Vorauszahlung"),
                .init(quellKey: "gueltigAb",          anzeige: "Gültig ab"),
            ]

        case .mietvertrag:
            return [
                .init(quellKey: "mieter",             anzeige: "Mieter"),
                .init(quellKey: "einzugAm",           anzeige: "Einzug"),
                .init(quellKey: "kaltmieteEuro",      anzeige: "Kaltmiete"),
                .init(quellKey: "nkVorauszahlungEuro",anzeige: "NK-Vorauszahlung"),
                .init(quellKey: "flaecheM2",          anzeige: "Fläche"),
                .init(quellKey: "zimmer",             anzeige: "Zimmer"),
            ]

        case .hvAbrechnung:
            return [
                .init(quellKey: "verwalter",          anzeige: "Verwalter"),
                .init(quellKey: "zeitraum",           anzeige: "Zeitraum"),
                .init(quellKey: "meaAnteil",          anzeige: "MEA-Anteil"),
                .init(quellKey: "gesamtkosten",       anzeige: "Gesamtkosten"),
                .init(quellKey: "umlagefaehigGesamt", anzeige: "Umlagefähig"),
                .init(quellKey: "eigentuemerGesamt", anzeige: "Eigentümer"),
                .init(quellKey: "lohnanteil35a",      anzeige: "§35a Lohnanteil"),
            ]

        case .energieausweis:
            return [
                .init(quellKey: "ausstellungsdatum",  anzeige: "Ausgestellt am"),
                .init(quellKey: "gueltigBis",         anzeige: "Gültig bis"),
                .init(quellKey: "energieklasse",      anzeige: "Energieklasse"),
                .init(quellKey: "endenergiebedarf",   anzeige: "Endenergiebedarf"),
            ]

        case .grundsteuerbescheid:
            return [
                .init(quellKey: "amt",                anzeige: "Finanzamt"),
                .init(quellKey: "aktenzeichen",       anzeige: "Aktenzeichen"),
                .init(quellKey: "datum",              anzeige: "Bescheiddatum"),
                .init(quellKey: "jahresbetrag",       anzeige: "Jahresbetrag"),
            ]

        case .zaehlerfoto:
            return [
                .init(quellKey: "zaehlerart",         anzeige: "Zählerart"),
                .init(quellKey: "standWert",          anzeige: "Zählerstand"),
                .init(quellKey: "einheit",            anzeige: "Einheit"),
            ]

        case .unbekannt, .sonstiges:
            return []
        }
    }

    /// Welcher Typ hat heute eine produktive Persistenz-Route? Fuer die
    /// Uebrigen landet „Uebernehmen" auf einem Toast mit
    /// „folgt in naechstem Task"-Hinweis. Ehrlich gegenueber dem User.
    static func hatProduktivenSavePath(_ typ: Dokumenttyp) -> Bool {
        switch typ {
        case .rechnung, .bescheid, .handwerkerbeleg, .winterdienstbeleg,
             .energieausweis, .grundsteuerbescheid:
            return true
        case .erhoehungsschreiben, .mietvertrag, .hvAbrechnung,
             .zaehlerfoto, .unbekannt, .sonstiges:
            return false
        }
    }
}
