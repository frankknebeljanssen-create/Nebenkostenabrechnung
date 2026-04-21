//
//  StandardKostenarten.swift
//  NebenkostenApp — Services
//
//  Legt fuer eine neu angelegte Immobilie die Standard-
//  Kostenarten an. Drei Objekt-Typen, je eigener Katalog:
//
//  - `.gesamtgebaeude` — Vermieter mit eigener Anlage, mehrere
//    Einheiten, voller BetrKV-Katalog. Mit/ohne
//    Zentralheizungs-Kostenart je nach `mitZentralheizung`-Flag.
//  - `.einzelneWE` — Eine Wohneinheit in einem Fremdgebaeude
//    (typisch: Eigentuemergemeinschaft, Hausverwaltung liefert
//    WEG-Abrechnung, die durchgereicht wird). Minimal-Katalog.
//  - `.einfachObjekt` — Datsche / einfaches Haus ohne zentrale
//    Haustechnik. Nur Grundkosten.
//
//  Aufgerufen aus:
//  - `SeedData` (Bahnhofstr. 37 → gesamtgebaeude + Heizung).
//    Siehe `SeedData.bauKostenarten` fuer die historische
//    Version; dieser Service uebernimmt dort die Liste.
//  - `NeuesObjektSheet` (Nutzer-Anlage — Typ frei waehlbar).
//

import Foundation
import SwiftData

@MainActor
enum StandardKostenarten {

    enum Typ: String, CaseIterable, Identifiable, Sendable {
        case gesamtgebaeude
        case einzelneWE
        case einfachObjekt

        var id: String { rawValue }

        var anzeigeName: String {
            switch self {
            case .gesamtgebaeude: return "Gesamtgebäude"
            case .einzelneWE:     return "WE in Fremdgebäude"
            case .einfachObjekt:  return "Einfaches Objekt / Datsche"
            }
        }

        var beschreibung: String {
            switch self {
            case .gesamtgebaeude:
                return "Eigene Anlage, mehrere Einheiten — voller BetrKV-Katalog"
            case .einzelneWE:
                return "Hausverwaltungs-Abrechnung wird weitergereicht — minimal"
            case .einfachObjekt:
                return "Nur Grundkosten — Grundsteuer, Versicherung, Gartenpflege"
            }
        }
    }

    /// Legt die Standard-Kostenarten fuer die Immobilie an und
    /// persistiert sie im Context.
    /// - Parameters:
    ///   - typ: Objekt-Typ — bestimmt den Katalog.
    ///   - mitZentralheizung: nur relevant fuer
    ///     `.gesamtgebaeude` — ohne Heizung entfaellt die
    ///     „Heizung und Warmwasser"-Kostenart.
    static func anlegen(
        fuer immobilie: Immobilie,
        typ: Typ,
        mitZentralheizung: Bool,
        context: ModelContext
    ) {
        let entwuerfe = entwuerfeFuer(typ: typ, mitZentralheizung: mitZentralheizung)
        for (index, e) in entwuerfe.enumerated() {
            let ka = Kostenart()
            ka.bezeichnung = e.bezeichnung
            ka.betrKvKategorie = e.betrKv
            ka.umlageschluessel = e.schluessel
            ka.paragraph35a = e.p35a
            ka.paragraph35aNurLohnanteil = e.nurLohn
            ka.aktiv = true
            ka.sortierung = (index + 1) * 10
            ka.immobilie = immobilie
            context.insert(ka)
        }
    }

    // MARK: - Intern

    private struct Entwurf {
        let bezeichnung: String
        let betrKv: String
        let schluessel: Umlageschluessel
        let p35a: Bool
        let nurLohn: Bool
    }

    private static func entwuerfeFuer(
        typ: Typ,
        mitZentralheizung: Bool
    ) -> [Entwurf] {
        switch typ {
        case .gesamtgebaeude:
            return gesamtgebaeudeKatalog(mitZentralheizung: mitZentralheizung)
        case .einzelneWE:
            return einzelneWEKatalog()
        case .einfachObjekt:
            return einfachObjektKatalog()
        }
    }

    private static func gesamtgebaeudeKatalog(mitZentralheizung: Bool) -> [Entwurf] {
        var liste: [Entwurf] = [
            .init(bezeichnung: "Grundsteuer",                 betrKv: "1",       schluessel: .flaeche,   p35a: false, nurLohn: false),
            .init(bezeichnung: "Be- und Entwässerung",        betrKv: "2 + 3",   schluessel: .verbrauch, p35a: false, nurLohn: false)
        ]
        if mitZentralheizung {
            liste.append(
                .init(bezeichnung: "Heizung und Warmwasser",  betrKv: "4a + 4b", schluessel: .heizkosten3070, p35a: false, nurLohn: false)
            )
        }
        liste.append(contentsOf: [
            .init(bezeichnung: "Müllabfuhr",                  betrKv: "8",       schluessel: .flaeche,   p35a: false, nurLohn: false),
            .init(bezeichnung: "Gebäudeversicherung",         betrKv: "13",      schluessel: .flaeche,   p35a: false, nurLohn: false),
            .init(bezeichnung: "Gartenpflege",                betrKv: "10",      schluessel: .flaeche,   p35a: true,  nurLohn: true),
            .init(bezeichnung: "Gebäudereinigung",            betrKv: "9",       schluessel: .flaeche,   p35a: true,  nurLohn: false),
            .init(bezeichnung: "Schnee- und Eisbeseitigung",  betrKv: "8",       schluessel: .flaeche,   p35a: true,  nurLohn: true),
            .init(bezeichnung: "Allgemeinstrom",              betrKv: "11",      schluessel: .flaeche,   p35a: false, nurLohn: false)
        ])
        return liste
    }

    private static func einzelneWEKatalog() -> [Entwurf] {
        [
            .init(bezeichnung: "Hausgeld-Abrechnung (WEG)",   betrKv: "1-17",    schluessel: .flaeche,   p35a: false, nurLohn: false),
            .init(bezeichnung: "Grundsteuer",                 betrKv: "1",       schluessel: .flaeche,   p35a: false, nurLohn: false),
            .init(bezeichnung: "Sonstige umlagefähige Kosten", betrKv: "17",     schluessel: .flaeche,   p35a: false, nurLohn: false)
        ]
    }

    private static func einfachObjektKatalog() -> [Entwurf] {
        [
            .init(bezeichnung: "Grundsteuer",                 betrKv: "1",       schluessel: .flaeche,   p35a: false, nurLohn: false),
            .init(bezeichnung: "Gebäudeversicherung",         betrKv: "13",      schluessel: .flaeche,   p35a: false, nurLohn: false),
            .init(bezeichnung: "Gartenpflege",                betrKv: "10",      schluessel: .flaeche,   p35a: true,  nurLohn: true),
            .init(bezeichnung: "Sonstige Kosten",             betrKv: "17",      schluessel: .flaeche,   p35a: false, nurLohn: false)
        ]
    }
}
