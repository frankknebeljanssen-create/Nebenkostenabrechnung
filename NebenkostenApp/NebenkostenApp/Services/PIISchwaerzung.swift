//
//  PIISchwaerzung.swift
//  NebenkostenApp — Services
//
//  Regex-basierte PII-Schwärzung VOR jedem AI-Call. Entfernt
//  personenbezogene Daten aus dem OCR-Text, bevor er an externe
//  Dienste geht — unverhandelbare Voraussetzung der 3-Ebenen-
//  Datenmodell-Architektur (siehe CLAUDE.md Task 1.2).
//
//  Geschwärzt werden:
//    - Adressen (Straße + Hausnummer + PLZ + Ort, ein- oder mehrzeilig)
//    - Telefonnummern (internationales + nationales Format)
//    - E-Mail-Adressen
//    - IBANs
//    - Eigennamen Mieter (aus Kontext)
//    - Eigenname Vermieter (aus Kontext)
//
//  Bewusst NICHT geschwärzt:
//    - Kundennummern / Vertragsnummern / Rechnungsnummern (6+
//      Ziffern ohne Kontext-Tag) — oft für Zuordnung gebraucht.
//    - Datumsangaben.
//    - Beträge.
//

import Foundation

/// Kontext-Daten für die Schwärzung: Mieter- und Vermieter-Namen
/// aus dem laufenden Daten-Store, damit Eigennamen spezifisch
/// geschwärzt werden können (Regex-Namens-Erkennung ist unzuverlässig).
struct PIIKontext: Sendable {
    var mieterNamen: [String] = []
    var vermieterName: String?

    static let leer = PIIKontext()
}

enum PIISchwaerzung {

    /// Wendet alle Regeln an. Reihenfolge ist wichtig — spezifische
    /// Pattern (IBAN, Email) vor generischen (Adresse, Telefon), damit
    /// kein Pattern ein anderes vorzeitig verschluckt.
    static func apply(text: String, kontext: PIIKontext = .leer) -> String {
        var out = text

        // 1. Namen aus Kontext (längste zuerst — sonst würde "Frank"
        //    Teile von "Frank Knebel-Janßen" ersetzen und den
        //    Nachnamen stehen lassen).
        if let vermieter = kontext.vermieterName, !vermieter.isEmpty {
            out = ersetzeAlle(out, muster: NSRegularExpression.escapedPattern(for: vermieter),
                              durch: "[VERMIETER]")
        }
        for name in kontext.mieterNamen.sorted(by: { $0.count > $1.count })
            where !name.isEmpty {
            out = ersetzeAlle(out, muster: NSRegularExpression.escapedPattern(for: name),
                              durch: "[MIETER]")
        }

        // 2. IBAN — Länderkennung + 2 Prüfziffern + 18–30 alphanumerische
        //    (für Deutschland 20 Ziffern; wir erlauben 18–30, mit
        //    optionalen Leerzeichen in 4er-Gruppen).
        out = ersetzeAlle(out,
            muster: #"[A-Z]{2}\d{2}(?:[\s]?[A-Z0-9]{4}){4,7}[\s]?[A-Z0-9]{0,4}"#,
            durch: "[IBAN]")

        // 3. E-Mail
        out = ersetzeAlle(out,
            muster: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#,
            durch: "[EMAIL]")

        // 4. Telefon — erfordert Kontext-Hinweise, damit 6+-Ziffern-
        //    Kundennummern nicht versehentlich geschwärzt werden:
        //    a) "+49 …" oder "+1 …" international
        //    b) "Tel:" oder "Tel." oder "Telefon:" gefolgt von Nummer
        //    c) Bindestrich-getrenntes nationales Format
        //       "0xxx-xxxxxxx" (Vorwahl + Bindestrich + Zahl)
        out = ersetzeAlle(out,
            muster: #"\+\d{1,3}[ \-/]?(?:\(?\d{1,6}\)?[ \-/]?)?\d{2,}(?:[ \-/]\d{2,})*"#,
            durch: "[TELEFON]")
        out = ersetzeAlle(out,
            muster: #"(?i)(?:Tel(?:efon)?\.?\s*:?\s*)(?:\+?[\d \-/()]{6,})"#,
            durch: "Tel.: [TELEFON]")
        out = ersetzeAlle(out,
            muster: #"\b0\d{2,5}[ \-/]\d{3,}(?:[ \-/]\d+)*"#,
            durch: "[TELEFON]")

        // 5. Adresse einzeilig — "Bahnhofstr. 37, 12207 Berlin" oder
        //    "Hauptstraße 12a · 10115 Berlin".
        out = ersetzeAlle(out,
            muster: #"[A-ZÄÖÜ][\wäöüÄÖÜß\-\.]+(?:straße|strasse|str\.|weg|allee|platz|ring|gasse|damm)\s+\d+[a-zA-Z]?[\s,·•\-]+\d{5}\s+[A-ZÄÖÜ][\wäöüÄÖÜß\-]+"#,
            durch: "[ADRESSE]",
            options: [.caseInsensitive])

        // 6. Adresse mehrzeilig — dasselbe mit Zeilenumbruch.
        out = ersetzeAlle(out,
            muster: #"[A-ZÄÖÜ][\wäöüÄÖÜß\-\.]+(?:straße|strasse|str\.|weg|allee|platz|ring|gasse|damm)\s+\d+[a-zA-Z]?\s*[\r\n]+\s*\d{5}\s+[A-ZÄÖÜ][\wäöüÄÖÜß\-]+"#,
            durch: "[ADRESSE]",
            options: [.caseInsensitive])

        return out
    }

    // MARK: - Helper

    private static func ersetzeAlle(
        _ input: String,
        muster: String,
        durch: String,
        options: NSRegularExpression.Options = []
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: muster, options: options) else {
            return input
        }
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        return regex.stringByReplacingMatches(
            in: input, options: [], range: range, withTemplate: durch
        )
    }
}
