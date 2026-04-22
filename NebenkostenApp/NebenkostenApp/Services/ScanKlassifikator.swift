//
//  ScanKlassifikator.swift
//  NebenkostenApp — Services
//
//  Erkennt nach einem Universal-Scan den Dokumenttyp + extrahiert die
//  relevanten Felder. Zwei Pfade:
//
//  1. **Stub (Default).** Liefert `.unbekannt` + leere Felder — der
//     `UniversellerAnalyseScreen` fuehrt den User auf den manuellen
//     Typ-Picker. Schadet weder DSGVO noch Kosten, aber eben auch
//     keine Erkennung.
//
//  2. **Echter Claude-Call.** Nur aktiv, wenn der User in den Debug-
//     Einstellungen `Toggle Dev-Modus Claude-Klassifikation` gesetzt
//     hat (UserDefaults-Key `scan.klassifikation.debug.aktiv`). In
//     dem Fall:
//       - PDF wird via PDFKit in bis zu 3 JPEG-Seiten gerendert.
//       - `AnthropicClient.extrahiere(bilder:systemPrompt:userPrompt:)`
//         mit dem Klassifikations-Prompt.
//       - Response JSON-geparsed zu `ScanKlassifikationsErgebnis`.
//
//  Compliance-Hinweise (CLAUDE.md):
//    - Der Pfad ist explizit als **Dev-Modus** markiert und nicht
//      produktionsreif. API-Key laeuft ueber `AnthropicClient`
//      (UserDefaults/ENV, NICHT Cloudflare-Proxy) — fuer Produktion
//      MUSS der Worker-Proxy vorgeschaltet werden.
//    - PII-Schwaerzung fehlt. Der `UniversellerAnalyseScreen` zeigt
//      einen roten Banner, damit der User weiss, dass das volle
//      Dokument ungeschwaerzt an Anthropic geht.
//    - MieterhoehungSheet + Datenmodell existieren noch nicht — die
//      Felder werden im Analyse-Screen angezeigt, aber die
//      eigentliche Bearbeitung landet weiter im `ScanPlatzhalterSheet`.
//

import Foundation
import PDFKit
import UIKit
import OSLog

/// Logger fuer den Klassifikations-Flow. Filter in Xcode-Console via
/// `subsystem:de.nebenkosten category:scan.klassifikator`.
private let log = Logger(subsystem: "de.nebenkosten", category: "scan.klassifikator")

/// Ergebnis einer Scan-Klassifikation. `felder` ist ein Typ-unabhaengiges
/// Dictionary — der `UniversellerAnalyseScreen` rendert Schluessel und
/// Werte 1:1, ohne auf den Typ zu switchen.
struct ScanKlassifikationsErgebnis: Sendable {
    let typ: Dokumenttyp
    /// Konfidenz 0…1. Der Stub liefert 0, der echte Claude-Call fuellt
    /// diesen Wert aus der Response.
    let konfidenz: Double
    /// Typ-abhaengige Roh-Felder als Key/Value-Strings. Jeder Wert ist
    /// bereits als Anzeige-String formatiert.
    let felder: [String: String]
}

@MainActor
enum ScanKlassifikator {

    // MARK: - Feature-Flag

    /// UserDefaults-Key fuer den Debug-Toggle. Wird in
    /// `EinstellungenSheet` (Debug-Section) an-/abgeschaltet.
    static let debugFlagKey = "scan.klassifikation.debug.aktiv"

    /// Dev-Modus aktiv? Nur in diesem Modus geht ein Bild an Anthropic.
    static var devModusAktiv: Bool {
        UserDefaults.standard.bool(forKey: debugFlagKey)
    }

    // MARK: - Einstieg

