//
//  ScanZuordnung.swift
//  NebenkostenApp — Services
//
//  Auto-Zuordnung eines gescannten Dokuments zu Immobilie + Wohneinheit
//  auf Basis der vom `ScanKlassifikator` extrahierten Felder. Reine
//  Funktion — kein SwiftUI, kein State, testbar.
//
//  Matching-Heuristik (einfach, aber robust genug fuer die ueblichen
//  Vermieter-Dokumente):
//    - Adresse: Teilstring-Match der Strasse + Hausnummer aus dem
//      Dokument (`objektAdresse` oder `adresse`) gegen `Immobilie
//      .adresse`.
//    - Mieter-Name: Wortweise Teilstring-Match aus `mieterName` oder
//      `empfaenger` gegen `Mietverhaeltnis.mieterName`. Wir schauen
//      nur auf aktuelle Mieter (`auszugAm == nil`) — der Vermieter
//      waehlt beim Scannen keinen ausgezogenen Mieter.
//    - Einheit-Bezeichnung: direkte Teilstring-Suche (z.B. "OG").
//
//  Score-Modell (Zahlen ausgewuerfelt, nicht super-fein-kalibriert):
//    Adresse: 3 · Mieter-Name: 2 · Einheit-Bezeichnung: 1
//
//  Ergebnis:
//    - Genau ein Kandidat mit Punkten > 0: `.gefunden`.
//    - Mehrere Kandidaten mit gleichem Top-Score: `.mehrdeutig`.
//    - Kein Kandidat mit Punkten > 0: `.nichtGefunden`.
//

import Foundation

@MainActor
enum ScanZuordnung {

    struct Kandidat: Hashable, Sendable {
        let immobilieID: UUID
        let einheitBezeichnung: String?  // nil = Objekt-weit (z.B. Energieausweis)
        let score: Int
    }

    enum Ergebnis: Sendable {
        case gefunden(Kandidat)
        case mehrdeutig([Kandidat])
        case nichtGefunden
    }

    /// Liefert die Zuordnung + die Liste aller nicht-null Kandidaten
    /// fuer den manuellen Picker. Wenn der `typ` Objekt-weit ist
    /// (Energieausweis, Grundsteuer), wird NIE eine Einheit
    /// zurueckgegeben — die Dokumente haengen an der Immobilie.
    static func finde(
        typ: Dokumenttyp,
        felder: [String: String],
        immobilien: [Immobilie]
    ) -> Ergebnis {
        let objektWeit = istObjektWeit(typ)

        // Query-Strings aus den Feldern.
        let adressQuery = normalisiere(
            felder["objektAdresse"] ?? felder["adresse"] ?? ""
        )
        let mieterQuery = normalisiere(
            felder["mieterName"] ?? felder["empfaenger"] ?? ""
        )
        let einheitQuery = normalisiere(
            felder["einheit"] ?? felder["wohneinheit"] ?? felder["geschoss"] ?? ""
        )

        var kandidaten: [Kandidat] = []

        for immo in immobilien {
            let immoAdresse = normalisiere(immo.adresse)
            let adressMatch = !adressQuery.isEmpty
                && enthaeltWortweise(target: immoAdresse, query: adressQuery)

            if objektWeit {
                // Energieausweis / Grundsteuer: nur Objekt-Match zaehlt.
                let score = adressMatch ? 3 : 0
                if score > 0 || immobilien.count == 1 {
                    // Einziges Objekt → auch ohne Adress-Match vorschlagen
                    // (Score 0, aber unstrittig).
                    kandidaten.append(Kandidat(
                        immobilieID: immo.id,
                        einheitBezeichnung: nil,
                        score: immobilien.count == 1 && score == 0 ? 1 : score
                    ))
                }
                continue
            }

            // Einheiten-bezogener Typ (Rechnung, Mieterhoehung, Mietvertrag, …)
            for einheit in (immo.wohneinheiten ?? []) {
                var score = adressMatch ? 3 : 0

                // Aktiver Mieter
                let aktiverMV = (einheit.mietverhaeltnisse ?? [])
                    .first(where: { $0.auszugAm == nil })
                if let mv = aktiverMV, !mieterQuery.isEmpty {
                    let mvName = normalisiere(mv.mieterName)
                    if enthaeltWortweise(target: mvName, query: mieterQuery) {
                        score += 2
                    }
                }

                // WE-Bezeichnung
                let einheitBez = normalisiere(einheit.bezeichnung)
                if !einheitQuery.isEmpty
                    && enthaeltWortweise(target: einheitBez, query: einheitQuery) {
                    score += 1
                }

                if score > 0 {
                    kandidaten.append(Kandidat(
                        immobilieID: immo.id,
                        einheitBezeichnung: einheit.bezeichnung,
                        score: score
                    ))
                }
            }
        }

        guard !kandidaten.isEmpty else { return .nichtGefunden }
        let sortiert = kandidaten.sorted(by: { $0.score > $1.score })
        let topScore = sortiert[0].score
        let tops = sortiert.filter { $0.score == topScore }
        if tops.count == 1 {
            return .gefunden(tops[0])
        }
        return .mehrdeutig(tops)
    }

    /// Dokumente, die an der Immobilie haengen (nicht an einer WE).
    static func istObjektWeit(_ typ: Dokumenttyp) -> Bool {
        switch typ {
        case .energieausweis, .grundsteuerbescheid, .hvAbrechnung:
            return true
        case .rechnung, .bescheid, .handwerkerbeleg, .winterdienstbeleg,
             .mietvertrag, .erhoehungsschreiben, .zaehlerfoto,
             .unbekannt, .sonstiges:
            return false
        }
    }

    // MARK: - Normalisierung + Matching

    /// Lowercase, Umlaute weg, Interpunktion raus. Behaelt Leerzeichen
    /// als Wort-Separator.
    static func normalisiere(_ roh: String) -> String {
        var s = roh.lowercased()
        let ersatz: [(Character, String)] = [
            ("ä", "ae"), ("ö", "oe"), ("ü", "ue"), ("ß", "ss")
        ]
        for (ch, repl) in ersatz {
            s = s.replacingOccurrences(of: String(ch), with: repl)
        }
        let erlaubt = CharacterSet.alphanumerics.union(.whitespaces)
        s = String(s.unicodeScalars.map { erlaubt.contains($0) ? Character($0) : " " })
        // Mehrfache Whitespace-Sequenzen zu einem Leerzeichen.
        while s.contains("  ") {
            s = s.replacingOccurrences(of: "  ", with: " ")
        }
        return s.trimmingCharacters(in: .whitespaces)
    }

    /// Alle Worte (>=3 Zeichen) aus `query` muessen in `target` vorkommen
    /// (Teilstring). Sehr kurze Worte (und, der, …) werden ignoriert,
    /// damit „Fam. Kossak" → nur Kossak pruefen.
    private static func enthaeltWortweise(target: String, query: String) -> Bool {
        let worte = query.split(separator: " ").filter { $0.count >= 3 }
        guard !worte.isEmpty else { return false }
        return worte.allSatisfy { target.contains($0) }
    }
}
