//
//  VollstaendigkeitsPruefungSprungzielTests.swift
//  NebenkostenAppTests — CalcTests
//
//  Prüft, dass die VollstaendigkeitsPruefung für jede Regel das
//  richtige Sprungziel + passende Schwere liefert. Nutzt den
//  Bahnhofstr37-Seed, daher async throws + ModelContainer.preview.
//

import Foundation
import SwiftData
import Testing
@testable import NebenkostenApp

@MainActor
@Suite(.serialized)
struct VollstaendigkeitsPruefungSprungzielTests {

    private struct SeedErgebnis {
        let container: ModelContainer
        let immobilie: Immobilie
        let periode: Abrechnungsperiode
    }

    private func seed() throws -> SeedErgebnis {
        let container = try ModelContainer.preview()
        let ctx = container.mainContext
        SeedData.seedeWennLeer(in: ctx)
        try ctx.save()
        let immobilie = try ctx.fetch(FetchDescriptor<Immobilie>()).first!
        let periode = (immobilie.perioden ?? []).sorted { $0.von < $1.von }.first!
        return SeedErgebnis(container: container, immobilie: immobilie, periode: periode)
    }

    // MARK: - Stammdaten-Regeln

    @Test("stammdaten-gesamtflaeche trägt .einstellungenObjekt")
    func gesamtflaeche_sprungziel() async throws {
        let s = try seed()
        let liste = VollstaendigkeitsPruefung.pruefe(
            immobilie: s.immobilie, periode: s.periode
        )
        let anf = liste.first { $0.anforderung.id == "stammdaten-gesamtflaeche" }
        #expect(anf?.sprungZiel == .einstellungenObjekt)
        #expect(anf?.schwere == .blocker)
    }

    @Test("stammdaten-wohneinheiten trägt .einstellungenObjekt")
    func wohneinheiten_sprungziel() async throws {
        let s = try seed()
        let liste = VollstaendigkeitsPruefung.pruefe(
            immobilie: s.immobilie, periode: s.periode
        )
        let anf = liste.first { $0.anforderung.id == "stammdaten-wohneinheiten" }
        #expect(anf?.sprungZiel == .einstellungenObjekt)
    }

    @Test("stammdaten-periode trägt .einstellungenPeriode")
    func periode_sprungziel() async throws {
        let s = try seed()
        let liste = VollstaendigkeitsPruefung.pruefe(
            immobilie: s.immobilie, periode: s.periode
        )
        let anf = liste.first { $0.anforderung.id == "stammdaten-periode" }
        #expect(anf?.sprungZiel == .einstellungenPeriode)
    }

    @Test("stammdaten-vorauszahlung trägt .mieterVorauszahlung mit Einheit-ID")
    func vorauszahlung_sprungziel() async throws {
        let s = try seed()
        let liste = VollstaendigkeitsPruefung.pruefe(
            immobilie: s.immobilie, periode: s.periode
        )
        let anf = liste.first { $0.anforderung.id == "stammdaten-vorauszahlung" }
        #expect(anf != nil)
        if case .mieterVorauszahlung(let id) = anf?.sprungZiel {
            #expect(!id.isEmpty, "Einheit-ID sollte gesetzt sein, got: \(id)")
        } else {
            Issue.record("Sprungziel ist nicht .mieterVorauszahlung — \(String(describing: anf?.sprungZiel))")
        }
    }

    // MARK: - Zähler-Regeln

    @Test("zaehler-<uuid> trägt .zaehlerstandErfassen(zaehlerId: uuid)")
    func zaehler_sprungziel() async throws {
        let s = try seed()
        let liste = VollstaendigkeitsPruefung.pruefe(
            immobilie: s.immobilie, periode: s.periode
        )
        let zaehlerAnforderungen = liste.filter { $0.anforderung.kategorie == .zaehlerstand
            && $0.anforderung.id != "plausi-wmz" }
        #expect(!zaehlerAnforderungen.isEmpty)
        for anf in zaehlerAnforderungen {
            if case .zaehlerstandErfassen(let id) = anf.sprungZiel {
                #expect(anf.anforderung.id == "zaehler-\(id.uuidString)")
            } else {
                Issue.record("Zähler-Anforderung ohne korrektes Sprungziel: \(anf.anforderung.id)")
            }
        }
    }

    // MARK: - Rechnungs-Regeln

    @Test("rechnung-<kostenart> trägt .rechnungKostenart(id)")
    func rechnung_sprungziel() async throws {
        let s = try seed()
        let liste = VollstaendigkeitsPruefung.pruefe(
            immobilie: s.immobilie, periode: s.periode
        )
        let rechnungsAnforderungen = liste.filter { $0.anforderung.kategorie == .rechnung }
        #expect(!rechnungsAnforderungen.isEmpty)
        for anf in rechnungsAnforderungen {
            if case .rechnungKostenart(let id) = anf.sprungZiel {
                #expect(anf.anforderung.id == "rechnung-\(id.uuidString)")
            } else {
                Issue.record("Rechnungs-Anforderung ohne korrektes Sprungziel: \(anf.anforderung.id)")
            }
        }
    }

    // MARK: - Schwere-Default

    @Test("Alle Stammdaten-, Zähler-, Rechnungs-Regeln haben Schwere .blocker")
    func default_schwere_blocker() async throws {
        let s = try seed()
        let liste = VollstaendigkeitsPruefung.pruefe(
            immobilie: s.immobilie, periode: s.periode
        )
        for anf in liste where anf.anforderung.id != "plausi-wmz" {
            #expect(anf.schwere == .blocker, "Regel \(anf.anforderung.id) sollte .blocker sein")
        }
    }

    @Test("blockiertBerechnung ist true nur bei schwere=.blocker && status=.offen")
    func blockiertBerechnung_logik() {
        let anf = DatenAnforderung(id: "x", kategorie: .stammdaten,
                                    titel: "T", details: "D", erforderlich: true)
        let blocker_offen = AnforderungMitStatus(
            anforderung: anf, status: .offen, schwere: .blocker
        )
        #expect(blocker_offen.blockiertBerechnung)

        let blocker_erfuellt = AnforderungMitStatus(
            anforderung: anf, status: .erfuellt, schwere: .blocker
        )
        #expect(!blocker_erfuellt.blockiertBerechnung)

        let warnung_offen = AnforderungMitStatus(
            anforderung: anf, status: .offen, schwere: .warnung
        )
        #expect(!warnung_offen.blockiertBerechnung)

        let warnung_teilweise = AnforderungMitStatus(
            anforderung: anf, status: .teilweise, schwere: .warnung
        )
        #expect(!warnung_teilweise.blockiertBerechnung)
    }
}
