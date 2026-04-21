//
//  MietvertragsExtraktion.swift
//  NebenkostenApp — Services
//
//  Datentypen + Service fuer die Mietvertrags-KI-Extraktion.
//  Eingangs-Pfad: scanned PDF/Image → Claude Vision API (via
//  `AnthropicClient`) → `MietvertragsAnalyse` mit Feldern +
//  Konfidenzen + erkanntem Dokument-Typ. Die UI (NeuesObjektSheet
//  / KontextDetailSheet) rendert die Vorschau mit Ampel-Punkten
//  pro Feld und laesst den User jeden Wert ueberschreiben.
//
//  Realer API-Call
//  ---------------
//  Die Produktiv-Pipeline laeuft ueber die Anthropic Messages API
//  mit einem System-Prompt + User-Prompt + einem/mehreren image-
//  Content-Bloecken. Claude antwortet mit reinem JSON (kein
//  Markdown-Fence, siehe `AnthropicClient.trimJSONFence`), das
//  hier ins domainspezifische `MietvertragsExtraktion`-Modell
//  gemappt wird.
//
//  Keine Fake-Daten im Code-Pfad — AUCH NICHT in DEBUG
//  ---------------------------------------------------
//  Ohne konfigurierten API-Key wirft `extrahiere` IMMER
//  `Fehler.keinAPIKey` — auch im DEBUG-Build. Die UI zeigt den
//  User-lesbaren Text; der User setzt den Key in den Einstellungen
//  (Debug-Section: „Anthropic API-Key (Scan)"). Frueher gab es in
//  DEBUG einen Fallback auf Demo-Daten („Hans Beispielmieter"),
//  der ist jetzt weg — Mock-Daten in keiner Build-Variante.
//

import Foundation
import UIKit

// MARK: - Feld-Primitives

/// Ein extrahiertes Feld mit Konfidenz 0…1.
///  - 0.8…1.0 → gruen (System-Status-Ok)
///  - 0.5…<0.8 → gelb (Warn, bitte pruefen)
///  - <0.5 → rot (Error, nicht zuverlaessig — besser manuell)
///  - `wert == nil` → nicht erkannt, Konfidenz 0.
struct FeldMitKonfidenz<T: Equatable & Sendable>: Equatable, Sendable {
    let wert: T?
    let konfidenz: Double

    static var leer: FeldMitKonfidenz<T> {
        .init(wert: nil, konfidenz: 0)
    }

    enum Ampel: Sendable {
        case gruen
        case gelb
        case rot
        case nichtErkannt
    }

    var ampel: Ampel {
        guard wert != nil else { return .nichtErkannt }
        if konfidenz >= 0.8 { return .gruen }
        if konfidenz >= 0.5 { return .gelb }
        return .rot
    }
}

// MARK: - Extraktions-Ergebnis

struct MietvertragsExtraktion: Equatable, Sendable {
    var adresse: FeldMitKonfidenz<String>
    var plz: FeldMitKonfidenz<String>
    var stadt: FeldMitKonfidenz<String>
    var gesamtflaecheM2: FeldMitKonfidenz<Decimal>

    var einheitBezeichnung: FeldMitKonfidenz<String>
    var einheitFlaecheM2: FeldMitKonfidenz<Decimal>

    var mieterName: FeldMitKonfidenz<String>
    var mieterAnschrift: FeldMitKonfidenz<String>
    var einzugAm: FeldMitKonfidenz<Date>

    /// Aktuelle NK-Vorauszahlung pro Monat. Bei Erhoehungsschreiben
    /// der NEUE Betrag.
    var vorauszahlungMonatEuro: FeldMitKonfidenz<Decimal>
    /// Vorheriger NK-Vorauszahlungs-Betrag (nur bei
    /// Erhoehungsschreiben gefuellt).
    var vorauszahlungVorherEuro: FeldMitKonfidenz<Decimal>
    /// Stichtag, ab dem die neue NK-VZ gilt.
    var vorauszahlungGueltigAb: FeldMitKonfidenz<Date>

