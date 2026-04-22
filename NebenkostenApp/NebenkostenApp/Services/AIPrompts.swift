//
//  AIPrompts.swift
//  NebenkostenApp — Services
//
//  Typ-spezifische Prompts für die AI-Extraktion (Task 1.2-C4).
//
//  Jeder Prompt besteht aus:
//    1. Rolle (Assistent für Nebenkosten-Belege in Deutschland)
//    2. Aufgabe mit Feldliste
//    3. Strikt definiertem JSON-Antwort-Schema
//    4. Konfidenz-Forderung pro Feld (0…1)
//    5. Einem konkreten Beispiel für den jeweiligen Dokument-Typ
//
//  Generische Extraktion gibt es bewusst nicht — die Spezifik für
//  Gas/Wasser/Kommunal/Handwerker hat historisch deutlich bessere
//  Extraktions-Qualität gebracht.
//

import Foundation

enum AIPrompts {

    /// Wählt den passenden Prompt für einen Dokument-Typ. Für
    /// `sonstiges` (und `mietvertrag`, `zaehlerfoto`) greift der
    /// generische Fallback.
    static func fuer(typ: Dokumenttyp) -> String {
        switch typ {
        case .rechnung:            return rechnungGas
        case .handwerkerbeleg:     return handwerkerbeleg
        case .winterdienstbeleg:   return handwerkerbeleg
        case .bescheid:            return bescheidKommunal
        case .grundsteuerbescheid: return bescheidKommunal
        case .zaehlerfoto:         return fallback
        case .mietvertrag:         return fallback
        case .energieausweis:      return fallback
        case .sonstiges:           return fallback
        }
    }

    /// Prompt-Name für Logs / Tests (ohne den vollen Body rauszugeben).
    static func name(fuer typ: Dokumenttyp) -> String {
        switch typ {
        case .rechnung:            return "rechnungGas"
        case .handwerkerbeleg,
             .winterdienstbeleg:   return "handwerkerbeleg"
        case .bescheid,
             .grundsteuerbescheid: return "bescheidKommunal"
        case .zaehlerfoto,
             .mietvertrag,
             .energieausweis,
             .sonstiges:           return "fallback"
        }
    }

    // MARK: - Gemeinsamer Header

    private static let rolle = """
    Du bist ein Assistent für die Extraktion von Rechnungs- und
    Bescheid-Feldern aus deutschen Nebenkostenbelegen. Antworte
    AUSSCHLIESSLICH mit einem gültigen JSON-Objekt, keine Prosa, kein
    Markdown. Datumsfelder als ISO-8601 ("YYYY-MM-DD"). Unbekannte
    Felder bleiben null. Jedes gefüllte Feld bekommt zusätzlich eine
    Konfidenz 0…1 in konfidenzJeFeld; leere Felder werden im
    Konfidenz-Dict weggelassen.
    """

    // MARK: - Gas

    static let rechnungGas = """
    \(rolle)

    AUFGABE — Gas-Rechnung (z.B. GASAG):
    Extrahiere folgende Felder aus dem OCR-Text:
    - versorger (String, Markenname)
    - rechnungsNr (String)
    - dokumentDatum (ISO-Datum, Rechnungsdatum)
    - leistungszeitraumStart, leistungszeitraumEnde (ISO-Daten)
    - betragBrutto (Decimal, Gesamtsumme in EUR)
    - mwstSatz (Decimal, in Prozent, z.B. 19.0 oder 7.0)
    - positionenJSON (String, JSON-Array mit Einzelposten wie
      Arbeitspreis, Grundpreis, CO2-Abgabe, jeweils mit menge_kWh
      und betrag_eur). Leer lassen wenn nicht eindeutig strukturierbar.
    - kostenartVorschlag: "Heizung und Warmwasser"

    BEISPIEL-ANTWORT:
    {
      "versorger": "GASAG",
      "rechnungsNr": "211002198550",
      "dokumentDatum": "2025-10-15",
      "leistungszeitraumStart": "2024-10-08",
      "leistungszeitraumEnde": "2025-10-07",
      "betragBrutto": 3554.95,
      "mwstSatz": 19.0,
      "kostenartVorschlag": "Heizung und Warmwasser",
      "konfidenzJeFeld": { "versorger": 0.98, "betragBrutto": 0.95 }
    }
    """

    // MARK: - Wasser

