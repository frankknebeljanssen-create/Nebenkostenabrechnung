import XCTest
// HINWEIS: Modulname muss zum Xcode-Target passen. Anpassen falls nötig.
@testable import NKPruefer

final class CalculatorTests: XCTestCase {

    // MARK: - Test 1: Summen stimmen — keine Findings

    func test_checkSummen_korrekteGesamtsumme_keineFindings() {
        let abrechnung = makeAbrechnung(
            kostenpositionen: [
                makePosition(id: 1, gesamtkosten: 1000, mieterAnteil: 100),
                makePosition(id: 2, gesamtkosten: 2000, mieterAnteil: 200),
                makePosition(id: 3, gesamtkosten: 3000, mieterAnteil: 300)
            ],
            summeAnteile: 600
        )

        let findings = Calculator.checkSummen(abrechnung: abrechnung)

        XCTAssertTrue(findings.isEmpty, "Bei korrekter Summe darf kein Finding entstehen.")
    }

    // MARK: - Test 2: Summe weicht ab — Finding

    func test_checkSummen_falscheGesamtsumme_einFinding() {
        let abrechnung = makeAbrechnung(
            kostenpositionen: [
                makePosition(id: 1, gesamtkosten: 5000, mieterAnteil: 1000),
                makePosition(id: 2, gesamtkosten: 5000, mieterAnteil: 1000),
                makePosition(id: 3, gesamtkosten: 5000, mieterAnteil: 500)
            ],
            summeAnteile: 2600   // berechnet: 2500 — Differenz 100
        )

        let findings = Calculator.checkSummen(abrechnung: abrechnung)

        XCTAssertEqual(findings.count, 1)
        let finding = try? XCTUnwrap(findings.first)
        XCTAssertEqual(finding?.typ, .rechenfehler)
        XCTAssertEqual(finding?.schwere, .fehler)
        XCTAssertEqual(finding?.konfidenz, .sicher)
        XCTAssertEqual(finding?.quelle, .code)
        XCTAssertEqual(abs(finding?.differenz ?? 0), Decimal(100))
        XCTAssertEqual(finding?.betragAbrechnung, Decimal(2600))
        XCTAssertEqual(finding?.betragKorrekt, Decimal(2500))
    }

    // MARK: - Test 3: Anteil korrekt berechnet

    func test_checkAnteile_korrekterWohnflaechenanteil_keineFindings() {
        let position = makePosition(
            id: 1,
            kostenartNormalisiert: "grundsteuer",
            gesamtkosten: 5000,
            schluessel: .wohnflaeche,
            mieterAnteil: 340  // 5000 * 68 / 1000
        )
        let abrechnung = makeAbrechnung(
            kostenpositionen: [position],
            summeAnteile: 340,
            objektFlaeche: 1000
        )

        let findings = Calculator.checkAnteile(
            abrechnung: abrechnung,
            userFlaecheQm: 68,
            userPersonenzahl: 2
        )

        XCTAssertTrue(findings.isEmpty, "Bei korrektem Anteil darf kein Finding entstehen.")
    }

    // MARK: - Test 4: Anteil falsch — Finding

    func test_checkAnteile_falscherWohnflaechenanteil_einFinding() {
        let position = makePosition(
            id: 7,
            bezeichnung: "Grundsteuer",
            kostenartNormalisiert: "grundsteuer",
            gesamtkosten: 5000,
            schluessel: .wohnflaeche,
            mieterAnteil: 380  // korrekt wären 340 → Differenz +40
        )
        let abrechnung = makeAbrechnung(
            kostenpositionen: [position],
            summeAnteile: 380,
            objektFlaeche: 1000
        )

        let findings = Calculator.checkAnteile(
            abrechnung: abrechnung,
            userFlaecheQm: 68,
            userPersonenzahl: 2
        )

        XCTAssertEqual(findings.count, 1)
        let finding = try? XCTUnwrap(findings.first)
        XCTAssertEqual(finding?.typ, .rechenfehler)
        XCTAssertEqual(finding?.schwere, .fehler)
        XCTAssertEqual(finding?.konfidenz, .sicher)
        XCTAssertEqual(finding?.quelle, .code)
        XCTAssertEqual(finding?.positionId, 7)
        XCTAssertEqual(abs(finding?.differenz ?? 0), Decimal(40))
        XCTAssertEqual(finding?.betragAbrechnung, Decimal(380))
        XCTAssertEqual(finding?.betragKorrekt, Decimal(340))
    }

    // MARK: - Test 5: Plausibilität zu hoch — Warnung

    func test_checkPlausibilitaet_ueberbereich_einWarnungsFinding() {
        // 8 €/m²/Monat × 100 m² × 12 Monate = 9600 €/Jahr
        let abrechnung = makeAbrechnung(
            kostenpositionen: [
                makePosition(id: 1, gesamtkosten: 9600, mieterAnteil: 9600)
            ],
            summeAnteile: 9600
        )

        let findings = Calculator.checkPlausibilitaet(
            abrechnung: abrechnung,
            userFlaecheQm: 100
        )

        XCTAssertEqual(findings.count, 1)
        let finding = try? XCTUnwrap(findings.first)
        XCTAssertEqual(finding?.typ, .plausibilitaet)
        XCTAssertEqual(finding?.schwere, .warnung)
        XCTAssertEqual(finding?.konfidenz, .wahrscheinlich)
        XCTAssertEqual(finding?.quelle, .code)
    }