    /// Kaltmiete pro Monat (aktueller bzw. neuer Betrag).
    var kaltmieteEuro: FeldMitKonfidenz<Decimal>
    /// Vorherige Kaltmiete — nur bei Erhoehungsschreiben.
    var kaltmieteVorherEuro: FeldMitKonfidenz<Decimal>
    /// Stichtag, ab dem die neue Kaltmiete gilt.
    var kaltmieteGueltigAb: FeldMitKonfidenz<Date>

    var abrechnungsturnus: FeldMitKonfidenz<String>
    var kaution: FeldMitKonfidenz<Decimal>
    var besondereNKVereinbarungen: FeldMitKonfidenz<String>

    static let leer = MietvertragsExtraktion(
        adresse:                    .leer,
        plz:                        .leer,
        stadt:                      .leer,
        gesamtflaecheM2:            .leer,
        einheitBezeichnung:         .leer,
        einheitFlaecheM2:           .leer,
        mieterName:                 .leer,
        mieterAnschrift:            .leer,
        einzugAm:                   .leer,
        vorauszahlungMonatEuro:     .leer,
        vorauszahlungVorherEuro:    .leer,
        vorauszahlungGueltigAb:     .leer,
        kaltmieteEuro:              .leer,
        kaltmieteVorherEuro:        .leer,
        kaltmieteGueltigAb:         .leer,
        abrechnungsturnus:          .leer,
        kaution:                    .leer,
        besondereNKVereinbarungen:  .leer
    )
}

/// Kombi aus strukturierter Extraktion + erkanntem Dokument-Typ.
struct MietvertragsAnalyse: Equatable, Sendable {
    var extraktion: MietvertragsExtraktion
    var erkannterTyp: DokumentTyp
    /// Hinweise, die Claude mitliefert (z.B. „Seite 2 fehlt",
    /// „Ueberschrift schlecht lesbar"). Werden als Warnungen im
    /// AnalyseBefundView angezeigt.
    var hinweise: [String]
}

// MARK: - Service

@MainActor
enum MietvertragsExtraktionService {

    enum Fehler: Error, LocalizedError {
        case keineBilder
        case keinAPIKey
        case netzwerk(underlying: Error)
        case parseFehler(String)

        var errorDescription: String? {
            switch self {
            case .keineBilder:       return "Keine Seiten gescannt."
            case .keinAPIKey:
                return "Anthropic-API-Key nicht konfiguriert. Bitte in den Einstellungen hinterlegen."
            case .netzwerk(let u):   return "Netzwerkfehler bei der KI-Analyse: \(u.localizedDescription)"
            case .parseFehler(let d): return "KI-Antwort konnte nicht interpretiert werden: \(d)"
            }
        }
    }

    // MARK: - Hauptaufruf

    static func extrahiere(ausBildern bilder: [UIImage]) async throws -> MietvertragsAnalyse {
        guard !bilder.isEmpty else { throw Fehler.keineBilder }

        // Ohne API-Key: IMMER Fehler, auch in DEBUG. Kein Fake-
        // Daten-Fallback mehr — der User muss den Key in den
        // Einstellungen setzen, sonst geht der Scan nicht.
        guard AnthropicClient.istKonfiguriert else {
            throw Fehler.keinAPIKey
        }

        let antwortText: String
        do {
            antwortText = try await AnthropicClient.extrahiere(
                bilder: bilder,
                systemPrompt: Self.systemPrompt,
                userPrompt: Self.userPrompt
            )
        } catch AnthropicClient.Fehler.keinAPIKey {
            throw Fehler.keinAPIKey
        } catch {
            throw Fehler.netzwerk(underlying: error)
        }

        guard let daten = antwortText.data(using: .utf8) else {
            throw Fehler.parseFehler("Antwort nicht UTF-8")
        }
        let antwort: ClaudeAntwort
        do {
            antwort = try JSONDecoder().decode(ClaudeAntwort.self, from: daten)
        } catch {
            throw Fehler.parseFehler("JSON-Decoding: \(error.localizedDescription)")
        }

        return mappe(antwort)
    }

