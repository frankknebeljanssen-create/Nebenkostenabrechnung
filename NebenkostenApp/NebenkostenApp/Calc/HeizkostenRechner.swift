//
//  HeizkostenRechner.swift
//  NebenkostenApp — Calc-Layer
//
//  Kostenaufteilung nach HeizkostenV §7 Abs. 1:
//    30–50 % verbrauchsunabhängig (Fläche), Rest verbrauchsabhängig (WMZ).
//  Default: 30 % Fläche / 70 % Verbrauch.
//  Einziger erlaubter Import: Foundation.
//

import Foundation

struct HeizkostenInput: Equatable, Sendable {
    let gesamtflaecheM2: Flaeche
    let wohneinheitFlaecheM2: Flaeche
    let wmzGesamt: Verbrauch
    let wmzWohneinheit: Verbrauch
    let gesamtkostenEuro: Euro
    /// Flächenanteil in Prozent. HeizkostenV-zulässig: 30 bis 50. Default 30.
    let flaechenanteilProzent: Decimal

    init(
        gesamtflaecheM2: Flaeche,
        wohneinheitFlaecheM2: Flaeche,
        wmzGesamt: Verbrauch,
        wmzWohneinheit: Verbrauch,
        gesamtkostenEuro: Euro,
        flaechenanteilProzent: Decimal = 30
    ) {
        self.gesamtflaecheM2 = gesamtflaecheM2
        self.wohneinheitFlaecheM2 = wohneinheitFlaecheM2
        self.wmzGesamt = wmzGesamt
        self.wmzWohneinheit = wmzWohneinheit
        self.gesamtkostenEuro = gesamtkostenEuro
        self.flaechenanteilProzent = flaechenanteilProzent
    }
}

struct HeizkostenErgebnis: Equatable, Sendable {
    let flaechenanteilEuro: Euro
    let verbrauchsanteilEuro: Euro
    let gesamtEuro: Euro
    let verteilerschluesselText: String
}

enum HeizkostenRechner {
    /// Berechnet den Mieteranteil nach HeizkostenV-Schlüssel.
    ///
    ///   flaechenanteil    = (prozent / 100) · (eigeneFläche / gesamtFläche) · kosten
    ///   verbrauchsanteil  = ((100 − prozent) / 100) · (eigenerWMZ / gesamtWMZ) · kosten
    ///
    /// Es wird intern NICHT gerundet; die Rundung auf Euro-Cent obliegt
    /// dem Aufrufer (typisch `.gerundet(auf: 2)`).
    static func berechne(_ input: HeizkostenInput) -> HeizkostenErgebnis {
        let flaechenQuote = input.wohneinheitFlaecheM2 / input.gesamtflaecheM2
        let verbrauchsQuote = input.wmzWohneinheit / input.wmzGesamt

        let flaechenProzent = input.flaechenanteilProzent
        let verbrauchsProzent = 100 - flaechenProzent

        let flaechenAnteil = (flaechenProzent / 100) * flaechenQuote * input.gesamtkostenEuro
        let verbrauchsAnteil = (verbrauchsProzent / 100) * verbrauchsQuote * input.gesamtkostenEuro
        let gesamt = flaechenAnteil + verbrauchsAnteil

        let fProzInt = NSDecimalNumber(decimal: flaechenProzent).intValue
        let vProzInt = NSDecimalNumber(decimal: verbrauchsProzent).intValue
        let text = "\(fProzInt) % Fläche + \(vProzInt) % Verbrauch"

        return HeizkostenErgebnis(
            flaechenanteilEuro: flaechenAnteil,
            verbrauchsanteilEuro: verbrauchsAnteil,
            gesamtEuro: gesamt,
            verteilerschluesselText: text
        )
    }
}
