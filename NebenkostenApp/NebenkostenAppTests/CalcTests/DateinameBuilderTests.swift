//
//  DateinameBuilderTests.swift
//  NebenkostenAppTests — CalcTests
//
//  Unit-Tests für das Dateinamens-Schema aus Task 1.1 (Core/
//  DateinameBuilder.swift). Reine Funktions-Tests, keine
//  SwiftData- oder Filesystem-Abhängigkeit.
//

import Foundation
import Testing
@testable import NebenkostenApp

@MainActor
struct DateinameBuilderTests {

    private let datum = DateinameBuilderTests.erstelleDatum(jahr: 2026, monat: 4, tag: 20)
    private let stableUUID = UUID(uuidString: "ABCD1234-5678-90AB-CDEF-123456789012")!

    // MARK: - Happy paths

    @Test("Alle Felder gesetzt: Datum + Typ + Versorger + Kontext + Betrag")
    func alleFelderGesetzt() async throws {
        let eingabe = DateinameBuilder.Eingabe(
            datum: datum,
            dokumenttyp: .rechnung,
            versorger: "GASAG",
            kontext: "Kalenderjahr 2025",
            betragBrutto: Decimal(string: "1234.56"),
            id: stableUUID
        )
        let name = DateinameBuilder.build(from: eingabe)
        #expect(name == "2026-04-20_Rechnung_GASAG_Kalenderjahr_2025_1234-56EUR.pdf")
    }

    @Test("Nur Pflichtfelder (Datum + Typ) — Optionale werden weggelassen")
    func nurPflichtfelder() async throws {
        let eingabe = DateinameBuilder.Eingabe(
            datum: datum,
            dokumenttyp: .bescheid,
            id: stableUUID
        )
        let name = DateinameBuilder.build(from: eingabe)
        #expect(name == "2026-04-20_Bescheid.pdf")
    }

    // MARK: - Normalisierung

    @Test("Umlaute im Versorger: ae/oe/ue/ss statt ä/ö/ü/ß")
    func umlauteNormalisiert() async throws {
        let eingabe = DateinameBuilder.Eingabe(
            datum: datum,
            dokumenttyp: .rechnung,
            versorger: "Müller & Söhne GmbH",
            id: stableUUID
        )
        let name = DateinameBuilder.build(from: eingabe)
        // "&" ist kein erlaubtes Zeichen → Underscore → Doppel-Underscore
        // wird eingedampft.
        #expect(name == "2026-04-20_Rechnung_Mueller_Soehne_GmbH.pdf")
    }

    @Test("Leerzeichen in Versorger und Kontext werden zu Underscores")
    func leerzeichen_zuUnderscore() async throws {
        let eingabe = DateinameBuilder.Eingabe(
            datum: datum,
            dokumenttyp: .handwerkerbeleg,
            versorger: "Leske Heizung Lüftung Sanitär",
            kontext: "Wartung Gasheizung 2024",
            id: stableUUID
        )
        let name = DateinameBuilder.build(from: eingabe)
        #expect(name == "2026-04-20_Beleg_Leske_Heizung_Lueftung_Sanitaer_Wartung_Gasheizung_2024.pdf")
    }

    // MARK: - Betrag

    @Test("Betrag mit Komma wird zu Dash")
    func betragKomma_zuDash() async throws {
        let eingabe = DateinameBuilder.Eingabe(
            datum: datum,
            dokumenttyp: .rechnung,
            versorger: "BWB",
            betragBrutto: Decimal(string: "1427.83"),
            id: stableUUID
        )
        let name = DateinameBuilder.build(from: eingabe)
        #expect(name.contains("_1427-83EUR."))
    }

    @Test("Ganzzahliger Betrag: '245EUR' ohne Dezimalstellen-Teil")
    func betragGanzzahlig() async throws {
        let eingabe = DateinameBuilder.Eingabe(
            datum: datum,
            dokumenttyp: .rechnung,
            versorger: "BSR",
            betragBrutto: 245,
            id: stableUUID
        )
        let name = DateinameBuilder.build(from: eingabe)
        #expect(name.contains("_245EUR."))
    }

    // MARK: - Fallback

    @Test("Komplett-Fallback: nur Datum, Typ .sonstiges, keine Zusatzfelder → UUID-Suffix")
    func komplettFallback() async throws {
        let eingabe = DateinameBuilder.Eingabe(
            datum: datum,
            dokumenttyp: .sonstiges,
            id: stableUUID
        )
        let name = DateinameBuilder.build(from: eingabe)
        // Format: 2026-04-20_Dokument_<4 Chars>.pdf
        #expect(name.hasPrefix("2026-04-20_Dokument_"))
        #expect(name.hasSuffix(".pdf"))
        let kern = name
            .replacingOccurrences(of: "2026-04-20_Dokument_", with: "")
            .replacingOccurrences(of: ".pdf", with: "")
        #expect(kern.count == 4, "Erwartet 4-stelligen UUID-Suffix, bekommen '\(kern)'")
    }

    // MARK: - Dokumenttyp-Mapping

    @Test("Alle Dokumenttypen mappen auf definierte Kurzform")
    func typKurzform_vollstaendig() async throws {
        let erwartet: [Dokumenttyp: String] = [
            .rechnung:          "Rechnung",
            .bescheid:          "Bescheid",
            .handwerkerbeleg:   "Beleg",
            .winterdienstbeleg: "Beleg",
            .zaehlerfoto:       "Zaehlerfoto",
            .mietvertrag:       "Mietvertrag",
            .sonstiges:         "Dokument"
        ]
        for (typ, kurz) in erwartet {
            #expect(DateinameBuilder.typKurz(typ) == kurz,
                    "\(typ) sollte \(kurz) liefern")
        }
    }

    // MARK: - Kollision

    @Test("Kollisions-Suffix: existierender Name bekommt 4-Chars-UUID-Anhang")
    func kollisionsSuffix() async throws {
        let eingabe = DateinameBuilder.Eingabe(
            datum: datum,
            dokumenttyp: .rechnung,
            versorger: "GASAG",
            id: stableUUID
        )
        let vorhanden: Set<String> = ["2026-04-20_Rechnung_GASAG.pdf"]
        let name = DateinameBuilder.build(from: eingabe, vorhandeneNamen: vorhanden)
        // Erwartet: Basis + "_<4 Chars>.pdf"
        #expect(name != "2026-04-20_Rechnung_GASAG.pdf")
        #expect(name.hasPrefix("2026-04-20_Rechnung_GASAG_"))
        #expect(name.hasSuffix(".pdf"))
        let suffix = name
            .replacingOccurrences(of: "2026-04-20_Rechnung_GASAG_", with: "")
            .replacingOccurrences(of: ".pdf", with: "")
        #expect(suffix.count == 4)
    }

    @Test("Kein Kollisions-Suffix, wenn Name frei ist")
    func keinSuffix_wennFrei() async throws {
        let eingabe = DateinameBuilder.Eingabe(
            datum: datum,
            dokumenttyp: .rechnung,
            versorger: "GASAG",
            id: stableUUID
        )
        let name = DateinameBuilder.build(from: eingabe, vorhandeneNamen: [])
        #expect(name == "2026-04-20_Rechnung_GASAG.pdf")
    }

    // MARK: - Helper

    private static func erstelleDatum(jahr: Int, monat: Int, tag: Int) -> Date {
        var k = DateComponents()
        k.year = jahr
        k.month = monat
        k.day = tag
        var kal = Calendar(identifier: .gregorian)
        kal.timeZone = TimeZone.current
        return kal.date(from: k)!
    }
}