    // MARK: - Prompt

    /// System-Prompt: Rolle + Antwort-Format.
    private static let systemPrompt = """
    Du bist ein Assistent für die Extraktion von Feldern aus deutschen
    Mietdokumenten (Mietvertrag, Mietvertrags-Nachtrag, NK-Erhöhungs-
    schreiben, Übergabeprotokoll). Antworte AUSSCHLIESSLICH mit einem
    gültigen JSON-Objekt, keine Prosa, kein Markdown. Datumsfelder im
    Format "YYYY-MM-DD". Felder, die du nicht erkennst, sind null.
    Pro gefuelltem Feld gib zusätzlich eine Konfidenz 0…1 in
    konfidenz[FELDNAME] an.
    """

    /// User-Prompt mit konkretem JSON-Schema.
    private static let userPrompt = """
    Analysiere das beigefuegte deutsche Mietdokument und extrahiere
    alle relevanten Felder.

    Gib ausschliesslich folgendes JSON-Objekt zurueck:
    {
      "dokumentTyp": "mietvertrag|nachtrag|erhoehungsschreiben|uebergabeprotokoll|sonstiges",
      "mieterName": "...",
      "mieterAnschrift": "...",
      "objektStrasse": "...",
      "objektPlz": "...",
      "objektStadt": "...",
      "wohneinheit": "EG|OG|KG|<freier Text>",
      "flaecheM2": 187.5,
      "einzugDatum": "YYYY-MM-DD",
      "vorauszahlungNKEuro": 260.0,
      "vorauszahlungNKVorher": 180.0,
      "vorauszahlungNKGueltigAb": "YYYY-MM-DD",
      "kaltmieteEuro": 820.0,
      "kaltmieteVorher": 780.0,
      "kaltmieteGueltigAb": "YYYY-MM-DD",
      "abrechnungsturnus": "jaehrlich|halbjaehrlich|monatlich",
      "kaution": 1500.0,
      "dokumentDatum": "YYYY-MM-DD",
      "konfidenz": {
        "mieterName": 0.95,
        "vorauszahlungNKEuro": 0.7,
        "kaltmieteEuro": 0.85
      },
      "hinweise": ["z.B. 'Seite 2 unscharf'"]
    }

    Regeln:
    - Felder, die nicht im Dokument stehen: null.
    - Alle Euro- und Flaechen-Werte sind Zahlen, nicht Strings.
    - Bei schlechter Lesbarkeit: Konfidenz < 0.5 und ein passender Hinweis.
    - Bei Mieterhoehungsschreiben: extrahiere SOWOHL den alten als auch
      den neuen Betrag fuer Kaltmiete UND NK-Vorauszahlung, plus das
      Datum ab dem der neue Betrag gilt (*Vorher, *GueltigAb). Der alte
      Wert gehoert in *Vorher, der neue in *Euro — niemals umgekehrt.
    - „vorauszahlungNK*" bezieht sich ausschliesslich auf die
      Nebenkosten-Vorauszahlung; „kaltmiete*" ist die Netto-Kaltmiete
      ohne NK und ohne Heizkosten.
    - Nur JSON, kein Text drumherum, kein Markdown-Codeblock.
    """

    // MARK: - Mapping

    private struct ClaudeAntwort: Decodable {
        let dokumentTyp: String?
        let mieterName: String?
        let mieterAnschrift: String?
        let objektStrasse: String?
        let objektPlz: String?
        let objektStadt: String?
        let wohneinheit: String?
        let flaecheM2: Double?
        let einzugDatum: String?

        // NK-Vorauszahlung — optional mit alt/Gueltig-ab bei Erhoehung.
        let vorauszahlungNKEuro: Double?
        let vorauszahlungNKVorher: Double?
        let vorauszahlungNKGueltigAb: String?
        /// Alt-Feldname (Kompatibilitaet mit frueheren Prompts) —
        /// wird akzeptiert, falls Claude die alte Benennung zurueck-
        /// liefert.
        let vorauszahlungEuro: Double?

