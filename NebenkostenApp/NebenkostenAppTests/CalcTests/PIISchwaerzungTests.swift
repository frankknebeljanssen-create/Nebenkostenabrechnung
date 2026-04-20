//
//  PIISchwaerzungTests.swift
//  NebenkostenAppTests — CalcTests
//
//  Regex-Coverage für die PII-Schwärzung (Task 1.2-C5).
//  Prüft, dass personenbezogene Daten verschwinden UND dass
//  Kundennummern etc. stehen bleiben (Negativ-Kontrolle).
//

import Foundation
import Testing
@testable import NebenkostenApp

@MainActor
struct PIISchwaerzungTests {

    // MARK: - Adresse

    @Test("Adresse einzeilig: 'Bahnhofstr. 37, 12207 Berlin' wird geschwärzt")
    func adresse_einzeilig() async throws {
        let text = "Anschrift: Bahnhofstr. 37, 12207 Berlin (Versorger)"
        let out = PIISchwaerzung.apply(text: text)
        #expect(out.contains("[ADRESSE]"), "Adresse sollte ersetzt sein, out=\(out)")
        #expect(!out.contains("Bahnhofstr. 37"))
        #expect(!out.contains("12207 Berlin"))
    }

    @Test("Adresse mehrzeilig: Straße in Zeile 1, PLZ+Ort in Zeile 2")
    func adresse_mehrzeilig() async throws {
        let text = """
        Rechnung an:
        Bahnhofstraße 37
        12207 Berlin
        Betrag: 123,45 €
        """
        let out = PIISchwaerzung.apply(text: text)
        #expect(out.contains("[ADRESSE]"))
        #expect(!out.contains("Bahnhofstraße 37"))
        #expect(!out.contains("12207 Berlin"))
        #expect(out.contains("Betrag: 123,45 €"), "Betrag muss erhalten bleiben")
    }

    // MARK: - Telefon

    @Test("Telefon national mit Bindestrich: '030-92142640' wird geschwärzt")
    func telefon_national_bindestrich() async throws {
        let text = "Festnetz: 030-92142640"
        let out = PIISchwaerzung.apply(text: text)
        #expect(out.contains("[TELEFON]"))
        #expect(!out.contains("030-92142640"))
    }

    @Test("Telefon international: '+49 30 92142640' wird geschwärzt")
    func telefon_international() async throws {
        let text = "Hotline +49 30 92142640 erreichbar Mo-Fr."
        let out = PIISchwaerzung.apply(text: text)
        #expect(out.contains("[TELEFON]"))
        #expect(!out.contains("+49 30 92142640"))
    }

    @Test("Telefon mit Tel.-Label: 'Tel.: 0177-7588365' wird geschwärzt")
    func telefon_mit_label() async throws {
        let text = "Kontakt\nTel.: 0177-7588365"
        let out = PIISchwaerzung.apply(text: text)
        #expect(out.contains("[TELEFON]"))
        #expect(!out.contains("0177-7588365"))
    }

    // MARK: - E-Mail + IBAN

    @Test("E-Mail-Adresse wird geschwärzt")
    func email_geschwaerzt() async throws {
        let text = "Bei Rückfragen: verena.janszen@hotmail.com"
        let out = PIISchwaerzung.apply(text: text)
        #expect(out.contains("[EMAIL]"))
        #expect(!out.contains("@hotmail.com"))
    }

    @Test("IBAN wird geschwärzt, Kontonummer-ähnliche Ziffernfolgen bleiben")
    func iban_geschwaerzt() async throws {
        let text = """
        IBAN: DE89 3704 0044 0532 0130 00
        Kundennummer: 123456789
        """
        let out = PIISchwaerzung.apply(text: text)
        #expect(out.contains("[IBAN]"))
        #expect(!out.contains("DE89"))
        #expect(out.contains("123456789"), "Kundennummer muss erhalten bleiben")
    }

    // MARK: - Namen

    @Test("Mietername aus Kontext wird zu [MIETER]")
    func mietername_ersetzt() async throws {
        let kontext = PIIKontext(mieterNamen: ["Frank Knebel-Janßen", "Sandra Pfaffenbach"])
        let text = "Mieter OG: Sandra Pfaffenbach. Mieter KG: Frank Knebel-Janßen."
        let out = PIISchwaerzung.apply(text: text, kontext: kontext)
        #expect(out.contains("[MIETER]"))
        #expect(!out.contains("Sandra Pfaffenbach"))
        #expect(!out.contains("Frank Knebel-Janßen"))
    }

    @Test("Vermieter-Name wird zu [VERMIETER]")
    func vermieter_ersetzt() async throws {
        let kontext = PIIKontext(vermieterName: "Verena Janßen")
        let text = "Vermieterin: Verena Janßen, Steuer-Nr 25/743/01236"
        let out = PIISchwaerzung.apply(text: text, kontext: kontext)
        #expect(out.contains("[VERMIETER]"))
        #expect(!out.contains("Verena Janßen"))
        // Steuernummer ist kein PII in diesem Kontext — Feld, kein Name.
    }

    // MARK: - Negativ-Kontrolle

    @Test("Kundennummer/Rechnungsnummer (6+ Ziffern ohne Kontext) bleibt stehen")
    func kundennummer_bleibt() async throws {
        let text = """
        Kundennummer: 7012345
        Rechnungsnummer: 211002198550
        """
        let out = PIISchwaerzung.apply(text: text)
        #expect(out.contains("7012345"))
        #expect(out.contains("211002198550"))
        #expect(!out.contains("[TELEFON]"))
    }

    @Test("Datumsangabe und Betrag bleiben unverändert")
    func datum_betrag_bleiben() async throws {
        let text = "Rechnungsdatum: 06.12.2024 · Betrag: 279,91 €"
        let out = PIISchwaerzung.apply(text: text)
        #expect(out.contains("06.12.2024"))
        #expect(out.contains("279,91"))
        #expect(!out.contains("[TELEFON]"))
    }
}