    static let rechnungWasser = """
    \(rolle)

    AUFGABE — Wasser-Rechnung (z.B. Berliner Wasserbetriebe):
    Extrahiere folgende Felder:
    - versorger (String)
    - rechnungsNr (String)
    - dokumentDatum (ISO-Datum)
    - leistungszeitraumStart, leistungszeitraumEnde (ISO-Daten)
    - betragBrutto (Decimal, Gesamtsumme in EUR)
    - mwstSatz (Decimal, Prozent)
    - positionenJSON: JSON-Array aus Trinkwasser und Schmutzwasser
      mit je {art, menge_m3, preis_pro_m3, grundgebuehr, gesamt}.
      Gartenzwischenzähler-Abzug falls ausgewiesen als eigene Position
      mit menge_m3 und negativ betrag_eur.
    - kostenartVorschlag: "Be- und Entwässerung"

    BEISPIEL-ANTWORT:
    {
      "versorger": "Berliner Wasserbetriebe",
      "rechnungsNr": "200065188",
      "dokumentDatum": "2025-10-22",
      "leistungszeitraumStart": "2024-10-10",
      "leistungszeitraumEnde": "2025-10-22",
      "betragBrutto": 1427.83,
      "mwstSatz": 7.0,
      "positionenJSON": "[{\\"art\\":\\"Trinkwasser\\",\\"menge_m3\\":434,\\"gesamt\\":866.74}]",
      "kostenartVorschlag": "Be- und Entwässerung",
      "konfidenzJeFeld": { "versorger": 0.97, "betragBrutto": 0.96 }
    }
    """

    // MARK: - Kommunal-Bescheid

    static let bescheidKommunal = """
    \(rolle)

    AUFGABE — Kommunaler Bescheid (BSR, Grundsteuer):
    Extrahiere folgende Felder:
    - versorger (String, Behörde oder Versorger, z.B. "BSR",
      "Finanzamt Berlin")
    - rechnungsNr (String, Bescheid- oder Aktenzeichen)
    - dokumentDatum (ISO-Datum, Bescheidausstellung)
    - leistungszeitraumStart, leistungszeitraumEnde (i.d.R.
      Kalenderjahr 01.01.–31.12.)
    - betragBrutto (Decimal, Jahresbetrag)
    - mwstSatz: null (Bescheide sind nicht mwst-pflichtig)
    - positionenJSON: JSON-Array mit {art, betrag_eur} je Teilposten
      (z.B. Hausmüll, Grundgebühr, Bio bei BSR).
    - kostenartVorschlag: "Müllabfuhr (BSR)" oder "Grundsteuer"

    BEISPIEL-ANTWORT:
    {
      "versorger": "BSR Berliner Stadtreinigung",
      "rechnungsNr": "220448697",
      "dokumentDatum": "2025-01-31",
      "leistungszeitraumStart": "2025-01-01",
      "leistungszeitraumEnde": "2025-12-31",
      "betragBrutto": 527.84,
      "kostenartVorschlag": "Müllabfuhr (BSR)",
      "konfidenzJeFeld": { "versorger": 0.99, "betragBrutto": 0.98 }
    }
    """

    // MARK: - Handwerkerbeleg

    static let handwerkerbeleg = """
    \(rolle)

    AUFGABE — Handwerkerbeleg (Wartung, Schornsteinfeger, Reinigung,
    Winterdienst):
    Extrahiere folgende Felder:
    - versorger (String, Firmenname)
    - rechnungsNr (String)
    - dokumentDatum (ISO-Datum, Rechnungsdatum)
    - leistungszeitraumStart, leistungszeitraumEnde (ISO, optional)
    - betragBrutto (Decimal)
    - mwstSatz (Decimal, meist 19.0)
    - positionenJSON: JSON-Array mit {art, netto, mwst, brutto,
      arbeitskosten_brutto}. Arbeitskosten sind §35a-relevant —
      unbedingt separat ausweisen wenn auf der Rechnung erkennbar.
    - kostenartVorschlag: "Gebäudereinigung", "Schornsteinfeger",
      "Schnee- und Eisbeseitigung" oder "Heizung und Warmwasser"
      (Wartung), je nach Tätigkeit.

    BEISPIEL-ANTWORT:
    {
      "versorger": "Leske Heizung Lüftung Sanitär GmbH",
      "rechnungsNr": "242238",
      "dokumentDatum": "2024-12-06",
      "betragBrutto": 279.91,
      "mwstSatz": 19.0,
      "positionenJSON": "[{\\"art\\":\\"Wartung Gasheizung\\",\\"arbeitskosten_brutto\\":279.91}]",
      "kostenartVorschlag": "Heizung und Warmwasser",
      "konfidenzJeFeld": { "versorger": 0.96, "betragBrutto": 0.95 }
    }
    """

    // MARK: - Fallback

    static let fallback = """
    \(rolle)

    AUFGABE — Generische Dokument-Extraktion:
    Extrahiere grundlegende Rechnungs-Felder:
    - versorger (String, Aussteller)
    - rechnungsNr (String, falls vorhanden)
    - dokumentDatum (ISO-Datum)
    - betragBrutto (Decimal, falls erkennbar)
    - mwstSatz (Decimal, Prozent)
    - kostenartVorschlag: null (keine Vermutung bei unklarem Typ)

    BEISPIEL-ANTWORT:
    {
      "versorger": "Unbekannter Aussteller",
      "dokumentDatum": "2025-06-15",
      "betragBrutto": 130.24,
      "mwstSatz": 19.0,
      "konfidenzJeFeld": { "versorger": 0.6, "betragBrutto": 0.7 }
    }
    """
}
