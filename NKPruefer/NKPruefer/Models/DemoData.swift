import Foundation

/// Beispiel-Daten für den Demo-Flow (v4-21).
///
/// Komplette, plausible Beispiel-Abrechnung mit 10 Kostenpositionen,
/// 3 Findings (1 Fehler + 2 Warnungen) und einem fertigen Widerspruchs-
/// Text. Kein API-Call, keine Internet-Verbindung nötig.
///
/// **Wichtig:** Der erzeugte `Pruefbericht` wird NICHT in SwiftData
/// gespeichert — er existiert nur im Speicher der laufenden View.
enum DemoData {

    // MARK: - Mietobjekt (Demo-Wohnung)

    static func mietobjekt() -> Mietobjekt {
        Mietobjekt(
            adresse: "Schillerstraße 17, 10625 Berlin",
            bezeichnung: "3. OG links",
            flaecheQm: 72,
            personenzahl: 2,
            vermieterName: "Hausverwaltung Müller & Partner GmbH",
            vermieterAdresse: "Kantstraße 42, 10625 Berlin"
        )
    }

    // MARK: - Datum-Helper

    private static func datum(_ iso: String) -> Date {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "de_DE")
        df.timeZone = TimeZone(identifier: "UTC")
        return df.date(from: iso) ?? Date()
    }

    // MARK: - Abrechnung

    private static let abrechnung = Abrechnung(
        meta: AbrechnungMeta(
            vermieter: ParsedVermieter(
                name: "Hausverwaltung Müller & Partner GmbH",
                adresse: "Kantstraße 42, 10625 Berlin"
            ),
            objekt: ParsedObjekt(
                adresse: "Schillerstraße 17, 10625 Berlin",
                gesamtflaecheQm: 864,
                anzahlEinheiten: 12,
                baujahr: nil
            ),
            zeitraum: Zeitraum(
                von: datum("2024-01-01"),
                bis: datum("2024-12-31")
            ),
            mieterEinheit: MieterEinheit(
                bezeichnung: "3. OG links",
                flaecheQm: 72,
                personen: 2
            ),
            vorauszahlungenGesamt: 2640,
            nachzahlungOderGuthaben: 186.42,
            typ: .nachzahlung
        ),
        kostenpositionen: [
            Kostenposition(
                id: 1,
                bezeichnungOriginal: "Grundsteuer",
                kostenartNormalisiert: "grundsteuer",
                gesamtkosten: 4820.00,
                verteilerschluessel: .wohnflaeche,
                mieterAnteil: 401.67,
                confidence: .high,
                notiz: nil
            ),
            Kostenposition(
                id: 2,
                bezeichnungOriginal: "Wasserversorgung / Entwässerung",
                kostenartNormalisiert: "entwaesserung",
                gesamtkosten: 6240.00,
                verteilerschluessel: .verbrauch,
                mieterAnteil: 487.20,
                confidence: .high,
                notiz: nil
            ),
            Kostenposition(
                id: 3,
                bezeichnungOriginal: "Heizkosten",
                kostenartNormalisiert: "heizung",
                gesamtkosten: 18960.00,
                verteilerschluessel: .verbrauch,
                mieterAnteil: 1204.30,
                confidence: .high,
                notiz: nil
            ),
            Kostenposition(
                id: 4,
                bezeichnungOriginal: "Hausmeister",
                kostenartNormalisiert: "hausmeister",
                gesamtkosten: 7200.00,
                verteilerschluessel: .wohnflaeche,
                mieterAnteil: 600.00,
                confidence: .medium,
                notiz: "Enthält möglicherweise Verwaltungsanteile"
            ),
            Kostenposition(
                id: 5,
                bezeichnungOriginal: "Müllabfuhr",
                kostenartNormalisiert: "muellabfuhr",
                gesamtkosten: 3120.00,
                verteilerschluessel: .einheiten,
                mieterAnteil: 260.00,
                confidence: .high,
                notiz: nil
            ),
            Kostenposition(
                id: 6,
                bezeichnungOriginal: "Allgemeinstrom",
                kostenartNormalisiert: "beleuchtung",
                gesamtkosten: 1440.00,
                verteilerschluessel: .wohnflaeche,
                mieterAnteil: 120.00,
                confidence: .high,
                notiz: nil
            ),
            Kostenposition(
                id: 7,
                bezeichnungOriginal: "Gebäudeversicherung",
                kostenartNormalisiert: "versicherung",
                gesamtkosten: 5280.00,
                verteilerschluessel: .wohnflaeche,
                mieterAnteil: 440.00,
                confidence: .high,
                notiz: nil
            ),
            Kostenposition(
                id: 8,
                bezeichnungOriginal: "Gartenpflege",
                kostenartNormalisiert: "gartenpflege",
                gesamtkosten: 2400.00,
                verteilerschluessel: .wohnflaeche,
                mieterAnteil: 200.00,
                confidence: .high,
                notiz: nil
            ),
            Kostenposition(
                id: 9,
                bezeichnungOriginal: "Verwaltungskosten",
                kostenartNormalisiert: "verwaltungskosten",
                gesamtkosten: 3600.00,
                verteilerschluessel: .einheiten,
                mieterAnteil: 300.00,
                confidence: .high,
                notiz: "NICHT UMLAGEFÄHIG"
            ),
            Kostenposition(
                id: 10,
                bezeichnungOriginal: "Gebäudereinigung / Treppenhausreinigung",
                kostenartNormalisiert: "gebaeudereinigung",
                gesamtkosten: 2880.00,
                verteilerschluessel: .wohnflaeche,
                mieterAnteil: 240.00,
                confidence: .medium,
                notiz: "Prüfen ob doppelt mit Hausmeister"
            )
        ],
        summeAnteile: 4253.17,
        confidenceGesamt: .high,
        warnungen: []
    )

    // MARK: - Findings (1 Fehler + 2 Warnungen)

    private static let findings: [Finding] = [
        Finding(
            id: "F001",
            typ: .nichtUmlagefaehig,
            schwere: .fehler,
            konfidenz: .sicher,
            quelle: .juristAgent,
            positionId: 9,
            bezeichnung: "Verwaltungskosten sind nicht umlagefähig",
            beschreibung: "Verwaltungskosten (Position 9: 300,00 €) dürfen nicht auf Mieter umgelegt werden. Sie gehören zu den nicht umlagefähigen Kosten gemäß BetrKV.",
            betragAbrechnung: 300.00,
            betragKorrekt: 0,
            differenz: 300.00,
            rechtsgrundlage: "§ 1 Abs. 2 BetrKV",
            rechtsgrundlageVerifiziert: true,
            erklaerung: "Die Hausverwaltung Müller & Partner GmbH hat 300 € als Verwaltungskosten in die Nebenkosten aufgenommen. Verwaltungskosten sind die Kosten, die der Vermieter für die Verwaltung des Mietobjekts trägt — z. B. Buchhaltung, Mietverwaltung, Mahnwesen. Diese Kosten dürfen laut Betriebskostenverordnung nicht auf den Mieter umgelegt werden.",
            handlungsempfehlung: "Widerspruch einlegen und 300,00 € zurückfordern."
        ),
        Finding(
            id: "F002",
            typ: .grenzfall,
            schwere: .warnung,
            konfidenz: .wahrscheinlich,
            quelle: .juristAgent,
            positionId: 4,
            bezeichnung: "Hausmeisterkosten — Belegeinsicht empfohlen",
            beschreibung: "Die Hausmeisterkosten (600,00 €) liegen im oberen Bereich. Mögliche Verwaltungs- oder Reparaturanteile sollten herausgerechnet werden.",
            betragAbrechnung: 600.00,
            betragKorrekt: nil,
            differenz: 0,
            rechtsgrundlage: "§ 2 Nr. 14 BetrKV",
            rechtsgrundlageVerifiziert: true,
            erklaerung: "Nur die reinen Betriebskosten-Anteile des Hausmeisters sind umlagefähig (Reinigung, Gartenpflege, Winterdienst). Verwaltungs- und Reparaturanteile müssen vom Vermieter selbst getragen werden. Typisch sind 10–20 % Abzug für diese nicht umlagefähigen Anteile.",
            handlungsempfehlung: "Belegeinsicht anfordern und prüfen, ob der Hausmeistervertrag Verwaltungs- oder Reparaturtätigkeiten enthält."
        ),
        Finding(
            id: "F003",
            typ: .plausibilitaet,
            schwere: .warnung,
            konfidenz: .wahrscheinlich,
            quelle: .juristAgent,
            positionId: 10,
            bezeichnung: "Mögliche Doppelberechnung mit Hausmeister",
            beschreibung: "Sowohl 'Hausmeister' (600 €) als auch 'Gebäudereinigung' (240 €) sind separat aufgeführt. Wenn der Hausmeister die Reinigung übernimmt, ist das eine doppelte Umlage.",
            betragAbrechnung: 240.00,
            betragKorrekt: nil,
            differenz: 0,
            rechtsgrundlage: "§ 556 Abs. 3 BGB",
            rechtsgrundlageVerifiziert: true,
            erklaerung: "Der Vermieter darf für dieselbe Leistung nicht zweimal Kosten umlegen. Wenn der Hausmeister-Vertrag die Treppenhausreinigung beinhaltet, sind die separat aufgeführten 240 € unzulässig.",
            handlungsempfehlung: "Belegeinsicht: Gibt es einen separaten Reinigungsvertrag oder steht die Reinigung im Hausmeistervertrag?"
        )
    ]

    // MARK: - TrustScores (realistisch gestaffelt)

    private static let trustScores: [String: TrustScore] = [
        "F001": TrustScore(
            strukturValid: true,
            crossCheckValid: true,
            quelltreuValid: true,
            debatteBestaetigt: true,
            auditBestaetigt: true
        ),  // 100 %
        "F002": TrustScore(
            strukturValid: true,
            crossCheckValid: true,
            quelltreuValid: true,
            debatteBestaetigt: false,
            auditBestaetigt: true
        ),  //  80 %
        "F003": TrustScore(
            strukturValid: true,
            crossCheckValid: true,
            quelltreuValid: true,
            debatteBestaetigt: false,
            auditBestaetigt: false
        )   //  60 %
    ]

    // MARK: - Fertiger Widerspruchs-Text

    static let widerspruchText: String = """
    Sehr geehrte Damen und Herren,

    hiermit erhebe ich Einwendungen gegen die Nebenkostenabrechnung für den Zeitraum 01.01.2024 bis 31.12.2024.

    1. Verwaltungskosten (300,00 €)

    Die in Position 9 aufgeführten Verwaltungskosten in Höhe von 300,00 € sind nicht umlagefähig. Gemäß § 1 Abs. 2 BetrKV gehören Verwaltungskosten nicht zu den Betriebskosten. Ich bitte um Korrektur der Abrechnung und Erstattung des Betrags.

    2. Hausmeisterkosten — Belegeinsicht

    Die Hausmeisterkosten in Höhe von 600,00 € bitte ich zu belegen. Ich möchte prüfen, ob der Hausmeistervertrag Verwaltungs- oder Reparaturtätigkeiten enthält, die nicht umlagefähig wären (§ 2 Nr. 14 BetrKV).

    3. Gebäudereinigung — Doppelberechnung

    Bitte belegen Sie, dass die Gebäudereinigung (240,00 €) von einer separaten Firma durchgeführt wird und nicht bereits in den Hausmeisterkosten enthalten ist.

    Darüber hinaus mache ich von meinem Recht auf Belegeinsicht gemäß § 259 BGB Gebrauch und bitte um Einsichtnahme in die der Abrechnung zugrunde liegenden Belege und Rechnungen.

    Ich bitte um Korrektur der Abrechnung und Rückerstattung der zu Unrecht berechneten Beträge innerhalb von 14 Tagen.

    Mit freundlichen Grüßen
    """

    // MARK: - Pruefbericht zusammenbauen

    static func erstellePruefbericht() -> Pruefbericht {
        return Pruefbericht(
            abrechnungId: "DEMO-2024",
            pruefDatum: Date(),
            abrechnung: abrechnung,
            findings: findings,
            berichtText: "Wir haben drei Auffälligkeiten in deiner Beispiel-Abrechnung gefunden. Die Verwaltungskosten von 300 € sind klar nicht umlagefähig — hier kannst du dein Geld zurückfordern. Bei Hausmeister- und Reinigungskosten lohnt eine Belegeinsicht.",
            ersparnisGesamt: 300.00,
            trustScores: trustScores
        )
    }
}
