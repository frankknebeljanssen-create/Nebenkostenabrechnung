//
//  ScopeTexte.swift
//  NebenkostenApp — UI/Components
//
//  Zentrale Text-Formatierung für den Scope-Picker und die
//  ScopeIndicatorBar. Sorgt dafür, dass Mieter-Namen überall
//  konsistent abgekürzt angezeigt werden.
//

import Foundation

enum ScopeTexte {

    /// Label für den Objekt-Scope im Picker und im Indicator.
    static let gesamtLabel = "Gesamtes Objekt"

    /// Kürzt einen Mieter-Namen für Tooltip- und Titel-Anzeigen:
    /// - Beginnt mit "Familie ": Präfix "Fam. " + Nachname.
    /// - Sonst: Vornamen auf ersten Buchstaben mit Punkt, Nachname
    ///   (das letzte Wort) voll.
    ///
    /// Beispiele:
    ///   "Familie Sandra und Daniel Pfaffenbach" → "Fam. Pfaffenbach"
    ///   "Frank Knebel-Janßen"                  → "F. Knebel-Janßen"
    ///   "Verena Janßen"                        → "V. Janßen"
    ///   ""                                     → ""
    static func abkuerzungName(_ voll: String) -> String {
        let getrimmt = voll.trimmingCharacters(in: .whitespaces)
        guard !getrimmt.isEmpty else { return "" }

        if let rest = rumpfNachFamilienprefix(getrimmt) {
            let worte = rest.split(whereSeparator: { $0.isWhitespace })
            guard let nachname = worte.last else { return "Fam." }
            return "Fam. \(nachname)"
        }

        let worte = getrimmt
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        guard worte.count >= 2 else { return getrimmt }
        let nachname = worte.last!
        let initialen = worte.dropLast()
            .compactMap { $0.first.map { "\($0)." } }
            .joined(separator: " ")
        return "\(initialen) \(nachname)"
    }

    /// Titel für den Picker- bzw. Indicator-Header.
    ///   objekt  → "Gesamtes Objekt"
    ///   einheit → "OG · Fam. Pfaffenbach" (oder nur "OG", wenn kein
    ///   Mieter vorhanden)
    static func scopeTitel(einheitID: String?, mieterName: String) -> String {
        guard let id = einheitID, !id.isEmpty else {
            return gesamtLabel
        }
        let kurz = abkuerzungName(mieterName)
        if kurz.isEmpty { return id }
        return "\(id) · \(kurz)"
    }

    // MARK: - Intern

    private static func rumpfNachFamilienprefix(_ text: String) -> String? {
        let varianten = ["Familie ", "Fam. ", "Fam "]
        for p in varianten where text.hasPrefix(p) {
            return String(text.dropFirst(p.count)).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }
}
