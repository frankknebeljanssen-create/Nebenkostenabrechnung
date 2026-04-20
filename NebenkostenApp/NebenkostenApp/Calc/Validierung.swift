//
//  Validierung.swift
//  NebenkostenApp — Calc-Layer
//
//  Cross-Entity-Plausibilitätsprüfung vor Abrechnungs-Erstellung.
//  Einziger erlaubter Import: Foundation.
//

import Foundation

// MARK: - Warnungs-Typen

enum WarnungsStufe: String, Codable, Sendable {
    case hinweis   // physikalisch normal / nur Info
    case warnung   // auffällig, bitte prüfen
    case fehler    // inkonsistent, Abrechnung sollte nicht finalisiert werden
}

struct Warnung: Equatable, Sendable, Identifiable {
    let id: UUID
    let stufe: WarnungsStufe
    /// Maschinenlesbare Kategorie (für Audit-Log + Deduplikation).
    let kategorie: String
    let nachricht: String
    let kostenartID: UUID?

    init(
        id: UUID = UUID(),
        stufe: WarnungsStufe,
        kategorie: String,
        nachricht: String,
        kostenartID: UUID? = nil
    ) {
        self.id = id
        self.stufe = stufe
        self.kategorie = kategorie
        self.nachricht = nachricht
        self.kostenartID = kostenartID
    }
}

// MARK: - Input

struct ValidierungsInput: Sendable {

    struct EinheitFlaeche: Sendable {
        let id: UUID
        let bezeichnung: String
        let flaecheM2: Flaeche
    }

    struct Zaehlerstand: Sendable {
        let zaehlerID: UUID
        let zaehlerBezeichnung: String
        let datum: Date
        let wert: Decimal
    }

    struct Rechnung: Sendable {
        let id: UUID
        let lieferant: String
        let datum: Date
        let betrag: Euro
        let kostenartID: UUID?
        let kostenartName: String
    }

    struct Periode: Sendable {
        let id: UUID
        let von: Date
        let bis: Date
        let abgeschlossen: Bool
    }

    // Check 4
    let gesamtflaecheM2: Flaeche
    let einheiten: [EinheitFlaeche]

    // Check 1
    let zaehlerstaende: [Zaehlerstand]

    // Check 2
    let rechnungen: [Rechnung]

    // Check 3
    let perioden: [Periode]
    let aktuellePeriodeID: UUID?

    // Check 5
    let gasHauptzaehlerKwh: Verbrauch?
    let wmzSummeKwh: Verbrauch
    let warmwasserWaermeKwh: Verbrauch

    // Check 6
    let umlageSummeEuro: Euro?
    let rechnungGesamtEuro: Euro?
}

// MARK: - Validierung

enum Validierung {

    static let wmzToleranzProzent: Decimal = 10
    static let ausreisserFaktor: Decimal = 3
    static let umlageToleranzEuro = Decimal(string: "0.01")!

    static func pruefe(_ input: ValidierungsInput) -> [Warnung] {
        var w: [Warnung] = []
        w += checkZaehlerRuecklauf(input)
        w += checkRechnungAusreisser(input)
        w += checkPeriodenUeberschneidung(input)
        w += checkFlaechenSumme(input)
        w += checkWmzVsHauptzaehler(input)
        w += checkUmlageSumme(input)
        return w
    }

    // MARK: Check 1 — Zählerstand < Vorstand

    private static func checkZaehlerRuecklauf(_ input: ValidierungsInput) -> [Warnung] {
        let proZaehler = Dictionary(grouping: input.zaehlerstaende, by: \.zaehlerID)
        var warnungen: [Warnung] = []
        for staende in proZaehler.values {
            let sortiert = staende.sorted { $0.datum < $1.datum }
            for i in 1..<sortiert.count where sortiert[i].wert < sortiert[i - 1].wert {
                let aktueller = sortiert[i]
                warnungen.append(Warnung(
                    stufe: .warnung,
                    kategorie: "zaehlerstand_ruecklauf",
                    nachricht:
                        "Zähler \(aktueller.zaehlerBezeichnung): Stand am "
                        + formatDatum(aktueller.datum)
                        + " ist kleiner als der vorherige Stand."
                ))
            }
        }
        return warnungen
    }

    // MARK: Check 2 — Rechnungsbetrag > 3× historischer Durchschnitt

    private static func checkRechnungAusreisser(_ input: ValidierungsInput) -> [Warnung] {
        let proKostenart = Dictionary(grouping: input.rechnungen, by: \.kostenartID)
        var warnungen: [Warnung] = []

        for (_, gruppe) in proKostenart where gruppe.count >= 3 {
            let sortiert = gruppe.sorted { $0.datum > $1.datum }
            let neueste = sortiert[0]
            let historisch = Array(sortiert.dropFirst())

            let summe = historisch.reduce(Decimal(0)) { $0 + $1.betrag }
            let durchschnitt = summe / Decimal(historisch.count)
            guard durchschnitt > 0 else { continue }

            if neueste.betrag > durchschnitt * ausreisserFaktor {
                warnungen.append(Warnung(
                    stufe: .warnung,
                    kategorie: "rechnung_ausreisser",
                    nachricht:
                        "Rechnung \(neueste.lieferant) (\(neueste.kostenartName)) "
                        + "vom \(formatDatum(neueste.datum)) "
                        + "beträgt \(formatEuro(neueste.betrag)) — "
                        + "mehr als das \(ausreisserFaktor)-fache des historischen Durchschnitts "
                        + "(\(formatEuro(durchschnitt)) über \(historisch.count) Rechnungen).",
                    kostenartID: neueste.kostenartID
                ))
            }
        }
        return warnungen
    }

