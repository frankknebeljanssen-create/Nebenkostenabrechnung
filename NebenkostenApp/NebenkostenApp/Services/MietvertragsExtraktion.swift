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
    /// Nur gefuellt, wenn `erkannterTyp == .hvAbrechnung`. Enthaelt
    /// die strukturierte Rohdaten-Extraktion der HV-Abrechnung
    /// (wird vom HVAnalyseBefundView gerendert und vom
    /// Uebernahme-Flow in SwiftData-Entities uebersetzt).
    var hvDaten: HVAbrechnungsRohdaten?
}

// MARK: - HV-Abrechnungs-Rohdaten (Transport)

/// Reine Transport-Structs — keine @Model-Klassen. Werden beim
/// „So uebernehmen"-Flow in `HVAbrechnung` + `HVPosition` +
/// `HVEigentuemerKosten` uebersetzt.
struct HVAbrechnungsRohdaten: Equatable, Sendable {
    var hausverwaltungName: String
    var hausverwaltungAdresse: String
    var wegName: String
    var gebaeudeAdresse: String
    var meaAnteil: Int
    var meaGesamt: Int
    var abrechnungszeitraumVon: Date?
    var abrechnungszeitraumBis: Date?
    var abrechnungsspitzeEuro: Decimal
    var vorauszahlungenEuro: Decimal
    var erhaltungsruecklageAnteilEuro: Decimal
    var paragraph35aHandwerkerEuro: Decimal
    var paragraph35aHaushaltsnahEuro: Decimal
    var umlagefaehigePositionen: [HVPositionRohdaten]
    var eigentuemerKosten: [HVEigentuemerKostenRohdaten]
}

struct HVPositionRohdaten: Equatable, Sendable, Identifiable {
    let id: UUID = UUID()
    var bezeichnung: String
    var kontierung: String
    var gesamtkostenGebaeude: Decimal
    var anteilEuro: Decimal
    /// Claudes Mapping-Vorschlag (z.B. „Wasser", „Müll"). Der User
    /// kann das beim Uebernehmen korrigieren.
    var betrkvKostenart: String
}

struct HVEigentuemerKostenRohdaten: Equatable, Sendable, Identifiable {
    let id: UUID = UUID()
    var bezeichnung: String
    var kontierung: String
    var anteilEuro: Decimal
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

    /// System-Prompt: Rolle + Antwort-Format. Deckt Mietdokumente
    /// UND HV-Einzelabrechnungen (WEG) ab. Claude setzt zuerst
    /// `dokumentTyp`, dann die passenden Felder je Typ.
    private static let systemPrompt = """
    Du bist ein Assistent für die Extraktion von Feldern aus deutschen
    Immobilien-Dokumenten — Mietdokumenten (Mietvertrag, Mietvertrags-
    Nachtrag, NK-Erhöhungsschreiben, Übergabeprotokoll) UND
    Hausverwaltungs-Einzelabrechnungen (WEG-Einzelabrechnung für
    Eigentümer). Antworte AUSSCHLIESSLICH mit einem gültigen
    JSON-Objekt, keine Prosa, kein Markdown. Datumsfelder im Format
    "YYYY-MM-DD". Felder, die du nicht erkennst, sind null. Pro
    gefuelltem Top-Level-Feld gib zusätzlich eine Konfidenz 0…1 in
    konfidenz[FELDNAME] an.
    """

