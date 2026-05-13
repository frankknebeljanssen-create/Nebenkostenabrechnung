import Foundation

struct Calculator {

    // MARK: - Toleranzen

    private static let toleranzSummeEur: Decimal = Decimal(string: "1.00")!
    private static let toleranzAnteilEur: Decimal = Decimal(string: "0.50")!

    private static let plausibilitaetMinProQmMonat: Decimal = Decimal(string: "1.50")!
    private static let plausibilitaetMaxProQmMonat: Decimal = Decimal(string: "6.50")!
    private static let heizkostenAnteilMax: Decimal = Decimal(string: "0.50")!

    // MARK: - Methode 1: checkSummen

    static func checkSummen(abrechnung: Abrechnung) -> [Finding] {
        // Ohne ausgewiesene Gesamtsumme können wir nicht abgleichen.
        guard let ausgewieseneSumme = abrechnung.summeAnteile else { return [] }

        let berechneteSumme = abrechnung.kostenpositionen.reduce(Decimal(0)) { $0 + $1.mieterAnteil }
        let differenz = berechneteSumme - ausgewieseneSumme

        guard abs(differenz) > toleranzSummeEur else { return [] }

        let finding = Finding(
            id: "F001",
            typ: .rechenfehler,
            schwere: .fehler,
            konfidenz: .sicher,
            quelle: .code,
            positionId: 0,
            bezeichnung: "Gesamtsumme",
            beschreibung: "Die Summe der Einzelposten weicht von der ausgewiesenen Gesamtsumme ab.",
            betragAbrechnung: ausgewieseneSumme,
            betragKorrekt: berechneteSumme,
            differenz: differenz,
            rechtsgrundlage: nil,
            rechtsgrundlageVerifiziert: false
        )
        return [finding]
    }

    // MARK: - Methode 2: checkAnteile

    static func checkAnteile(
        abrechnung: Abrechnung,
        userFlaecheQm: Decimal,
        userPersonenzahl: Int
    ) -> [Finding] {
        var findings: [Finding] = []
        var counter = 1

        let objektFlaeche = abrechnung.meta.objekt.gesamtflaecheQm
        let anzahlEinheiten = abrechnung.meta.objekt.anzahlEinheiten

        for position in abrechnung.kostenpositionen {
            // Ohne Gesamtkosten der Position können wir den Anteil nicht
            // gegen-rechnen — Position überspringen.
            guard let gesamtkosten = position.gesamtkosten else { continue }

            let berechneterAnteil: Decimal
            let konfidenz: Konfidenz

            switch position.verteilerschluessel {
            case .wohnflaeche:
                guard let oFlaeche = objektFlaeche, oFlaeche > 0 else { continue }
                berechneterAnteil = gesamtkosten * userFlaecheQm / oFlaeche
                konfidenz = .sicher

            case .einheiten:
                guard let einheiten = anzahlEinheiten, einheiten > 0 else { continue }
                berechneterAnteil = gesamtkosten / Decimal(einheiten)
                konfidenz = .sicher

            case .personenzahl:
                // Gesamtpersonen unbekannt — Fallback auf Wohnfläche, Konfidenz reduziert.
                guard let oFlaeche = objektFlaeche, oFlaeche > 0 else { continue }
                berechneterAnteil = gesamtkosten * userFlaecheQm / oFlaeche
                konfidenz = .wahrscheinlich

            case .verbrauch, .miteigentumsanteil, .unbekannt:
                continue
            }

            let differenz = position.mieterAnteil - berechneterAnteil
            guard abs(differenz) > toleranzAnteilEur else { continue }

            let finding = Finding(
                id: idFor(counter),
                typ: .rechenfehler,
                schwere: .fehler,
                konfidenz: konfidenz,
                quelle: .code,
                positionId: position.id,
                bezeichnung: position.bezeichnungOriginal,
                beschreibung: beschreibungFuerAnteil(
                    position: position,
                    berechnet: berechneterAnteil,
                    differenz: differenz
                ),
                betragAbrechnung: position.mieterAnteil,
                betragKorrekt: berechneterAnteil,
                differenz: differenz,
                rechtsgrundlage: nil,
                rechtsgrundlageVerifiziert: false
            )
            findings.append(finding)
            counter += 1
        }
        return findings
    }

    // MARK: - Methode 3: checkPlausibilitaet