    // MARK: Check 3 — Perioden-Überschneidung

    private static func checkPeriodenUeberschneidung(_ input: ValidierungsInput) -> [Warnung] {
        guard let id = input.aktuellePeriodeID,
              let aktuelle = input.perioden.first(where: { $0.id == id })
        else { return [] }

        var warnungen: [Warnung] = []
        for andere in input.perioden where andere.id != aktuelle.id && andere.abgeschlossen {
            let ueberschneidet = aktuelle.von <= andere.bis && andere.von <= aktuelle.bis
            if ueberschneidet {
                warnungen.append(Warnung(
                    stufe: .fehler,
                    kategorie: "periode_ueberschneidung",
                    nachricht:
                        "Aktuelle Periode \(formatDatum(aktuelle.von))–"
                        + "\(formatDatum(aktuelle.bis)) überschneidet sich mit der "
                        + "bereits abgeschlossenen Periode \(formatDatum(andere.von))–"
                        + "\(formatDatum(andere.bis))."
                ))
            }
        }
        return warnungen
    }

    // MARK: Check 4 — Σ Einheitsflächen > Gesamtfläche

    private static func checkFlaechenSumme(_ input: ValidierungsInput) -> [Warnung] {
        let summe = input.einheiten.reduce(Decimal(0)) { $0 + $1.flaecheM2 }
        guard summe > input.gesamtflaecheM2 else { return [] }

        let diff = summe - input.gesamtflaecheM2
        return [Warnung(
            stufe: .fehler,
            kategorie: "flaechen_inkonsistenz",
            nachricht:
                "Summe der Einheitsflächen (\(formatFlaeche(summe)) m²) ist größer "
                + "als die Gesamtfläche (\(formatFlaeche(input.gesamtflaecheM2)) m²). "
                + "Differenz: \(formatFlaeche(diff)) m²."
        )]
    }

    // MARK: Check 5 — WMZ-Summe vs. Hauptzähler (Toleranz 10 %, Stufe .hinweis)

    private static func checkWmzVsHauptzaehler(_ input: ValidierungsInput) -> [Warnung] {
        guard let gasTotal = input.gasHauptzaehlerKwh, gasTotal > 0 else { return [] }

        let heizungErrechnet = gasTotal - input.warmwasserWaermeKwh
        guard heizungErrechnet > 0 else { return [] }

        let abweichung = (heizungErrechnet - input.wmzSummeKwh).magnitude
        let erlaubt = heizungErrechnet * wmzToleranzProzent / 100
        guard abweichung > erlaubt else { return [] }

        let prozent = abweichung / heizungErrechnet * 100
        return [Warnung(
            stufe: .hinweis,  // Leitungs- und Kesselverluste sind physikalisch normal
            kategorie: "wmz_vs_hauptzaehler",
            nachricht:
                "Summe der WMZ-Verbräuche (\(formatKwh(input.wmzSummeKwh))) weicht "
                + "um \(formatProzent(prozent)) vom errechneten Heizungs-Gasanteil "
                + "(\(formatKwh(heizungErrechnet))) ab. "
                + "Bis \(formatProzent(wmzToleranzProzent)) physikalisch normal; "
                + "darüber prüfen, ob die Warmwasser-Umrechnung oder ein Zähler zu korrigieren ist."
        )]
    }

    // MARK: Check 6 — Umlage-Summe ≠ Gesamtbetrag

    private static func checkUmlageSumme(_ input: ValidierungsInput) -> [Warnung] {
        guard let umlage = input.umlageSummeEuro,
              let gesamt = input.rechnungGesamtEuro
        else { return [] }

        let abweichung = (umlage - gesamt).magnitude
        guard abweichung > umlageToleranzEuro else { return [] }

        return [Warnung(
            stufe: .warnung,
            kategorie: "umlage_summe_abweichung",
            nachricht:
                "Summe der Umlage-Anteile (\(formatEuro(umlage))) weicht vom "
                + "Rechnungs-Gesamtbetrag (\(formatEuro(gesamt))) ab. "
                + "Differenz: \(formatEuro(abweichung))."
        )]
    }

    // MARK: - Formatter (Foundation-only, de_DE-Locale)

    private static func formatDatum(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "de_DE")
        return f.string(from: d)
    }

    private static func formatEuro(_ e: Euro) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        f.locale = Locale(identifier: "de_DE")
        return f.string(from: NSDecimalNumber(decimal: e)) ?? "\(e) €"
    }

    private static func formatKwh(_ v: Verbrauch) -> String {
        let n = v.gerundet(auf: 0, modus: .bankers)
        return "\(NSDecimalNumber(decimal: n).stringValue) kWh"
    }

    private static func formatFlaeche(_ f: Flaeche) -> String {
        let g = f.gerundet(auf: 0, modus: .abrunden)
        if f == g { return NSDecimalNumber(decimal: g).stringValue }
        return NSDecimalNumber(decimal: f.gerundet(auf: 1, modus: .bankers)).stringValue
    }

    private static func formatProzent(_ p: Decimal) -> String {
        let g = p.gerundet(auf: 1, modus: .bankers)
        let n = NSDecimalNumber(decimal: g).stringValue
            .replacingOccurrences(of: ".", with: ",")
        return "\(n) %"
    }
}
