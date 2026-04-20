//
//  AIExtraktionServiceTests.swift
//  NebenkostenAppTests — CalcTests
//
//  Tests für die Prompt-Auswahl (AIPrompts) und die Parse-Pipeline
//  (AIExtraktionService). Der echte AI-Call ist in Task 1.2 ein Stub —
//  hier wird geprüft, dass die testbaren Randbereiche korrekt
//  arbeiten.
//

import Foundation
import Testing
@testable import NebenkostenApp

@MainActor
struct AIExtraktionServiceTests {

    // MARK: - Prompt-Auswahl

    @Test("Typ-spezifischer Prompt: rechnung → rechnungGas")
    func typ_rechnung_wirft_gas_prompt() async throws {
        let prompt = AIPrompts.fuer(typ: .rechnung)
        #expect(prompt.contains("Gas-Rechnung"))
        #expect(AIPrompts.name(fuer: .rechnung) == "rechnungGas")
    }

    @Test("Typ-spezifischer Prompt: bescheid → bescheidKommunal")
    func typ_bescheid_wirft_bescheid_prompt() async throws {
        let prompt = AIPrompts.fuer(typ: .bescheid)
        #expect(prompt.contains("Kommunaler Bescheid"))
        #expect(AIPrompts.name(fuer: .bescheid) == "bescheidKommunal")
    }

    @Test("Typ-spezifischer Prompt: handwerkerbeleg und winterdienstbeleg → gleicher Prompt")
    func handwerker_und_winterdienst_teilen_prompt() async throws {
        let p1 = AIPrompts.fuer(typ: .handwerkerbeleg)
        let p2 = AIPrompts.fuer(typ: .winterdienstbeleg)
        #expect(p1 == p2)
        #expect(p1.contains("Handwerkerbeleg"))
        #expect(AIPrompts.name(fuer: .winterdienstbeleg) == "handwerkerbeleg")
    }

    @Test("Fallback-Prompt für sonstiges, zaehlerfoto, mietvertrag")
    func fallback_prompt_fuer_sonstiges() async throws {
        let sonstiges = AIPrompts.fuer(typ: .sonstiges)
        let zaehler = AIPrompts.fuer(typ: .zaehlerfoto)
        let miet = AIPrompts.fuer(typ: .mietvertrag)
        #expect(sonstiges.contains("Generische Dokument-Extraktion"))
        #expect(zaehler == sonstiges)
        #expect(miet == sonstiges)
        #expect(AIPrompts.name(fuer: .sonstiges) == "fallback")
    }

    @Test("Alle Prompts verlangen AUSSCHLIESSLICH JSON")
    func alle_prompts_fordern_json() async throws {
        for typ in Dokumenttyp.allCases {
            let p = AIPrompts.fuer(typ: typ)
            #expect(p.contains("JSON"),
                    "\(typ) muss JSON im Prompt fordern")
        }
    }

    // MARK: - Parse

    @Test("Gültiger JSON wird korrekt geparst")
    func parse_gueltig() async throws {
        let json = """
        {
          "versorger": "GASAG",
          "rechnungsNr": "211002198550",
          "betragBrutto": 3554.95,
          "mwstSatz": 19.0,
          "kostenartVorschlag": "Heizung und Warmwasser",
          "konfidenzJeFeld": { "versorger": 0.98, "betragBrutto": 0.95 }
        }
        """.data(using: .utf8)!

        let vorschlag = AIExtraktionService.parseWorkerAntwort(data: json)
        #expect(vorschlag.versorger == "GASAG")
        #expect(vorschlag.rechnungsNr == "211002198550")
        #expect(vorschlag.betragBrutto == Decimal(string: "3554.95"))
        #expect(vorschlag.mwstSatz == Decimal(string: "19.0"))
        #expect(vorschlag.kostenartVorschlag == "Heizung und Warmwasser")
        #expect(vorschlag.konfidenzJeFeld?["versorger"] == 0.98)
    }

    @Test("Invalider JSON → leerer Default-Vorschlag, kein Crash")
    func parse_invalid_liefert_leer() async throws {
        let kaputt = "this is not JSON".data(using: .utf8)!
        var fehlerZaehler = 0
        let vorschlag = AIExtraktionService.parseWorkerAntwort(data: kaputt) { _ in
            fehlerZaehler += 1
        }
        #expect(vorschlag.versorger == nil)
        #expect(vorschlag.betragBrutto == nil)
        #expect(vorschlag.konfidenzJeFeld == nil)
        #expect(fehlerZaehler == 1, "Parse-Fehler-Callback muss genau einmal gerufen werden")
    }

    // MARK: - Konfidenz-Mapping

    @Test("Konfidenz-Dict roundtrippt durch Entity-Data")
    func konfidenz_roundtrip() async throws {
        var json = AIVorschlagJSON()
        json.versorger = "BWB"
        json.konfidenzJeFeld = ["versorger": 0.97, "betragBrutto": 0.9]

        let entity = AIVorschlag()
        AIExtraktionService.uebertrage(json, nach: entity)

        let zurueck = AIExtraktionService.konfidenzen(aus: entity)
        #expect(zurueck["versorger"] == 0.97)
        #expect(zurueck["betragBrutto"] == 0.9)
        #expect(entity.versorger == "BWB")
    }

    @Test("uebertrage kopiert alle Spec-Felder")
    func uebertrage_alle_felder() async throws {
        var json = AIVorschlagJSON()
        json.versorger = "Leske GmbH"
        json.rechnungsNr = "242238"
        // Decimal(string:) vermeidet die Double→Decimal-Ungenauigkeit
        // (279.91 als Literal wird 279.9100000000000512).
        json.betragBrutto = Decimal(string: "279.91")!
        json.mwstSatz = Decimal(string: "19.0")!
        json.kostenartVorschlag = "Heizung und Warmwasser"
        json.positionenJSON = "[{\"art\":\"Wartung\",\"brutto\":279.91}]"

        let entity = AIVorschlag()
        AIExtraktionService.uebertrage(json, nach: entity)

        #expect(entity.versorger == "Leske GmbH")
        #expect(entity.rechnungsNr == "242238")
        #expect(entity.betragBrutto == Decimal(string: "279.91"))
        #expect(entity.mwstSatz == Decimal(string: "19.0"))
        #expect(entity.kostenartVorschlag == "Heizung und Warmwasser")
        #expect(entity.positionenJSON?.contains("Wartung") == true)
    }

    // MARK: - Stub-Verhalten

    @Test("Stub-extrahiere liefert Vorschlag mit übergebenem Versorger-Hint")
    func stub_uebergibt_hint() async throws {
        let vorschlag = try await AIExtraktionService.extrahiere(
            ocrText: "Test-OCR", typ: .rechnung, versorgerHint: "GASAG"
        )
        #expect(vorschlag.versorger == "GASAG")
    }
}
