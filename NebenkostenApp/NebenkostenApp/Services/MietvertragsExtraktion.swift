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
//  Fallback im DEBUG-Build
//  -----------------------
//  Wenn kein API-Key konfiguriert ist (weder UserDefaults noch
//  ANTHROPIC_API_KEY-ENV gesetzt), faellt der Service in DEBUG-
//  Builds auf deterministische Demo-Daten zurueck, damit der
//  UI-Flow ohne Netzwerk testbar bleibt. In RELEASE-Builds wird
//  ein `Fehler.keinAPIKey` geworfen — Mock-Daten duerfen
//  niemals im produktiven Pfad landen.
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

    var vorauszahlungMonatEuro: FeldMitKonfidenz<Decimal>
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

        // Fallback-Logik: ohne API-Key in DEBUG auf Demo-Daten.
        guard AnthropicClient.istKonfiguriert else {
            #if DEBUG
            print("[MietvertragsExtraktion] Kein API-Key — fallback auf Demo-Daten (DEBUG-only).")
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            return .init(
                extraktion: demoExtraktion,
                erkannterTyp: .mietvertrag,
                hinweise: ["Demo-Daten — kein echter API-Call (kein API-Key gesetzt)"]
            )
            #else
            throw Fehler.keinAPIKey
            #endif
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
      "dokumentTyp": "mietvertrag|nachtrag|erhoehung|uebergabeprotokoll|sonstiges",
      "mieterName": "...",
      "mieterAnschrift": "...",
      "objektStrasse": "...",
      "objektPlz": "...",
      "objektStadt": "...",
      "wohneinheit": "EG|OG|KG|<freier Text>",
      "flaecheM2": 187.5,
      "einzugDatum": "YYYY-MM-DD",
      "vorauszahlungEuro": 260.0,
      "abrechnungsturnus": "jaehrlich|halbjaehrlich|monatlich",
      "kaution": 1500.0,
      "dokumentDatum": "YYYY-MM-DD",
      "konfidenz": {
        "mieterName": 0.95,
        "vorauszahlungEuro": 0.7
      },
      "hinweise": ["z.B. 'Seite 2 unscharf'"]
    }

    Regeln:
    - Felder, die nicht im Dokument stehen: null.
    - "flaecheM2", "vorauszahlungEuro", "kaution" sind Zahlen, nicht Strings.
    - Bei schlechter Lesbarkeit: Konfidenz < 0.5 und ein passender Hinweis.
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
        let vorauszahlungEuro: Double?
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
            vorauszahlungMonatEuro:    fDec(a.vorauszahlungEuro, "vorauszahlungEuro"),
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

    // MARK: - Demo-Daten (nur DEBUG)

    #if DEBUG
    /// Deterministische Demo-Extraktion fuer den UI-Flow ohne
    /// konfigurierten API-Key. Liegt bewusst hinter `#if DEBUG`,
    /// damit in Release-Builds keine Fake-Namen im Binary sind.
    private static var demoExtraktion: MietvertragsExtraktion {
        let kal = Calendar(identifier: .gregorian)
        let einzug = kal.date(from: DateComponents(year: 2024, month: 3, day: 1)) ?? Date()
        return MietvertragsExtraktion(
            adresse:                   .init(wert: "Am Dorfteich 4",            konfidenz: 0.93),
            plz:                       .init(wert: "16818",                     konfidenz: 0.95),
            stadt:                     .init(wert: "Schmachtenhagen",           konfidenz: 0.91),
            gesamtflaecheM2:           .init(wert: 65,                          konfidenz: 0.74),
            einheitBezeichnung:        .init(wert: "Datsche",                   konfidenz: 0.62),
            einheitFlaecheM2:          .init(wert: 65,                          konfidenz: 0.74),
            mieterName:                .init(wert: "Hans Beispielmieter",       konfidenz: 0.88),
            mieterAnschrift:           .init(wert: "Musterweg 12, 10115 Berlin", konfidenz: 0.71),
            einzugAm:                  .init(wert: einzug,                      konfidenz: 0.84),
            vorauszahlungMonatEuro:    .init(wert: 120,                         konfidenz: 0.79),
            abrechnungsturnus:         .init(wert: "jährlich",                  konfidenz: 0.46),
            kaution:                   .init(wert: 900,                         konfidenz: 0.38),
            besondereNKVereinbarungen: .leer
        )
    }
    #endif
}