    static func checkPlausibilitaet(
        abrechnung: Abrechnung,
        userFlaecheQm: Decimal
    ) -> [Finding] {
        var findings: [Finding] = []
        var counter = 1

        // a) Gesamt-NK pro m² pro Monat außerhalb des üblichen Bereichs.
        // Ohne `summeAnteile` können wir den Quotienten nicht bilden.
        if userFlaecheQm > 0, let summeAnteile = abrechnung.summeAnteile {
            let proQmProMonat = summeAnteile / userFlaecheQm / Decimal(12)

            if proQmProMonat < plausibilitaetMinProQmMonat || proQmProMonat > plausibilitaetMaxProQmMonat {
                let finding = Finding(
                    id: idFor(counter),
                    typ: .plausibilitaet,
                    schwere: .warnung,
                    konfidenz: .wahrscheinlich,
                    quelle: .code,
                    positionId: 0,
                    bezeichnung: "Gesamtkosten",
                    beschreibung: "Die Nebenkosten pro m² liegen außerhalb des üblichen Bereichs (\(formatGeld(proQmProMonat)) €/m²/Monat). Üblich sind 2,00–5,50 €/m²/Monat.",
                    betragAbrechnung: summeAnteile,
                    betragKorrekt: nil,
                    differenz: 0,
                    rechtsgrundlage: nil,
                    rechtsgrundlageVerifiziert: false
                )
                findings.append(finding)
                counter += 1
            }
        }

        // b) Heizkosten > 50 % der Gesamtkosten
        let heizPositionen = abrechnung.kostenpositionen.filter {
            $0.kostenartNormalisiert == "heizung"
        }
        let heizSumme = heizPositionen.reduce(Decimal(0)) { $0 + $1.mieterAnteil }

        if let summeAnteile = abrechnung.summeAnteile, summeAnteile > 0, heizSumme > 0 {
            let heizAnteil = heizSumme / summeAnteile
            if heizAnteil > heizkostenAnteilMax {
                let finding = Finding(
                    id: idFor(counter),
                    typ: .plausibilitaet,
                    schwere: .warnung,
                    konfidenz: .wahrscheinlich,
                    quelle: .code,
                    positionId: heizPositionen.first?.id ?? 0,
                    bezeichnung: "Heizkosten",
                    beschreibung: "Heizkosten machen mehr als 50 % der Gesamtkosten aus. Bitte Plausibilität prüfen.",
                    betragAbrechnung: heizSumme,
                    betragKorrekt: nil,
                    differenz: 0,
                    rechtsgrundlage: nil,
                    rechtsgrundlageVerifiziert: false
                )
                findings.append(finding)
                counter += 1
            }
        }

        return findings
    }

    // MARK: - Methode 4: checkAlle (Orchestrierung)

    static func checkAlle(
        abrechnung: Abrechnung,
        userFlaecheQm: Decimal,
        userPersonenzahl: Int
    ) -> [Finding] {
        var findings: [Finding] = []
        findings.append(contentsOf: checkSummen(abrechnung: abrechnung))
        findings.append(contentsOf: checkAnteile(
            abrechnung: abrechnung,
            userFlaecheQm: userFlaecheQm,
            userPersonenzahl: userPersonenzahl
        ))
        findings.append(contentsOf: checkPlausibilitaet(
            abrechnung: abrechnung,
            userFlaecheQm: userFlaecheQm
        ))
        return findings.enumerated().map { index, finding in
            finding.withId(idFor(index + 1))
        }
    }

    // MARK: - Helpers

    private static func idFor(_ number: Int) -> String {
        "F" + String(format: "%03d", number)
    }

    private static func beschreibungFuerAnteil(
        position: Kostenposition,
        berechnet: Decimal,
        differenz: Decimal
    ) -> String {
        let zuViel = differenz > 0
        let richtung = zuViel ? "zu hoch" : "zu niedrig"
        return "Der Mieteranteil für '\(position.bezeichnungOriginal)' ist um \(formatGeld(abs(differenz))) € \(richtung) (ausgewiesen: \(formatGeld(position.mieterAnteil)) €, berechnet: \(formatGeld(berechnet)) €)."
    }

    private static func formatGeld(_ wert: Decimal) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 2
        nf.maximumFractionDigits = 2
        nf.locale = Locale(identifier: "de_DE")
        return nf.string(from: wert as NSDecimalNumber) ?? "\(wert)"
    }
}
