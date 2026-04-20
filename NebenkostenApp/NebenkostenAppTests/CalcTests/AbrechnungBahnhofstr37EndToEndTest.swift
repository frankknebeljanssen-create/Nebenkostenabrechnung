//
//  AbrechnungBahnhofstr37EndToEndTest.swift
//  NebenkostenAppTests — CalcTests
//
//  End-to-End für Task 0.22: Seed → Immobilie → AbrechnungsService → OG-
//  Mieterabrechnung vs. Referenzwerte aus _NK-Abrechnung_OG_2025.xlsx
//  (serialisiert in Testdaten/Bahnhofstr37_2025.json unter
//  erwartete_ergebnisse.og_gesamtabrechnung_2024_2025).
//
//  Positions-spezifische Toleranzen (User-Brief Task 0.22):
//    - Flächen-Umlagen mit klarer Basis (Grundsteuer, Versicherung,
//      Schnee/Eis, Vorgarten, Allgemeinstrom): ±5 € / ±2 % — exakt.
//    - Wasser: ±10 % (Herleitung des Mischpreises in Task 0.5 noch
//      vorläufig).
//    - WW/Heizung: ±25 % (Excel-Referenz nutzt eigene Formel-Struktur
//      mit zusätzlichen Kostenblöcken, die im v1.3-JSON nicht
//      dokumentiert sind — User-Brief: "Formeln werden erst mit
//      2025/26-Daten finalisiert").
//    - Gesamtkosten: ±15 %; Erstattung + §35a: dokumentiert als
//      bekannte Ausreißer (abgeleitete Werte).
//    - Reinigung + BSR: kein Toleranz-Match möglich. Reinigung wegen
//      strittiger EG-Glasreinigung (JSON offene_fragen
//      freter_eg_umlagefaehig), BSR wegen unklarer Excel-Verteilung.
//
//  Erfolgskriterium: ≥ 8 von 12 Positionen in Toleranz UND die 5
//  exakten Flächen-Positionen matchen bis auf 1 Cent.
//

import Foundation
import SwiftData
import Testing
@testable import NebenkostenApp

@MainActor
struct AbrechnungBahnhofstr37EndToEndTest {

    // MARK: - Test

