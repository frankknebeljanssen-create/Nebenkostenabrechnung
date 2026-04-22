//
//  VollstaendigkeitsPruefungStatusTests.swift
//  NebenkostenAppTests — CalcTests
//
//  Status-Logik-Tests fuer VollstaendigkeitsPruefung. Ergaenzt die
//  bestehenden Sprungziel-Tests um die eigentlichen Regeln:
//
//    - Stammdaten (Flaeche, Einheiten, Vorauszahlungs-Flag, Periode)
//    - Zaehler  (offen / teilweise / Ruecklauf / erfasstAm-Marker)
//    - Rechnung (leer / aiVorschlag-Blocker / §35a-Lohnanteil /
//                ungeprueft / erfuellt)
//    - zusammenfassung()
//
//  Jeder Test baut sich ein minimales In-Memory-Szenario
//  (Immobilie + Einheit + Periode + optional Zaehler/Rechnung),
//  damit die erwartete Status-Logik isoliert ablesbar ist.
//

import Foundation
import SwiftData
import Testing
@testable import NebenkostenApp

@MainActor
@Suite(.serialized)
struct VollstaendigkeitsPruefungStatusTests {

    // MARK: - Szenario-Helfer

    private struct Grundgeruest {
        let container: ModelContainer
        let immobilie: Immobilie
        let einheit: Wohneinheit
        let mietverhaeltnis: Mietverhaeltnis
        let periode: Abrechnungsperiode
    }

    /// Baut das minimale Setup fuer alle Status-Tests: eine Immobilie
    /// mit Gesamtflaeche, eine Einheit mit Flaeche + aktivem Mieter
    /// (Vorauszahlung erfasst), eine valide Periode. Tests modifizieren
    /// das Setup gezielt, bevor sie `VollstaendigkeitsPruefung.pruefe`
    /// aufrufen.
    private func grund() throws -> Grundgeruest {
        let container = try ModelContainer.preview()
        let ctx = container.mainContext

        let immobilie = Immobilie()
        immobilie.adresse = "Teststr. 1"
        immobilie.gesamtflaecheM2 = 100
        ctx.insert(immobilie)

        let einheit = Wohneinheit()
        einheit.bezeichnung = "EG"
        einheit.flaecheM2 = 100
        einheit.nutzungsart = .wohnung
        einheit.immobilie = immobilie
        ctx.insert(einheit)

        let mv = Mietverhaeltnis()
        mv.mieterName = "Max Mustermann"
        mv.vorauszahlungMonatBruttoEuro = 300
        mv.vorauszahlungErfasst = true
        mv.einzugAm = Date(timeIntervalSince1970: 0)
        mv.wohneinheit = einheit
        ctx.insert(mv)

        let kal = Calendar(identifier: .gregorian)
        let von = kal.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        let bis = kal.date(from: DateComponents(year: 2025, month: 12, day: 31))!
        let periode = Abrechnungsperiode()
        periode.von = von
        periode.bis = bis
        periode.immobilie = immobilie
        ctx.insert(periode)

        try ctx.save()
        return Grundgeruest(
            container: container,
            immobilie: immobilie,
            einheit: einheit,
            mietverhaeltnis: mv,
            periode: periode
        )
    }

    private func anforderung(
        in liste: [AnforderungMitStatus], id: String
    ) -> AnforderungMitStatus? {
        liste.first { $0.anforderung.id == id }
    }

    // MARK: - Stammdaten

    @Test("Gesamtflaeche = 0 → offen")
    func gesamtflaeche_offen() throws {
        let g = try grund()
        g.immobilie.gesamtflaecheM2 = 0
        let liste = VollstaendigkeitsPruefung.pruefe(
            immobilie: g.immobilie, periode: g.periode
        )
        #expect(anforderung(in: liste, id: "stammdaten-gesamtflaeche")?.status == .offen)
    }

    @Test("Gesamtflaeche > 0 → erfuellt")
    func gesamtflaeche_erfuellt() throws {
        let g = try grund()
        let liste = VollstaendigkeitsPruefung.pruefe(
            immobilie: g.immobilie, periode: g.periode
        )
        #expect(anforderung(in: liste, id: "stammdaten-gesamtflaeche")?.status == .erfuellt)
    }

