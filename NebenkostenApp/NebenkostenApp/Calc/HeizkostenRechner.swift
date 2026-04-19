//
//  HeizkostenRechner.swift
//  NebenkostenApp — Calc-Layer
//
//  §9 HeizkostenV: Gesamtkosten der Verbundanlage (Gas + Stromzuschlag +
//  separate Nebenkosten-Töpfe) werden anhand der berechneten Warmwasser-
//  Wärmemenge zwischen Heizung und Warmwasser gesplittet, anschließend
//  nach §7 HeizkostenV (30/70) auf die Einheiten verteilt.
//  Einziger erlaubter Import: Foundation.
//

import Foundation

/// Anlagen-spezifische Parameter. Defaults für Bahnhofstr. 37 / 2024.
struct HeizkostenParameter: Equatable, Sendable {
    /// m³ Erdgas-Input pro m³ erzeugtem Warmwasser. Default 12,9 (aus
    /// den Gas-/Wasser-Daten der Bahnhofstr. 37 2024 abgeleitet).
    let wwGasFaktor: Double

    /// Brennwert · z-Zahl in kWh/m³ Gas. Default 11,14 (GASAG 2024/2025:
    /// Brennwert Ø (11,506 + 11,590)/2 · z-Zahl 0,9654 ≈ 11,14).
    let brennwertKwhProM3: Double

    /// Stromzuschlag für Hilfsstrom der Anlage (Pumpen, Regelung) —
    /// §9 Abs. 3 HeizkostenV. Default 3 % auf Gas-Kosten-Anteil.
    let stromZuschlagProzent: Double

    /// Flächen-Grundanteil der 30/70-Aufteilung. HeizkostenV §7 erlaubt
    /// 30–50 %. Default 0,30.
    let aufteilungHeizungProzent: Double

    /// Interner Arbeitspreis €/kWh für die WW/Heiz-Kostenaufteilung.
    /// Wenn gesetzt: ww_gaskosten = ww_gas_kwh · internerArbeitspreis,
    /// und heiz_gaskosten = gesamtGasKostenBrutto − ww_gaskosten.
    /// Wenn nil: reiner Pro-Rata-Split nach kWh-Verhältnis.
    /// Für Bahnhofstr. 37 liegt er bei 0,104255 €/kWh (vs. offizieller
    /// GASAG-Brutto-Preis 0,110207).
    let internerArbeitspreisEuroProKwh: Double?

    init(
        wwGasFaktor: Double = 12.9,
        brennwertKwhProM3: Double = 11.14,
        stromZuschlagProzent: Double = 0.03,
        aufteilungHeizungProzent: Double = 0.30,
        internerArbeitspreisEuroProKwh: Double? = nil
    ) {
        self.wwGasFaktor = wwGasFaktor
        self.brennwertKwhProM3 = brennwertKwhProM3
        self.stromZuschlagProzent = stromZuschlagProzent
        self.aufteilungHeizungProzent = aufteilungHeizungProzent
        self.internerArbeitspreisEuroProKwh = internerArbeitspreisEuroProKwh
    }
}

struct HeizkostenInput: Equatable, Sendable {
    /// Gas-Gesamtverbrauch der Liegenschaft in kWh (GASAG-Jahresrechnung).
    let gesamtGasVerbrauchKwh: Double
    /// Gas-Gesamtkosten brutto (GASAG-Jahresrechnung).
    let gesamtGasKostenBrutto: Euro
    /// Nebenkosten, die ausschließlich dem Heizungs-Topf zugeschlagen
    /// werden (z.B. Schornsteinfeger, Heizungs-Wartung).
    let heizNebenkosten: Euro
    /// Nebenkosten, die dem Warmwasser-Topf zugeschlagen werden.
    let wwNebenkosten: Euro
    /// Gemessene WMZ-Wärmemenge pro Einheit in kWh.
    let wmzProEinheit: [String: Double]
    /// Gemessener Warmwasser-Verbrauch pro Einheit in m³.
    let wwM3ProEinheit: [String: Double]
    /// Fläche pro Einheit in m².
    let flaechenProEinheit: [String: Double]
    let parameter: HeizkostenParameter