    /// User-Prompt mit konkretem JSON-Schema. Gemeinsamer Wrapper
    /// fuer alle unterstuetzten Dokument-Typen (Variante A —
    /// Ein-Prompt-Mehrzweck).
    private static let userPrompt = """
    Analysiere das beigefuegte deutsche Dokument. Es kann ein
    Mietdokument oder eine Hausverwaltungs-Abrechnung sein. Entscheide
    zuerst anhand des Inhalts den Typ und fuelle dann die passenden
    Felder. Lass Felder, die fuer den gewaehlten Typ nicht passen,
    null.

    HAUSVERWALTUNGS-ABRECHNUNG erkennst du an:
    - Absender ist eine Hausverwaltung / Verwaltungsgesellschaft
    - „Eigentuemergemeinschaft", „WEG", „Hausgeld"
    - MEA-Umlageschluessel (z.B. 21297/1000000 oder Prozentsatz)
    - Abschnitte „umlagefaehig" / „nicht umlagefaehig"

    Gib ausschliesslich folgendes JSON zurueck:
    {
      "dokumentTyp": "mietvertrag|nachtrag|erhoehungsschreiben|uebergabeprotokoll|hvAbrechnung|sonstiges",

      // ----- FELDER FUER MIETDOKUMENTE -----
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

      // ----- FELDER FUER HV-ABRECHNUNG -----
      "hausverwaltungName": "...",
      "hausverwaltungAdresse": "...",
      "wegName": "...",
      "gebaeudeAdresse": "...",
      "meaAnteil": 21297,
      "meaGesamt": 1000000,
      "abrechnungszeitraumVon": "YYYY-MM-DD",
      "abrechnungszeitraumBis": "YYYY-MM-DD",
      "abrechnungsspitzeEuro": -227.44,
      "vorauszahlungenEuro": 4020.00,
      "erhaltungsruecklageAnteilEuro": 638.92,
      "paragraph35aHandwerkerEuro": 405.45,
      "paragraph35aHaushaltsnahEuro": 109.60,
      "umlagefaehigePositionen": [
        {
          "bezeichnung": "Wasserversorgung",
          "kontierung": "804000000",
          "gesamtkostenGebaeude": 13459.78,
          "anteilEuro": 286.55,
          "betrkvKostenart": "Wasser"
        }
      ],
      "eigentuemerKosten": [
        {
          "bezeichnung": "Verwaltervergütung",
          "kontierung": "809000000",
          "anteilEuro": 314.16
        }
      ],

      "konfidenz": {
        "mieterName": 0.95,
        "meaAnteil": 0.99,
        "abrechnungsspitzeEuro": 0.9
      },
      "hinweise": ["z.B. 'Seite 2 unscharf'"]
    }

    Regeln — allgemein:
    - Felder, die nicht im Dokument stehen: null.
    - Alle Euro- und Flaechen-Werte sind Zahlen, nicht Strings.
    - Bei schlechter Lesbarkeit: Konfidenz < 0.5 und passenden Hinweis.
    - Nur JSON, kein Text drumherum, kein Markdown-Codeblock.

    Regeln — Mietdokumente:
    - Bei Mieterhoehungsschreiben: SOWOHL alter als auch neuer Betrag
      fuer Kaltmiete UND NK-Vorauszahlung + Datum ab dem der neue
      Betrag gilt (*Vorher, *GueltigAb). Alter Wert in *Vorher, neuer
      in *Euro — niemals umgekehrt.
    - „vorauszahlungNK*" = NK-Vorauszahlung; „kaltmiete*" = Netto-
      Kaltmiete ohne NK und ohne Heizkosten.

    Regeln — HV-Abrechnung:
    - `umlagefaehigePositionen` enthaelt ausschliesslich Posten aus
      dem Abschnitt „umlagefaehige Betriebskosten" (auf Mieter
      uebertragbar).
    - `eigentuemerKosten` enthaelt ausschliesslich Posten aus
      „nicht umlagefaehige Kosten" (Eigentuemer-Anteil, nie auf
      Mieter uebertragbar).
    - `erhaltungsruecklageAnteilEuro` ist KEIN Posten in den beiden
      Listen, sondern ein eigenes Feld.
    - `abrechnungsspitzeEuro`: NEGATIV = Guthaben fuer den Eigentuemer,
      POSITIV = Nachzahlung an die Hausverwaltung.
    - `meaAnteil` und `meaGesamt` sind ganze Zahlen. Bei Prozent-
      angabe (z.B. „2,1297 %") rechne in ppm: meaAnteil=21297,
      meaGesamt=1000000.
    - Jede Position braucht `betrkvKostenart` — ein Stichwort aus
      dem BetrKV-Katalog (z.B. „Wasser", „Muell", „Grundsteuer",
      „Gartenpflege", „Hauswart", „Allgemeinstrom") — als
      Mapping-Vorschlag. Wenn unklar: „Sonstige".
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

        // MARK: HV-Abrechnung (Variante A — gleicher JSON-Wrapper)

        let hausverwaltungName: String?
        let hausverwaltungAdresse: String?
        let wegName: String?
        let gebaeudeAdresse: String?
        let meaAnteil: Int?
        let meaGesamt: Int?
        let abrechnungszeitraumVon: String?
        let abrechnungszeitraumBis: String?
        let abrechnungsspitzeEuro: Double?
        let vorauszahlungenEuro: Double?
        let erhaltungsruecklageAnteilEuro: Double?
        let paragraph35aHandwerkerEuro: Double?
        let paragraph35aHaushaltsnahEuro: Double?
        let umlagefaehigePositionen: [HVPositionRoh]?
        let eigentuemerKosten: [HVEigentuemerKostenRoh]?
    }

    private struct HVPositionRoh: Decodable {
        let bezeichnung: String?
        let kontierung: String?
        let gesamtkostenGebaeude: Double?
        let anteilEuro: Double?
        let betrkvKostenart: String?
        /// Alt-Feldname-Fallback (fruehere Prompt-Version).
        let betrkvZuordnung: String?
    }

    private struct HVEigentuemerKostenRoh: Decodable {
        let bezeichnung: String?
        let kontierung: String?
        let anteilEuro: Double?
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

        let typ = typVon(a.dokumentTyp)
        let hvDaten: HVAbrechnungsRohdaten? = {
            guard typ == .hvAbrechnung else { return nil }
            return .init(
                hausverwaltungName:            a.hausverwaltungName ?? "",
                hausverwaltungAdresse:         a.hausverwaltungAdresse ?? "",
                wegName:                       a.wegName ?? "",
                gebaeudeAdresse:               a.gebaeudeAdresse ?? "",
                meaAnteil:                     a.meaAnteil ?? 0,
                meaGesamt:                     a.meaGesamt ?? 1,
                abrechnungszeitraumVon:        isoDatum(a.abrechnungszeitraumVon ?? ""),
                abrechnungszeitraumBis:        isoDatum(a.abrechnungszeitraumBis ?? ""),
                abrechnungsspitzeEuro:         decimal(a.abrechnungsspitzeEuro),
                vorauszahlungenEuro:           decimal(a.vorauszahlungenEuro),
                erhaltungsruecklageAnteilEuro: decimal(a.erhaltungsruecklageAnteilEuro),
                paragraph35aHandwerkerEuro:    decimal(a.paragraph35aHandwerkerEuro),
                paragraph35aHaushaltsnahEuro:  decimal(a.paragraph35aHaushaltsnahEuro),
                umlagefaehigePositionen:       (a.umlagefaehigePositionen ?? []).map {
                    HVPositionRohdaten(
                        bezeichnung:           $0.bezeichnung ?? "",
                        kontierung:            $0.kontierung ?? "",
                        gesamtkostenGebaeude:  decimal($0.gesamtkostenGebaeude),
                        anteilEuro:            decimal($0.anteilEuro),
                        betrkvKostenart:       $0.betrkvKostenart ?? $0.betrkvZuordnung ?? ""
                    )
                },
                eigentuemerKosten:             (a.eigentuemerKosten ?? []).map {
                    HVEigentuemerKostenRohdaten(
                        bezeichnung: $0.bezeichnung ?? "",
                        kontierung:  $0.kontierung ?? "",
                        anteilEuro:  decimal($0.anteilEuro)
                    )
                }
            )
        }()

        return .init(
            extraktion: extraktion,
            erkannterTyp: typ,
            hinweise: a.hinweise ?? [],
            hvDaten: hvDaten
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
        case "hvabrechnung",
             "hv-abrechnung",
             "hausverwaltungsabrechnung",
             "wegabrechnung",
             "weg-abrechnung":          return .hvAbrechnung
        default:                        return .unbekannt
        }
    }

    private static func decimal(_ d: Double?) -> Decimal {
        guard let d else { return 0 }
        return Decimal(d)
    }

    private static func isoDatum(_ s: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Europe/Berlin")
        return f.date(from: s)
    }

}