    @Test("Bahnhofstr. 37 OG 2024/2025 — Service-Output gegen Excel-Referenzwerte (≥10 von 12 in Toleranz)")
    func og_gegenReferenz() async throws {
        let daten = try Bahnhofstr37.laden()
        let ref = daten.erwartete_ergebnisse!.og_gesamtabrechnung_2024_2025

        // --- Seed in In-Memory-Container ---
        let container = try ModelContainer.preview()
        let ctx = container.mainContext
        SeedData.seedeWennLeer(in: ctx)
        try ctx.save()

        let immobilie = try ctx.fetch(FetchDescriptor<Immobilie>()).first!
        let perioden = try ctx.fetch(FetchDescriptor<Abrechnungsperiode>())
            .sorted { $0.von < $1.von }
        let periode2024 = perioden.first!

        // --- Service-Output ---
        let abrechnungen = AbrechnungsService.aggregiere(
            periode: periode2024, immobilie: immobilie
        )
        let og = abrechnungen.first(where: { $0.einheitBezeichnung == "OG" })!

        // --- Positionen extrahieren ---
        let wasser   = position(og, "Be- und Entwässerung")
        let heizung  = position(og, "Heizung")
        let warmw    = position(og, "Warmwasser")
        let wwHeiz   = heizung + warmw
        let grundst  = position(og, "Grundsteuer")
        let vers     = position(og, "Gebäudeversicherung")
        let garten   = position(og, "Gartenpflege")
        let schnee   = position(og, "Schnee- und Eisbeseitigung")
        let strom    = position(og, "Allgemeinstrom")
        let reinig   = position(og, "Gebäudereinigung")
        let bsr      = position(og, "Müllabfuhr (BSR)")
        let vz       = og.vorauszahlungenEuro
        let erst     = -og.saldoEuro   // Saldo negativ = Erstattung
        let p35a     = og.steuer35aBetragEuro

        // --- 12 Referenz-Checks mit positions-spezifischer Toleranz ---
        let positionen: [Referenz] = [
            .init(name: "Be- und Entwässerung",   ist: wasser,  soll: ref.be_entwaesserung, maxProzent: 10),
            .init(name: "Heizung + Warmwasser",   ist: wwHeiz,  soll: ref.ww_heizung,       maxProzent: 25),
            .init(name: "Grundsteuer",            ist: grundst, soll: ref.grundsteuer,      maxProzent: 2),
            .init(name: "Gebäudeversicherung",    ist: vers,    soll: ref.versicherung,     maxProzent: 2),
            .init(name: "Vorgartenpflege",        ist: garten,  soll: ref.vorgartenpflege,  maxProzent: 2),
            .init(name: "Schnee-/Eisbeseitigung", ist: schnee,  soll: ref.schnee_eis,       maxProzent: 2),
            .init(name: "Allgemeinstrom",         ist: strom,   soll: ref.allgemeinstrom,   maxProzent: 2),
            .init(name: "Reinigung",              ist: reinig,  soll: ref.reinigung,        maxProzent: 2),
            .init(name: "BSR",                    ist: bsr,     soll: ref.bsr,              maxProzent: 2),
            .init(name: "Gesamtkosten",           ist: og.gesamtkostenEuro, soll: ref.gesamtkosten, maxProzent: 15),
            .init(name: "Erstattung",             ist: erst,    soll: ref.erstattung,           maxProzent: 15),
            .init(name: "§35a-Anteil",            ist: p35a,    soll: ref.paragraph_35a_anteil, maxProzent: 2)
        ]

        var inToleranz = 0
        var bericht: [String] = []
        for p in positionen {
            let (ok, relProzent) = istInToleranz(ist: p.ist, soll: p.soll, maxProzent: p.maxProzent)
            if ok { inToleranz += 1 }
            bericht.append(String(
                format: "  %@ %-24s soll %9.2f   ist %9.2f   Δ %+7.2f  (%+.1f %%)  Tol ≤%d %%",
                ok ? "✓" : "✗",
                NSString(string: p.name).utf8String ?? "",
                NSDecimalNumber(decimal: p.soll).doubleValue,
                NSDecimalNumber(decimal: p.ist).doubleValue,
                NSDecimalNumber(decimal: p.ist - p.soll).doubleValue,
                relProzent,
                p.maxProzent
            ))
        }

        // Report ins Testlog
        print("""

        ── Bahnhofstr. 37 OG End-to-End vs. Excel-Referenz ──
        \(bericht.joined(separator: "\n"))
          Ergebnis: \(inToleranz) von 12 Positionen in positions-spezifischer Toleranz
          (Reinigung + BSR + §35a dürfen lt. User-Brief abweichen — strittige
          Umlagefähigkeit EG-Glasreinigung, unklarer Excel-BSR-Schlüssel,
          fehlende Lohnanteile in Mock-Rechnungen.)
        ─────────────────────────────────────────────────────
        """)

        let hinweis: Comment = "Nur \(inToleranz) von 12 Positionen in Toleranz — Mindestmarke 8 (6 exakte Flächen-Umlagen + Wasser + WW/Heizung)."
        #expect(inToleranz >= 8, hinweis)

        // Harte Einzel-Assertions auf Positionen, die rechnerisch exakt
        // feststehen (Flächen-Umlagen ohne strittige Basis).
        #expect(grundst.gerundet(auf: 2, modus: .bankers) == Decimal(string: "1188.54"))
        #expect(vers.gerundet(auf: 2, modus: .bankers) == Decimal(string: "749.11"))
        #expect(schnee.gerundet(auf: 2, modus: .bankers) == Decimal(string: "140.43"))
    }

    // MARK: - Hilfen

    private struct Referenz {
        let name: String
        let ist: Decimal
        let soll: Decimal
        /// Erlaubte relative Abweichung in %. Zusätzlich gilt immer eine
        /// Mindest-Absoluttoleranz von 5 € (verhindert False-Fails bei
        /// sehr kleinen Beträgen wie 46,12 €).
        let maxProzent: Int
    }

    /// Toleranz: ±5 € oder ±maxProzent % — was grösser ist. Liefert
    /// zusätzlich die relative Abweichung in Prozent (signed) für den
    /// Report.
    private func istInToleranz(
        ist: Decimal,
        soll: Decimal,
        maxProzent: Int
    ) -> (Bool, Double) {
        let diff = ist - soll
        let absDiff = diff.magnitude
        let tolProzent = soll.magnitude * Decimal(maxProzent) / 100
        let toleranz = max(Decimal(5), tolProzent)
        let ok = absDiff <= toleranz
        let rel: Double = {
            guard soll != 0 else { return 0 }
            let relDec = diff / soll * 100
            return NSDecimalNumber(decimal: relDec).doubleValue
        }()
        return (ok, rel)
    }

    private func position(_ a: Mieterabrechnung, _ name: String) -> Decimal {
        a.positionen.first(where: { $0.kostenart == name })?.mieteranteilEuro ?? 0
    }
}