    init(
        gesamtGasVerbrauchKwh: Double,
        gesamtGasKostenBrutto: Euro,
        heizNebenkosten: Euro,
        wwNebenkosten: Euro,
        wmzProEinheit: [String: Double],
        wwM3ProEinheit: [String: Double],
        flaechenProEinheit: [String: Double],
        parameter: HeizkostenParameter = HeizkostenParameter()
    ) {
        self.gesamtGasVerbrauchKwh = gesamtGasVerbrauchKwh
        self.gesamtGasKostenBrutto = gesamtGasKostenBrutto
        self.heizNebenkosten = heizNebenkosten
        self.wwNebenkosten = wwNebenkosten
        self.wmzProEinheit = wmzProEinheit
        self.wwM3ProEinheit = wwM3ProEinheit
        self.flaechenProEinheit = flaechenProEinheit
        self.parameter = parameter
    }
}

struct HeizkostenPosition: Equatable, Sendable {
    let flaechenanteilEuro: Euro
    let verbrauchsanteilEuro: Euro
    let gesamtEuro: Euro
    let verteilerschluesselText: String
}

struct HeizkostenErgebnisEinheit: Equatable, Sendable {
    let einheitID: String
    let heizung: HeizkostenPosition
    let warmwasser: HeizkostenPosition
}

struct HeizkostenErgebnis: Equatable, Sendable {
    /// Heizungs-Topf (Gas-Kostenanteil · (1+Stromzuschlag) + heizNebenkosten).
    let heizkostenTopfEuro: Euro
    /// Warmwasser-Topf (Gas-Kostenanteil · (1+Stromzuschlag) + wwNebenkosten).
    let warmwasserkostenTopfEuro: Euro
    /// Errechnete Warmwasser-Wärmemenge gesamt (Σ WW-m³ · Faktor · Brennwert).
    let qWarmwasserGesamtKwh: Double
    /// Gas-Verbrauch abzüglich Warmwasser-Wärmemenge.
    let qHeizungKwh: Double
    let proEinheit: [HeizkostenErgebnisEinheit]
}

enum HeizkostenRechner {

