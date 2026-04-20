//
//  DateinameBuilder.swift
//  NebenkostenApp — Core
//
//  Deterministisches Dateinamens-Schema für gescannte / importierte
//  Dokumente (Task 1.1). Alle Dokumente werden als PDF gespeichert;
//  der Name folgt dem Schema:
//
//    YYYY-MM-DD_<Typ>_<Versorger>_<Kontext>[_<Betrag>EUR].pdf
//
//  Leere Optional-Felder werden ausgelassen, Doppel-Underscores
//  zusammengefasst. Der Fallback bei komplett leeren Daten ist
//    YYYY-MM-DD_Dokument_<UUID-4-Chars>.pdf
//

import Foundation

enum DateinameBuilder {

    struct Eingabe: Sendable {
        let datum: Date
        let dokumenttyp: Dokumenttyp
        let versorger: String?
        let kontext: String?
        let betragBrutto: Decimal?
        let id: UUID

        init(
            datum: Date = Date(),
            dokumenttyp: Dokumenttyp,
            versorger: String? = nil,
            kontext: String? = nil,
            betragBrutto: Decimal? = nil,
            id: UUID = UUID()
        ) {
            self.datum = datum
            self.dokumenttyp = dokumenttyp
            self.versorger = versorger
            self.kontext = kontext
            self.betragBrutto = betragBrutto
            self.id = id
        }
    }

    /// Baut einen Dateinamen nach Schema. Kollision-Check liegt beim
    /// Aufrufer — wenn `vorhandeneNamen` den Basis-Namen enthält,
    /// werden die ersten 4 Zeichen der UUID angehängt, bis der Name
    /// frei ist (max. 5 Versuche).
    static func build(
        from eingabe: Eingabe,
        vorhandeneNamen: Set<String> = []
    ) -> String {
        let basis = basisname(eingabe)
        let voll = basis + ".pdf"

        guard vorhandeneNamen.contains(voll) else {
            return voll
        }
        // Kollision: 4-Chars-UUID-Suffix
        var uuid = eingabe.id.uuidString.replacingOccurrences(of: "-", with: "")
        for offset in stride(from: 0, through: 16, by: 4) {
            let idx0 = uuid.index(uuid.startIndex, offsetBy: offset)
            let idx1 = uuid.index(idx0, offsetBy: 4)
            let suffix = String(uuid[idx0..<idx1])
            let neu = "\(basis)_\(suffix).pdf"
            if !vorhandeneNamen.contains(neu) {
                return neu
            }
        }
        // Fallback: extrem unwahrscheinlich (5 Kollisionen in Folge).
        return "\(basis)_\(UUID().uuidString.prefix(4)).pdf"
    }

    // MARK: - Intern

    private static func basisname(_ e: Eingabe) -> String {
        var teile: [String] = [datumPraefix(e.datum), typKurz(e.dokumenttyp)]

        if let v = normalisiere(e.versorger), !v.isEmpty {
            teile.append(v)
        }
        if let k = normalisiere(e.kontext), !k.isEmpty {
            teile.append(k)
        }
        if let b = e.betragBrutto {
            teile.append(betragKurz(b))
        }

        // Wenn nur Datum + Typ (der aber "Sonstiges" → "Dokument" ist
        // und keine weiteren Infos): Fallback mit UUID-4-Chars.
        if teile.count == 2 && e.dokumenttyp == .sonstiges {
            let kurz = String(e.id.uuidString.prefix(4))
            teile.append(kurz)
        }

        let roh = teile.joined(separator: "_")
        return roh
            .replacingOccurrences(of: "__+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }

    private static func datumPraefix(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: d)
    }

    static func typKurz(_ t: Dokumenttyp) -> String {
        switch t {
        case .rechnung:          return "Rechnung"
        case .bescheid:          return "Bescheid"
        case .handwerkerbeleg:   return "Beleg"
        case .winterdienstbeleg: return "Beleg"
        case .zaehlerfoto:       return "Zaehlerfoto"
        case .mietvertrag:       return "Mietvertrag"
        case .sonstiges:         return "Dokument"
        }
    }

    /// Normalisiert einen freien User-String für Dateinamen: Umlaute,
    /// Whitespace, Sonderzeichen. Leere Strings und nil → nil.
    static func normalisiere(_ s: String?) -> String? {
        guard let roh = s?.trimmingCharacters(in: .whitespaces), !roh.isEmpty else {
            return nil
        }
        var x = roh
        // Umlaute
        let karten: [(String, String)] = [
            ("ä", "ae"), ("ö", "oe"), ("ü", "ue"),
            ("Ä", "Ae"), ("Ö", "Oe"), ("Ü", "Ue"),
            ("ß", "ss")
        ]
        for (von, zu) in karten {
            x = x.replacingOccurrences(of: von, with: zu)
        }
        // Whitespace → Underscore
        x = x.replacingOccurrences(
            of: "\\s+", with: "_", options: .regularExpression
        )
        // Unerlaubte Datei-System-Zeichen
        let erlaubt = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        x = x.unicodeScalars
            .map { erlaubt.contains($0) ? Character($0) : "_" }
            .map(String.init)
            .joined()
        // Doppel-Underscores eindampfen
        x = x.replacingOccurrences(
            of: "__+", with: "_", options: .regularExpression
        )
        return x.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }

    static func betragKurz(_ d: Decimal) -> String {
        let rounded = d.gerundet(auf: 2, modus: .kaufmaennisch)
        let s = NSDecimalNumber(decimal: rounded).stringValue
        // Komma/Punkt → Dash (Systemspezifisch), keine Dezimaltrenner
        // im Dateinamen.
        let mitDash = s
            .replacingOccurrences(of: ".", with: "-")
            .replacingOccurrences(of: ",", with: "-")
        return "\(mitDash)EUR"
    }
}
