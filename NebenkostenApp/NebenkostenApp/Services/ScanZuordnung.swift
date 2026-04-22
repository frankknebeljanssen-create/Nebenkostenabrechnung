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

        // Query-Strings aus den Feldern. Claude schreibt den Mieter-
        // Namen je nach Prompt mal unter `mieterName`, mal unter
        // `empfaenger`, mal als `mieter` — wir pruefen alle drei.
        // Analog die Adresse: `objektAdresse` bevorzugt, sonst
        // `mieterAnschrift`, sonst generisch `adresse`.
        let adressQuery = strasseHausnr(
            felder["objektAdresse"]
            ?? felder["mieterAnschrift"]
            ?? felder["adresse"]
            ?? ""
        )
        let mieterQuery = normalisiere(
            felder["mieterName"]
            ?? felder["empfaenger"]
            ?? felder["mieter"]
            ?? ""
        )
        let einheitQuery = normalisiere(
            felder["einheit"] ?? felder["wohneinheit"] ?? felder["geschoss"] ?? ""
        )

        print("🔍 ScanZuordnung.finde typ=\(typ.rawValue)")
        print("   mieterQuery='\(mieterQuery)'")
        print("   adressQuery='\(adressQuery)'")
        print("   einheitQuery='\(einheitQuery)'")

        var kandidaten: [Kandidat] = []

        for immo in immobilien {
            let immoAdresse = strasseHausnr(immo.adresse)
            let adressMatch = !adressQuery.isEmpty
                && istAehnlich(immoAdresse, adressQuery)
            print("   · Immobilie '\(immo.adresse)' → normalisiert='\(immoAdresse)' adressMatch=\(adressMatch)")

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
                var grund = adressMatch ? "Adresse(+3) " : ""

                // Aktiver Mieter
                let aktiverMV = (einheit.mietverhaeltnisse ?? [])
                    .first(where: { $0.auszugAm == nil })
                if let mv = aktiverMV, !mieterQuery.isEmpty {
                    let mvName = normalisiere(mv.mieterName)
                    if istAehnlich(mvName, mieterQuery) {
                        score += 2
                        grund += "Mieter(+2) "
                    }
                }

                // WE-Bezeichnung
                let einheitBez = normalisiere(einheit.bezeichnung)
                if !einheitQuery.isEmpty
                    && istAehnlich(einheitBez, einheitQuery) {
                    score += 1
                    grund += "Einheit(+1)"
                }

                print("     ↳ WE \(einheit.bezeichnung) mv='\(aktiverMV?.mieterName ?? "–")' score=\(score) \(grund)")

                if score > 0 {
                    kandidaten.append(Kandidat(
                        immobilieID: immo.id,
                        einheitBezeichnung: einheit.bezeichnung,
                        score: score
                    ))
                }
            }
        }

        guard !kandidaten.isEmpty else {
            print("   ⇒ kein Kandidat")
            return .nichtGefunden
        }
        let sortiert = kandidaten.sorted(by: { $0.score > $1.score })
        let topScore = sortiert[0].score
        let tops = sortiert.filter { $0.score == topScore }
        if tops.count == 1 {
            print("   ⇒ gefunden score=\(topScore)")
            return .gefunden(tops[0])
        }
        print("   ⇒ mehrdeutig: \(tops.count) Kandidaten mit score=\(topScore)")
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

    /// Robustes Match: zwei (normalisierte) Strings gelten als aehnlich,
    /// wenn einer den anderen als Teilstring enthaelt.
    /// Beispiele (beide normalisiert):
    ///   - „rolf kossak" ↔ „herr rolf kossak"  → match (query ⊂ target)
    ///   - „familie pfaffenbach" ↔ „sandra pfaffenbach"  → kein Match
    ///     (weder enthaelt den anderen) — bewusst: „Familie" ohne
    ///     Nachnamen-Uebereinstimmung ist zu vage. Beide haben aber
    ///     „pfaffenbach" als Wort — dafuer gibt es den WE-bezogenen
    ///     Score-Fallback via Adresse.
    ///   - „kossak" ↔ „rolf kossak"  → match (query ⊂ target)
    /// Zusatz: Auch wenn query nur EIN Wort ist, pruefen wir, ob
    /// dieses Wort im Target vorkommt — deckt den Claude-Fall ab, wo
    /// nur der Nachname extrahiert wird.
    static func istAehnlich(_ a: String, _ b: String) -> Bool {
        guard !a.isEmpty, !b.isEmpty else { return false }
        if a == b { return true }
        if a.contains(b) || b.contains(a) { return true }
        // Fallback: wenn die Query nur ein „wichtiges" Wort ist
        // (>=4 Zeichen, um „herr"/„frau" auszublenden), pruefe,
        // ob das Wort im Target vorkommt. Loest den Fall
        // „Kossak" gegen „Rolf Kossak".
        let aWorte = a.split(separator: " ").filter { $0.count >= 4 }
        let bWorte = b.split(separator: " ").filter { $0.count >= 4 }
        if aWorte.count == 1, b.contains(aWorte[0]) { return true }
        if bWorte.count == 1, a.contains(bWorte[0]) { return true }
        return false
    }

    /// Reduziert eine Adresse auf Strasse + Hausnummer — der erste
    /// Komma-Teil. So matched „Hindenburgdamm 102" auch dann, wenn das
    /// System die PLZ + Ort dahinter speichert („Hindenburgdamm 102,
    /// 12203 Berlin"). Output wird gleich normalisiert.
    static func strasseHausnr(_ adresse: String) -> String {
        let teile = adresse.split(separator: ",")
        let erster = teile.first.map(String.init) ?? adresse
        return normalisiere(erster)
    }
}