    /// Bricht den Kostensplit (§9) und die Verteilung (§7 30/70) in einem
    /// Zug herunter. Intern Decimal-Arithmetik; Double-Inputs werden
    /// unmittelbar gewandelt. Die Rundung auf Cent obliegt dem Aufrufer.
    static func berechne(_ input: HeizkostenInput) -> HeizkostenErgebnis {
        let p = input.parameter

        // Step 1: Warmwasser-Wärmemenge aus Σ WW-m³ · GasFaktor · Brennwert.
        let vWwGesamtM3 = input.wwM3ProEinheit.values.reduce(0.0, +)
        let qWwKwh = vWwGesamtM3 * p.wwGasFaktor * p.brennwertKwhProM3

        // Step 2: Heizungs-Wärmemenge.
        let qHeizungKwh = input.gesamtGasVerbrauchKwh - qWwKwh

        // Step 3: Gas-Kosten auf Heizung und Warmwasser splitten.
        let gasKostenWw: Euro
        let gasKostenHeizung: Euro
        if let preis = p.internerArbeitspreisEuroProKwh {
            // User-Excel-Logik: WW direkt am kWh-Preis, Rest ist Heizung.
            gasKostenWw      = Decimal(qWwKwh) * Decimal(preis)
            gasKostenHeizung = input.gesamtGasKostenBrutto - gasKostenWw
        } else {
            // Pro-rata nach kWh-Verhältnis.
            let qGesamt = Decimal(input.gesamtGasVerbrauchKwh)
            gasKostenWw      = input.gesamtGasKostenBrutto * Decimal(qWwKwh)     / qGesamt
            gasKostenHeizung = input.gesamtGasKostenBrutto * Decimal(qHeizungKwh) / qGesamt
        }

        // Step 4: Stromzuschlag auf beide Gas-Kosten-Anteile.
        let stromFaktor = Decimal(1.0 + p.stromZuschlagProzent)
        let gasKostenHeizungMitStrom = gasKostenHeizung * stromFaktor
        let gasKostenWwMitStrom      = gasKostenWw      * stromFaktor

        // Step 5: Nebenkosten-Töpfe addieren.
        let heizkostenTopf       = gasKostenHeizungMitStrom + input.heizNebenkosten
        let warmwasserkostenTopf = gasKostenWwMitStrom      + input.wwNebenkosten

        // Step 6/7: 30/70 auf beide Töpfe, dann pro Einheit verteilen.
        let fProzent = Decimal(p.aufteilungHeizungProzent)
        let vProzent = 1 - fProzent

        let gesamtFlaeche = Decimal(input.flaechenProEinheit.values.reduce(0.0, +))
        let wmzGesamt     = Decimal(input.wmzProEinheit.values.reduce(0.0, +))
        let vWwGesamt     = Decimal(vWwGesamtM3)

        let grundkostenHeizung    = heizkostenTopf       * fProzent
        let verbrauchskostenHeizung = heizkostenTopf     * vProzent
        let grundkostenWw         = warmwasserkostenTopf * fProzent
        let verbrauchskostenWw    = warmwasserkostenTopf * vProzent

        let fProzInt = Int((p.aufteilungHeizungProzent * 100).rounded())
        let vProzInt = 100 - fProzInt
        let heizungText = "\(fProzInt) % Fläche + \(vProzInt) % WMZ"
        let wwText      = "\(fProzInt) % Fläche + \(vProzInt) % WW-Verbrauch"

        let einheitIDs = Set(input.flaechenProEinheit.keys)
            .union(input.wmzProEinheit.keys)
            .union(input.wwM3ProEinheit.keys)
            .sorted()

        let proEinheit: [HeizkostenErgebnisEinheit] = einheitIDs.map { id in
            let flaeche = Decimal(input.flaechenProEinheit[id] ?? 0)
            let wmz     = Decimal(input.wmzProEinheit[id]     ?? 0)
            let wwM3    = Decimal(input.wwM3ProEinheit[id]    ?? 0)

            let hFlaeche   = grundkostenHeizung    * flaeche / gesamtFlaeche
            let hVerbrauch = wmzGesamt == 0 ? 0 : verbrauchskostenHeizung * wmz / wmzGesamt
            let hGesamt    = hFlaeche + hVerbrauch

            let wFlaeche   = grundkostenWw * flaeche / gesamtFlaeche
            let wVerbrauch = vWwGesamt == 0 ? 0 : verbrauchskostenWw * wwM3 / vWwGesamt
            let wGesamt    = wFlaeche + wVerbrauch

            return HeizkostenErgebnisEinheit(
                einheitID: id,
                heizung: HeizkostenPosition(
                    flaechenanteilEuro: hFlaeche,
                    verbrauchsanteilEuro: hVerbrauch,
                    gesamtEuro: hGesamt,
                    verteilerschluesselText: heizungText
                ),
                warmwasser: HeizkostenPosition(
                    flaechenanteilEuro: wFlaeche,
                    verbrauchsanteilEuro: wVerbrauch,
                    gesamtEuro: wGesamt,
                    verteilerschluesselText: wwText
                )
            )
        }

        return HeizkostenErgebnis(
            heizkostenTopfEuro: heizkostenTopf,
            warmwasserkostenTopfEuro: warmwasserkostenTopf,
            qWarmwasserGesamtKwh: qWwKwh,
            qHeizungKwh: qHeizungKwh,
            proEinheit: proEinheit
        )
    }
}
