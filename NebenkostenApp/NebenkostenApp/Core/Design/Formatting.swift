//
//  Formatting.swift
//  NebenkostenApp — Core/Design
//
//  Zentrale Formatter für die Darstellung aller User-sichtbaren
//  Werte. Locale hart auf de_DE — deutsche Tausenderformatierung mit
//  Punkt und Dezimalkomma, en-dash für Perioden, U+2212-Minus für
//  negative Beträge (nicht der Hyphen-Minus von ASCII).
//

import Foundation

enum Formatting {

    private static let locale = Locale(identifier: "de_DE")

    // MARK: - Euro

    /// Formatiert einen Decimal als deutschen Euro-Betrag.
    /// - Parameter showSign: Wenn true, wird auch bei positiven Werten
    ///   ein "+" vorangestellt. Default false — nur negative Werte
    ///   bekommen "− ".
    ///
    /// Beispiele:
    ///   4127.84              → "4.127,84 €"
    ///   -593.05              → "− 593,05 €"
    ///   4127.84, showSign:t  → "+ 4.127,84 €"
    static func euro(_ value: Decimal, showSign: Bool = false) -> String {
        let betrag = betragFormatter.string(
            from: NSDecimalNumber(decimal: abs(value))
        ) ?? "0,00"
        let negativ = value < 0
        let prefix: String
        if negativ {
            prefix = "\u{2212} "       // U+2212 MINUS SIGN
        } else if showSign {
            prefix = "+ "
        } else {
            prefix = ""
        }
        return "\(prefix)\(betrag) €"
    }

    private static let betragFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.groupingSeparator = "."
        f.decimalSeparator = ","
        f.usesGroupingSeparator = true
        return f
    }()

    // MARK: - Datum / Periode

    /// "dd.MM.yyyy", z.B. "18.01.2026".
    static func datum(_ date: Date) -> String {
        datumFormatter.string(from: date)
    }

    private static let datumFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = "dd.MM.yyyy"
        f.timeZone = TimeZone.current
        return f
    }()

    /// "01.01.2025 – 31.12.2025" (U+2013 EN-DASH zwischen den Daten).
    static func periode(_ start: Date, _ ende: Date) -> String {
        "\(datum(start)) \u{2013} \(datum(ende))"
    }

    // MARK: - Fläche

    /// Formatiert eine Fläche als "<zahl> m²" — de-DE-Komma, bis zu 2
    /// Dezimalstellen, aber ohne unnötige Nullen.
    ///
    /// Beispiele:
    ///   79      → "79 m²"
    ///   79.5    → "79,5 m²"
    ///   79.45   → "79,45 m²"
    static func m2(_ value: Decimal) -> String {
        let zahl = flaecheFormatter.string(
            from: NSDecimalNumber(decimal: value)
        ) ?? "0"
        return "\(zahl) m²"
    }

    private static let flaecheFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        f.groupingSeparator = "."
        f.decimalSeparator = ","
        f.usesGroupingSeparator = true
        return f
    }()

    // MARK: - Zählerstand + Verbrauch

    /// Zählerstand-Wert für die Messzeile. Wenn nil, liefert
    /// "— — —". Bei Werten < 10 wird auf 3 Dezimalstellen gerundet
    /// (Wasser-m³ sind teils sehr klein), sonst 1–2 Stellen.
    static func zaehlerstand(_ wert: Decimal?, einheit: String) -> String {
        guard let wert else { return "— — —" }
        let abs = NSDecimalNumber(decimal: wert).doubleValue
        let dezimal: Int
        if abs < 10 { dezimal = 3 }
        else if abs < 1_000 { dezimal = 2 }
        else { dezimal = 0 }
        return zahlenFormatter(dezimalStellen: dezimal)
            .string(from: NSDecimalNumber(decimal: wert)) ?? "—"
    }

    /// Verbrauch (Differenz) — bei nil liefert "—", bei kleinem
    /// Wert (< 10) mit einer Nachkommastelle, sonst ganzzahlig.
    static func verbrauch(_ delta: Decimal?) -> String {
        guard let delta else { return "—" }
        let abs = NSDecimalNumber(decimal: delta).doubleValue
        let dezimal = abs < 10 ? 1 : 0
        return zahlenFormatter(dezimalStellen: dezimal)
            .string(from: NSDecimalNumber(decimal: delta)) ?? "—"
    }

    private static func zahlenFormatter(dezimalStellen: Int) -> NumberFormatter {
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .decimal
        f.minimumFractionDigits = dezimalStellen
        f.maximumFractionDigits = dezimalStellen
        f.groupingSeparator = "."
        f.decimalSeparator = ","
        f.usesGroupingSeparator = true
        return f
    }

    // MARK: - Prozent

    /// Formatiert einen Anteil 0…1 als Prozent-Text. `dezimal` ist
    /// die Anzahl Nachkommastellen (Default 0).
    ///
    /// Beispiele:
    ///   0.85,  dezimal: 0  → "85 %"
    ///   0.856, dezimal: 1  → "85,6 %"
    ///   1.0,   dezimal: 0  → "100 %"
    static func prozent(_ anteil: Double, dezimal: Int = 0) -> String {
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .decimal
        f.minimumFractionDigits = dezimal
        f.maximumFractionDigits = dezimal
        f.decimalSeparator = ","
        let zahl = f.string(from: NSNumber(value: anteil * 100)) ?? "0"
        return "\(zahl) %"
    }
}