    @Test("Eine Einheit ohne Flaeche, eine mit → teilweise, Hinweis nennt Zahl")
    func einheiten_teilweise() throws {
        let g = try grund()
        let zweite = Wohneinheit()
        zweite.bezeichnung = "OG"
        zweite.flaecheM2 = 0
        zweite.nutzungsart = .wohnung
        zweite.immobilie = g.immobilie
        g.container.mainContext.insert(zweite)
        try g.container.mainContext.save()

        let liste = VollstaendigkeitsPruefung.pruefe(
            immobilie: g.immobilie, periode: g.periode
        )
        let anf = anforderung(in: liste, id: "stammdaten-wohneinheiten")
        #expect(anf?.status == .teilweise)
        #expect(anf?.hinweis?.contains("1") == true)
    }

    @Test("Vorauszahlung ohne erfasst-Flag blockiert → offen")
    func vorauszahlung_nicht_erfasst() throws {
        let g = try grund()
        g.mietverhaeltnis.vorauszahlungErfasst = false
        try g.container.mainContext.save()

        let liste = VollstaendigkeitsPruefung.pruefe(
            immobilie: g.immobilie, periode: g.periode
        )
        let anf = anforderung(in: liste, id: "stammdaten-vorauszahlung")
        #expect(anf?.status == .offen)
        #expect(anf?.schwere == .blocker)
        #expect(anf?.blockiertBerechnung == true)
    }

    @Test("Vorauszahlung 0 mit Flag = true → erfuellt (Selbstnutzer)")
    func vorauszahlung_null_mit_flag_erfuellt() throws {
        let g = try grund()
        g.mietverhaeltnis.vorauszahlungMonatBruttoEuro = 0
        g.mietverhaeltnis.vorauszahlungErfasst = true
        try g.container.mainContext.save()

        let liste = VollstaendigkeitsPruefung.pruefe(
            immobilie: g.immobilie, periode: g.periode
        )
        #expect(anforderung(in: liste, id: "stammdaten-vorauszahlung")?.status == .erfuellt)
    }

    @Test("Periode mit von >= bis → offen")
    func periode_von_groesser_bis() throws {
        let g = try grund()
        let kal = Calendar(identifier: .gregorian)
        let datum = kal.date(from: DateComponents(year: 2025, month: 6, day: 1))!
        g.periode.von = datum
        g.periode.bis = datum
        try g.container.mainContext.save()

        let liste = VollstaendigkeitsPruefung.pruefe(
            immobilie: g.immobilie, periode: g.periode
        )
        let anf = anforderung(in: liste, id: "stammdaten-periode")
        #expect(anf?.status == .offen)
        #expect(anf?.hinweis != nil)
    }

    @Test("Mieter fehlt (aktive Einheit ohne MV) → teilweise")
    func mieter_teilweise() throws {
        let g = try grund()
        let ctx = g.container.mainContext
        let leer = Wohneinheit()
        leer.bezeichnung = "OG"
        leer.flaecheM2 = 50
        leer.nutzungsart = .wohnung
        leer.immobilie = g.immobilie
        ctx.insert(leer)
        try ctx.save()

        let liste = VollstaendigkeitsPruefung.pruefe(
            immobilie: g.immobilie, periode: g.periode
        )
        let anf = anforderung(in: liste, id: "stammdaten-mieter")
        #expect(anf?.status == .teilweise)
    }

    @Test("Leerstand wird NICHT als fehlender Mieter gewertet")
    func leerstand_ignoriert_mieter() throws {
        let g = try grund()
        let ctx = g.container.mainContext
        let leer = Wohneinheit()
        leer.bezeichnung = "OG"
        leer.flaecheM2 = 50
        leer.nutzungsart = .leerstand
        leer.immobilie = g.immobilie
        ctx.insert(leer)
        try ctx.save()

        let liste = VollstaendigkeitsPruefung.pruefe(
            immobilie: g.immobilie, periode: g.periode
        )
        #expect(anforderung(in: liste, id: "stammdaten-mieter")?.status == .erfuellt)
    }