    /// Klassifikations-Entry-Point. Je nach Flag + API-Key Stub oder
    /// echter Call. Wirft NIE — Fehler werden in ein leeres
    /// `.unbekannt`-Ergebnis gewandelt und vom Caller separat per
    /// `letzterFehler` abgefragt (sauberere UI-Darstellung als try/catch
    /// in der View).
    static func klassifiziere(
        dokument: GespeichertesDokument
    ) async -> ScanKlassifikationsErgebnis {
        letzterFehler = nil
        letzterPfad = .idle
        log.info("🔍 Klassifikation startet — dokumentID=\(dokument.id, privacy: .public)")
        log.info("🔀 devModusAktiv = \(devModusAktiv, privacy: .public)")
        log.info("🔑 apiKeyKonfiguriert = \(AnthropicClient.istKonfiguriert, privacy: .public)")
        guard devModusAktiv else {
            log.info("🧪 Pfad: Stub (devModus aus) — liefere .unbekannt")
            letzterPfad = .stub(grund: "Dev-Toggle ist aus")
            return ScanKlassifikationsErgebnis(
                typ: .unbekannt, konfidenz: 0, felder: [:]
            )
        }
        guard AnthropicClient.istKonfiguriert else {
            log.error("🔑 Kein API-Key — Abbruch")
            letzterFehler = "Kein API-Key hinterlegt (Einstellungen → KI-Extraktion)."
            letzterPfad = .stub(grund: "API-Key fehlt")
            return ScanKlassifikationsErgebnis(
                typ: .unbekannt, konfidenz: 0, felder: [:]
            )
        }
        do {
            log.info("📤 Pfad: Echt — sende an Anthropic …")
            let ergebnis = try await klassifiziereEcht(dokument: dokument)
            log.info("✅ Klassifikation OK: typ=\(ergebnis.typ.rawValue, privacy: .public) konfidenz=\(ergebnis.konfidenz, privacy: .public) felder=\(ergebnis.felder.count, privacy: .public)")
            letzterPfad = .echt(typ: ergebnis.typ, felderAnzahl: ergebnis.felder.count)
            return ergebnis
        } catch {
            log.error("💥 Klassifikations-Fehler: \(error.localizedDescription, privacy: .public)")
            letzterFehler = error.localizedDescription
            letzterPfad = .echtFehler(beschreibung: error.localizedDescription)
            return ScanKlassifikationsErgebnis(
                typ: .unbekannt, konfidenz: 0, felder: [:]
            )
        }
    }

    /// Ausfuehrlicher Pfad-State fuer die Diagnose-UI. Wird nach jedem
    /// `klassifiziere`-Call aktualisiert — die View liest ihn im
    /// `task` nach dem Await und zeigt ihn als Info-Card an.
    private(set) static var letzterPfad: LetzterPfad = .idle

    enum LetzterPfad: Sendable {
        case idle
        case stub(grund: String)
        case echt(typ: Dokumenttyp, felderAnzahl: Int)
        case echtFehler(beschreibung: String)
    }

    /// Letzter Klassifikationsfehler — fuer den UI-Banner. Wird vor
    /// jedem Call geleert.
    private(set) static var letzterFehler: String?

    // MARK: - Echter Call

    private static func klassifiziereEcht(
        dokument: GespeichertesDokument
    ) async throws -> ScanKlassifikationsErgebnis {
        let url = try DokumentAblageService.absoluterPfad(fuer: dokument.dateipfadRelativ)
        log.debug("📄 PDF: \(url.lastPathComponent, privacy: .public)")
        let bilder = try rendereSeitenAlsBilder(pdfURL: url, maxSeiten: 3)
        log.debug("🖼️ Seiten gerendert: \(bilder.count, privacy: .public)")
        let rohText = try await AnthropicClient.extrahiere(
            bilder: bilder,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            maxTokens: 1500
        )
        log.debug("📥 Response laenge=\(rohText.count, privacy: .public) chars")
        // Roh-Response privat loggen — hilft beim Debuggen, landet
        // aber nicht in Release-Logs (OSLog redaktion default).
        log.debug("📥 Response raw: \(rohText, privacy: .private)")
        return try parse(rohText)
    }

    // MARK: - PDF → UIImage

    /// Rendert die ersten `maxSeiten` Seiten einer PDF in UIImage.
    /// Zielgroesse: 1600 pt lange Kante (gutes Verhaeltnis aus
    /// Claude-Qualitaet und Base64-Payload). Wirft, wenn kein
    /// Dokument lesbar ist.
    private static func rendereSeitenAlsBilder(
        pdfURL: URL,
        maxSeiten: Int
    ) throws -> [UIImage] {
        guard let dokument = PDFDocument(url: pdfURL),
              dokument.pageCount > 0 else {
            throw Fehler.pdfNichtLesbar
        }
        var bilder: [UIImage] = []
        let anzahl = min(dokument.pageCount, maxSeiten)
        for i in 0..<anzahl {
            guard let seite = dokument.page(at: i) else { continue }
            let pdfRect = seite.bounds(for: .mediaBox)
            let zielKante: CGFloat = 1600
            let langeKante = max(pdfRect.width, pdfRect.height)
            let skala = langeKante > 0 ? zielKante / langeKante : 1
            let zielGroesse = CGSize(
                width: pdfRect.width * skala,
                height: pdfRect.height * skala
            )
            let renderer = UIGraphicsImageRenderer(size: zielGroesse)
            let img = renderer.image { ctx in
                UIColor.white.set()
                ctx.fill(CGRect(origin: .zero, size: zielGroesse))
                ctx.cgContext.translateBy(x: 0, y: zielGroesse.height)
                ctx.cgContext.scaleBy(x: skala, y: -skala)
                seite.draw(with: .mediaBox, to: ctx.cgContext)
            }
            bilder.append(img)
        }
        guard !bilder.isEmpty else { throw Fehler.pdfNichtLesbar }
        return bilder
    }