        // Kaltmiete — optional mit alt/Gueltig-ab bei Erhoehung.
        let kaltmieteEuro: Double?
        let kaltmieteVorher: Double?
        let kaltmieteGueltigAb: String?

        let abrechnungsturnus: String?
        let kaution: Double?
        let dokumentDatum: String?
        let konfidenz: [String: Double]?
        let hinweise: [String]?
    }

    private static func mappe(_ a: ClaudeAntwort) -> MietvertragsAnalyse {
        let kf = a.konfidenz ?? [:]

        func f<T>(_ wert: T?, _ key: String, default: Double = 0.5) -> FeldMitKonfidenz<T> where T: Equatable & Sendable {
            guard let wert else { return .leer }
            return .init(wert: wert, konfidenz: kf[key] ?? `default`)
        }
        func fDec(_ wert: Double?, _ key: String) -> FeldMitKonfidenz<Decimal> {
            guard let wert else { return .leer }
            return .init(
                wert: Decimal(wert),
                konfidenz: kf[key] ?? 0.5
            )
        }
        func fDate(_ s: String?, _ key: String) -> FeldMitKonfidenz<Date> {
            guard let s, let d = isoDatum(s) else { return .leer }
            return .init(wert: d, konfidenz: kf[key] ?? 0.5)
        }

        // VZ: neues Feld "vorauszahlungNKEuro" bevorzugt, Fallback auf
        // legacy "vorauszahlungEuro".
        let vzNeu = a.vorauszahlungNKEuro ?? a.vorauszahlungEuro
        let vzKey = a.vorauszahlungNKEuro != nil ? "vorauszahlungNKEuro" : "vorauszahlungEuro"

        let extraktion = MietvertragsExtraktion(
            adresse:                   f(a.objektStrasse,      "objektStrasse"),
            plz:                       f(a.objektPlz,          "objektPlz"),
            stadt:                     f(a.objektStadt,        "objektStadt"),
            gesamtflaecheM2:           fDec(a.flaecheM2,       "flaecheM2"),
            einheitBezeichnung:        f(a.wohneinheit,        "wohneinheit"),
            einheitFlaecheM2:          fDec(a.flaecheM2,       "flaecheM2"),
            mieterName:                f(a.mieterName,         "mieterName"),
            mieterAnschrift:           f(a.mieterAnschrift,    "mieterAnschrift"),
            einzugAm:                  fDate(a.einzugDatum,    "einzugDatum"),
            vorauszahlungMonatEuro:    fDec(vzNeu,                         vzKey),
            vorauszahlungVorherEuro:   fDec(a.vorauszahlungNKVorher,       "vorauszahlungNKVorher"),
            vorauszahlungGueltigAb:    fDate(a.vorauszahlungNKGueltigAb,   "vorauszahlungNKGueltigAb"),
            kaltmieteEuro:             fDec(a.kaltmieteEuro,               "kaltmieteEuro"),
            kaltmieteVorherEuro:       fDec(a.kaltmieteVorher,             "kaltmieteVorher"),
            kaltmieteGueltigAb:        fDate(a.kaltmieteGueltigAb,         "kaltmieteGueltigAb"),
            abrechnungsturnus:         f(a.abrechnungsturnus,  "abrechnungsturnus"),
            kaution:                   fDec(a.kaution,         "kaution"),
            besondereNKVereinbarungen: .leer
        )

        return .init(
            extraktion: extraktion,
            erkannterTyp: typVon(a.dokumentTyp),
            hinweise: a.hinweise ?? []
        )
    }

    private static func typVon(_ raw: String?) -> DokumentTyp {
        switch raw?.lowercased() {
        case "mietvertrag":             return .mietvertrag
        case "nachtrag":                return .mietvertragNachtrag
        case "erhoehung",
             "erhoehungsschreiben",
             "nk-erhoehung":            return .nkErhoehungsschreiben
        case "uebergabeprotokoll":      return .uebergabeprotokollEinzug
        default:                        return .unbekannt
        }
    }

    private static func isoDatum(_ s: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/Berlin")
        return f.date(from: s)
    }

}