    // MARK: - Zaehler

    private func ergaenzeZaehler(
        _ g: Grundgeruest,
        staende: [(Date, Decimal, erfasstAm: Date?)]
    ) throws -> Zaehler {
        let ctx = g.container.mainContext
        let z = Zaehler()
        z.medium = .strom
        z.typ = .wohnung
        z.bezeichnung = "Strom EG"
        z.einheit = "kWh"
        z.wohneinheit = g.einheit
        ctx.insert(z)

        for (datum, wert, erfasstAm) in staende {
            let s = Zaehlerstand()
            s.ablesedatum = datum
            s.stand = wert
            s.erfasstAm = erfasstAm
            s.zaehler = z
            ctx.insert(s)
        }
        try ctx.save()
        return z
    }

    @Test("Zaehler ohne Staende in Periode → offen")
    func zaehler_keine_staende_offen() throws {
        let g = try grund()
        _ = try ergaenzeZaehler(g, staende: [])
        let liste = VollstaendigkeitsPruefung.pruefe(
            immobilie: g.immobilie, periode: g.periode
        )
        let z = anforderung(in: liste, id: "zaehler-\((g.einheit.zaehler ?? []).first!.id.uuidString)")
        #expect(z?.status == .offen)
        #expect(z?.hinweis?.contains("Anfangs") == true || z?.hinweis?.contains("End") == true)
    }

    @Test("Zaehler mit einem Stand + erfasstAm → teilweise 'Endstand fehlt'")
    func zaehler_ein_stand_teilweise() throws {
        let g = try grund()
        _ = try ergaenzeZaehler(g, staende: [
            (g.periode.von, 1000, erfasstAm: g.periode.von)
        ])
        let liste = VollstaendigkeitsPruefung.pruefe(
            immobilie: g.immobilie, periode: g.periode
        )
        let z = (g.einheit.zaehler ?? []).first!
        let anf = anforderung(in: liste, id: "zaehler-\(z.id.uuidString)")
        #expect(anf?.status == .teilweise)
        #expect(anf?.hinweis?.contains("Endstand") == true)
    }

    @Test("Zaehler mit zwei Staenden OHNE erfasstAm → offen (strikte-Daten-Regel)")
    func zaehler_ohne_erfasstAm_offen() throws {
        let g = try grund()
        _ = try ergaenzeZaehler(g, staende: [
            (g.periode.von, 1000, erfasstAm: nil),
            (g.periode.bis, 2500, erfasstAm: nil)
        ])
        let liste = VollstaendigkeitsPruefung.pruefe(
            immobilie: g.immobilie, periode: g.periode
        )
        let z = (g.einheit.zaehler ?? []).first!
        let anf = anforderung(in: liste, id: "zaehler-\(z.id.uuidString)")
        #expect(anf?.status == .offen)
        #expect(anf?.hinweis?.contains("nicht aktiv erfasst") == true)
    }

    @Test("Zaehler mit zwei Staenden + erfasstAm, Endstand > Anfang → erfuellt")
    func zaehler_vollstaendig_erfuellt() throws {
        let g = try grund()
        _ = try ergaenzeZaehler(g, staende: [
            (g.periode.von, 1000, erfasstAm: g.periode.von),
            (g.periode.bis, 2500, erfasstAm: g.periode.bis)
        ])
        let liste = VollstaendigkeitsPruefung.pruefe(
            immobilie: g.immobilie, periode: g.periode
        )
        let z = (g.einheit.zaehler ?? []).first!
        #expect(anforderung(in: liste, id: "zaehler-\(z.id.uuidString)")?.status == .erfuellt)
    }