    // MARK: - Prompts

    private static let systemPrompt = """
    Du bist ein Assistent fuer die Klassifikation deutscher Vermieter-
    Dokumente. Antworte AUSSCHLIESSLICH mit einem gueltigen JSON-
    Objekt, keine Prosa, keine Markdown-Fences.
    Datumsfelder als ISO-8601 ("YYYY-MM-DD"). Geldbetraege ohne
    Waehrungssymbol als Zahl mit Dezimalpunkt (nicht Komma).
    Unbekannte oder nicht sicher lesbare Felder bleiben null.
    """

    private static let userPrompt = """
    Klassifiziere dieses Dokument nach einem der folgenden Typen und
    extrahiere die relevanten Felder:

    Typen:
    - "rechnung"            — Rechnung/Beleg eines Dienstleisters
    - "erhoehungsschreiben" — Miet- oder NK-Erhoehung
    - "mietvertrag"         — Mietvertrag
    - "hvAbrechnung"        — WEG-/Hausverwaltungs-Jahresabrechnung
    - "energieausweis"      — Energieausweis
    - "grundsteuerbescheid" — Grundsteuer-Bescheid
    - "zaehlerfoto"         — Foto eines Zaehler-Displays
    - "unbekannt"           — kein eindeutiger Typ

    Antwortformat (exakt dieses JSON-Schema, keine Prosa):
    {
      "typ": "<einer der Typen>",
      "konfidenz": 0.0,
      "felder": {
        "<feldname>": "<anzeigewert als String>"
      }
    }

    Relevante Felder je Typ (Empfehlung, nicht Pflicht):
    - rechnung:            absender, datum, leistungszeitraum, betrag, iban, kundennummer
    - erhoehungsschreiben: absender, empfaenger, datum, kaltmieteAlt, kaltmieteNeu,
                           nkVorauszahlungAlt, nkVorauszahlungNeu, gueltigAb, objektAdresse
    - mietvertrag:         vermieter, mieter, objektAdresse, einzugAm, kaltmieteEuro,
                           nkVorauszahlungEuro, flaecheM2, zimmer
    - hvAbrechnung:        verwalter, zeitraum, meaAnteil, gesamtkosten, umlagefaehigGesamt,
                           eigentuemerGesamt, lohnanteil35a
    - energieausweis:      ausstellungsdatum, gueltigBis, energieklasse, endenergiebedarf
    - grundsteuerbescheid: amt, aktenzeichen, datum, jahresbetrag
    - zaehlerfoto:         zaehlerart, standWert, einheit

    Konfidenz: geschaetzte Wahrscheinlichkeit 0.0…1.0, dass der Typ stimmt.
    Feldwerte als kurze, menschenlesbare Strings. Waehrungen als Zahl + ' €'
    (z.B. "660.00 €"), Datumsangaben als "TT.MM.JJJJ".
    """

    // MARK: - Response-Parser

    private static func parse(_ rohText: String) throws -> ScanKlassifikationsErgebnis {
        guard let daten = rohText.data(using: .utf8) else {
            throw Fehler.responseUnlesbar("Kein UTF-8")
        }
        guard let obj = try? JSONSerialization.jsonObject(with: daten) as? [String: Any] else {
            throw Fehler.responseUnlesbar("Kein JSON-Objekt")
        }
        guard let typString = obj["typ"] as? String,
              let typ = Dokumenttyp(rawValue: typString) else {
            throw Fehler.responseUnlesbar("Typ fehlt oder unbekannt: \(obj["typ"] ?? "nil")")
        }
        let konfidenz = (obj["konfidenz"] as? Double) ?? 0
        var felder: [String: String] = [:]
        if let roh = obj["felder"] as? [String: Any] {
            for (key, value) in roh {
                if let s = value as? String, !s.isEmpty {
                    felder[key] = s
                } else if let n = value as? NSNumber {
                    felder[key] = n.stringValue
                }
                // null-Werte werden weggelassen — die UI zeigt
                // dann schlicht weniger Zeilen, statt "—".
            }
        }
        return ScanKlassifikationsErgebnis(
            typ: typ, konfidenz: konfidenz, felder: felder
        )
    }

    // MARK: - Fehler

    enum Fehler: Error, LocalizedError {
        case pdfNichtLesbar
        case responseUnlesbar(String)

        var errorDescription: String? {
            switch self {
            case .pdfNichtLesbar:
                return "PDF konnte nicht gerendert werden."
            case .responseUnlesbar(let d):
                return "Antwort nicht parsebar: \(d)"
            }
        }
    }
}