    // MARK: - Test 6: Verbrauchsschlüssel wird übersprungen

    func test_checkAnteile_verbrauchsschluessel_wirdUebersprungen() {
        let position = makePosition(
            id: 1,
            kostenartNormalisiert: "wasserversorgung",
            gesamtkosten: 5000,
            schluessel: .verbrauch,
            mieterAnteil: 999  // völlig "falscher" Wert — darf trotzdem nicht geflagged werden
        )
        let abrechnung = makeAbrechnung(
            kostenpositionen: [position],
            summeAnteile: 999
        )

        let findings = Calculator.checkAnteile(
            abrechnung: abrechnung,
            userFlaecheQm: 68,
            userPersonenzahl: 2
        )

        XCTAssertTrue(findings.isEmpty, "Verbrauchsabhängige Posten dürfen nicht geprüft werden.")
    }

    // MARK: - Bonus: Personenzahl-Schlüssel reduziert Konfidenz

    func test_checkAnteile_personenzahlschluessel_konfidenzWahrscheinlich() {
        let position = makePosition(
            id: 1,
            gesamtkosten: 5000,
            schluessel: .personenzahl,
            mieterAnteil: 999  // bewusst falsch, damit Finding entsteht
        )
        let abrechnung = makeAbrechnung(
            kostenpositionen: [position],
            summeAnteile: 999,
            objektFlaeche: 1000
        )

        let findings = Calculator.checkAnteile(
            abrechnung: abrechnung,
            userFlaecheQm: 68,
            userPersonenzahl: 2
        )

        XCTAssertEqual(findings.count, 1)
        XCTAssertEqual(findings.first?.konfidenz, .wahrscheinlich)
    }

    // MARK: - Bonus: checkAlle nummeriert Findings fortlaufend

    func test_checkAlle_findingsWerdenFortlaufendNummeriert() {
        // Eine Abrechnung mit Summenfehler UND Anteilsfehler
        let position = makePosition(
            id: 1,
            gesamtkosten: 5000,
            schluessel: .wohnflaeche,
            mieterAnteil: 380   // korrekt 340 → Anteilsfehler
        )
        let abrechnung = makeAbrechnung(
            kostenpositionen: [position],
            summeAnteile: 500,    // berechnet 380 → Summenfehler 120
            objektFlaeche: 1000
        )

        let findings = Calculator.checkAlle(
            abrechnung: abrechnung,
            userFlaecheQm: 68,
            userPersonenzahl: 2
        )

        XCTAssertGreaterThanOrEqual(findings.count, 2)
        let ids = findings.map(\.id)
        XCTAssertEqual(ids, ids.sorted(), "IDs müssen aufsteigend sortiert sein.")
        XCTAssertEqual(findings.first?.id, "F001")
        XCTAssertEqual(Set(ids).count, ids.count, "IDs müssen eindeutig sein.")
    }

    // MARK: - Test-Helpers

    private func makeAbrechnung(
        kostenpositionen: [Kostenposition],
        summeAnteile: Decimal,
        objektFlaeche: Decimal = Decimal(1000),
        anzahlEinheiten: Int = 18
    ) -> Abrechnung {
        Abrechnung(
            meta: AbrechnungMeta(
                vermieter: ParsedVermieter(
                    name: "Test-Hausverwaltung",
                    adresse: "Teststr. 1, 10115 Berlin"
                ),
                objekt: ParsedObjekt(
                    adresse: "Beispielweg 5, 10115 Berlin",
                    gesamtflaecheQm: objektFlaeche,
                    anzahlEinheiten: anzahlEinheiten,
                    baujahr: nil
                ),
                zeitraum: Zeitraum(von: Date(), bis: Date()),
                mieterEinheit: MieterEinheit(
                    bezeichnung: "Whg. 4",
                    flaecheQm: Decimal(68),
                    personen: 2
                ),
                vorauszahlungenGesamt: Decimal(0),
                nachzahlungOderGuthaben: Decimal(0),
                typ: .nachzahlung
            ),
            kostenpositionen: kostenpositionen,
            summeAnteile: summeAnteile,
            confidenceGesamt: .high,
            warnungen: []
        )
    }

    private func makePosition(
        id: Int,
        bezeichnung: String = "Test-Position",
        kostenartNormalisiert: String? = nil,
        gesamtkosten: Decimal,
        schluessel: Verteilerschluessel = .wohnflaeche,
        mieterAnteil: Decimal,
        confidence: Confidence = .high
    ) -> Kostenposition {
        Kostenposition(
            id: id,
            bezeichnungOriginal: bezeichnung,
            kostenartNormalisiert: kostenartNormalisiert,
            gesamtkosten: gesamtkosten,
            verteilerschluessel: schluessel,
            mieterAnteil: mieterAnteil,
            confidence: confidence,
            notiz: nil
        )
    }
}