    @Test("Zaehler-Ruecklauf (Endstand < Anfang) → teilweise 'Ruecklauf'")
    func zaehler_ruecklauf_teilweise() throws {
        let g = try grund()
        _ = try ergaenzeZaehler(g, staende: [
            (g.periode.von, 5000, erfasstAm: g.periode.von),
            (g.periode.bis, 4000, erfasstAm: g.periode.bis)
        ])
        let liste = VollstaendigkeitsPruefung.pruefe(
            immobilie: g.immobilie, periode: g.periode
        )
        let z = (g.einheit.zaehler ?? []).first!
        let anf = anforderung(in: liste, id: "zaehler-\(z.id.uuidString)")
        #expect(anf?.status == .teilweise)
        #expect(anf?.hinweis?.lowercased().contains("rücklauf") == true
                || anf?.hinweis?.lowercased().contains("ruecklauf") == true)
    }

    // MARK: - Rechnungen

    private func ergaenzeKostenart(
        _ g: Grundgeruest,
        paragraph35a: Bool = false
    ) throws -> Kostenart {
        let ctx = g.container.mainContext
        let ka = Kostenart()
        ka.bezeichnung = "Testkostenart"
        ka.aktiv = true
        ka.paragraph35a = paragraph35a
        ka.immobilie = g.immobilie
        ctx.insert(ka)
        try ctx.save()
        return ka
    }

    private func ergaenzeRechnung(
        _ g: Grundgeruest,
        kostenart: Kostenart,
        validierung: ValidierungsStatus = .importiert,
        geprueft: Bool = true,
        lohnanteil: Decimal? = nil
    ) throws -> Rechnung {
        let ctx = g.container.mainContext
        let r = Rechnung()
        r.lieferant = "Testlieferant"
        r.rechnungsdatum = g.periode.von
        r.leistungVon = g.periode.von
        r.leistungBis = g.periode.bis
        r.betragBruttoEuro = 100
        r.lohnanteilBruttoEuro = lohnanteil
        r.geprueft = geprueft
        r.validierungsStatus = validierung
        r.kostenart = kostenart
        r.immobilie = g.immobilie
        ctx.insert(r)
        try ctx.save()
        return r
    }

    @Test("Kostenart aktiv aber ohne Rechnung in Periode → offen, Hinweis 'hinzufuegen'")
    func rechnung_keine_in_periode_offen() throws {
        let g = try grund()
        let ka = try ergaenzeKostenart(g)
        let liste = VollstaendigkeitsPruefung.pruefe(
            immobilie: g.immobilie, periode: g.periode
        )
        let anf = anforderung(in: liste, id: "rechnung-\(ka.id.uuidString)")
        #expect(anf?.status == .offen)
        #expect(anf?.anforderung.titel.contains("hinzufügen") == true)
    }

    @Test("Rechnung mit validierungsStatus .aiVorschlag blockiert → offen 'validieren'")
    func rechnung_aiVorschlag_blockiert() throws {
        let g = try grund()
        let ka = try ergaenzeKostenart(g)
        _ = try ergaenzeRechnung(g, kostenart: ka, validierung: .aiVorschlag)
        let liste = VollstaendigkeitsPruefung.pruefe(
            immobilie: g.immobilie, periode: g.periode
        )
        let anf = anforderung(in: liste, id: "rechnung-\(ka.id.uuidString)")
        #expect(anf?.status == .offen)
        #expect(anf?.anforderung.titel.contains("validieren") == true)
        #expect(anf?.blockiertBerechnung == true)
    }

    @Test("§35a-Kostenart ohne Lohnanteil → teilweise 'Lohnanteil ergaenzen'")
    func rechnung_35a_ohne_lohn_teilweise() throws {
        let g = try grund()
        let ka = try ergaenzeKostenart(g, paragraph35a: true)
        _ = try ergaenzeRechnung(g, kostenart: ka, lohnanteil: nil)
        let liste = VollstaendigkeitsPruefung.pruefe(
            immobilie: g.immobilie, periode: g.periode
        )
        let anf = anforderung(in: liste, id: "rechnung-\(ka.id.uuidString)")
        #expect(anf?.status == .teilweise)
        #expect(anf?.anforderung.titel.contains("Lohnanteil") == true)
    }

    @Test("§35a-Kostenart MIT Lohnanteil → erfuellt")
    func rechnung_35a_mit_lohn_erfuellt() throws {
        let g = try grund()
        let ka = try ergaenzeKostenart(g, paragraph35a: true)
        _ = try ergaenzeRechnung(g, kostenart: ka, lohnanteil: 20)
        let liste = VollstaendigkeitsPruefung.pruefe(
            immobilie: g.immobilie, periode: g.periode
        )
        #expect(anforderung(in: liste, id: "rechnung-\(ka.id.uuidString)")?.status == .erfuellt)
    }

    @Test("Rechnung ungeprueft (geprueft=false) → teilweise 'pruefen'")
    func rechnung_ungeprueft_teilweise() throws {
        let g = try grund()
        let ka = try ergaenzeKostenart(g)
        _ = try ergaenzeRechnung(g, kostenart: ka, geprueft: false)
        let liste = VollstaendigkeitsPruefung.pruefe(
            immobilie: g.immobilie, periode: g.periode
        )
        let anf = anforderung(in: liste, id: "rechnung-\(ka.id.uuidString)")
        #expect(anf?.status == .teilweise)
        #expect(anf?.anforderung.titel.lowercased().contains("prüfen") == true)
    }

    @Test("Rechnung geprueft + validiert + kein §35a → erfuellt")
    func rechnung_komplett_erfuellt() throws {
        let g = try grund()
        let ka = try ergaenzeKostenart(g)
        _ = try ergaenzeRechnung(g, kostenart: ka)
        let liste = VollstaendigkeitsPruefung.pruefe(
            immobilie: g.immobilie, periode: g.periode
        )
        #expect(anforderung(in: liste, id: "rechnung-\(ka.id.uuidString)")?.status == .erfuellt)
    }

    @Test("Inaktive Kostenart wird NICHT als Anforderung gelistet")
    func rechnung_inaktive_kostenart_fehlt() throws {
        let g = try grund()
        let ka = try ergaenzeKostenart(g)
        ka.aktiv = false
        try g.container.mainContext.save()

        let liste = VollstaendigkeitsPruefung.pruefe(
            immobilie: g.immobilie, periode: g.periode
        )
        #expect(anforderung(in: liste, id: "rechnung-\(ka.id.uuidString)") == nil)
    }

    // MARK: - zusammenfassung()

    @Test("zusammenfassung zaehlt Status-Kategorien korrekt")
    func zusammenfassung_zaehlt_korrekt() {
        let anf = DatenAnforderung(
            id: "x", kategorie: .stammdaten,
            titel: "T", details: "D", erforderlich: true
        )
        let liste: [AnforderungMitStatus] = [
            .init(anforderung: anf, status: .erfuellt),
            .init(anforderung: anf, status: .erfuellt),
            .init(anforderung: anf, status: .teilweise),
            .init(anforderung: anf, status: .offen),
            .init(anforderung: anf, status: .nichtErwartet)
        ]
        let z = VollstaendigkeitsPruefung.zusammenfassung(fuer: liste)
        #expect(z.erfuellt == 2)
        #expect(z.teilweise == 1)
        #expect(z.offen == 1)
        #expect(z.nichtErwartet == 1)
        #expect(z.total == 5)
    }

    @Test("zusammenfassung.bereit true nur wenn alle nicht-nichtErwartet erfuellt sind")
    func zusammenfassung_bereit_flag() {
        let anf = DatenAnforderung(
            id: "x", kategorie: .stammdaten,
            titel: "T", details: "D", erforderlich: true
        )
        let bereit: [AnforderungMitStatus] = [
            .init(anforderung: anf, status: .erfuellt),
            .init(anforderung: anf, status: .nichtErwartet)
        ]
        let nichtBereit: [AnforderungMitStatus] = [
            .init(anforderung: anf, status: .erfuellt),
            .init(anforderung: anf, status: .teilweise)
        ]
        #expect(VollstaendigkeitsPruefung.zusammenfassung(fuer: bereit).bereit)
        #expect(!VollstaendigkeitsPruefung.zusammenfassung(fuer: nichtBereit).bereit)
    }

    @Test("zusammenfassung.bereit false bei leerer Liste")
    func zusammenfassung_leer_nicht_bereit() {
        let z = VollstaendigkeitsPruefung.zusammenfassung(fuer: [])
        #expect(!z.bereit)
        #expect(z.total == 0)
    }
}
