//
//  StringGrossschreibung.swift
//  NebenkostenApp — Core
//
//  Sicherheitsnetz fuer Claude-Extraktionen: wenn das Modell
//  Namen / Adressen trotz Prompt-Regel kleingeschrieben liefert,
//  korrigieren wir die Groß/Kleinschreibung lokal.
//
//  Bewusst NICHT universell angewandt — Betraege, IBANs, Datums-
//  Strings, technische Keys (z.B. Aktenzeichen) bleiben unveraendert.
//  Der Aufrufer (ScanKlassifikator.parse) entscheidet per Feld-Key,
//  ob die Extension greift.
//

import Foundation

extension String {
    /// „rolf kossak" → „Rolf Kossak". „HINDENBURGDAMM 102" →
    /// „Hindenburgdamm 102". „von der heide" → „Von Der Heide"
    /// (Kleinigkeiten wie „von"/„der" bleiben gross — ist bei
    /// deutschen Namen eher selten problematisch; der User kann
    /// das Feld inline editieren wenn's falsch ist).
    var alsName: String {
        split(separator: " ")
            .map { wort -> String in
                guard let first = wort.first else { return "" }
                return String(first).uppercased()
                    + wort.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }
}
