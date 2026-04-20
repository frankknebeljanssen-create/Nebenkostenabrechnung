//
//  AIExtraktionService.swift
//  NebenkostenApp — Services
//
//  Service-Interface für die Ebene-2-Extraktion (AIVorschlag) aus
//  OCR-Volltext. Die eigentliche AI-Anbindung (Cloudflare Worker +
//  Claude API) ist NICHT Teil von Task 1.2 — dieser Service ist ein
//  lokaler Stub, der:
//
//    1. den typ-spezifischen Prompt wählt (AIPrompts, Task 1.2-C4)
//    2. PII-Schwärzung anwendet (PIISchwaerzung, Task 1.2-C5)
//    3. einen (leeren) AIVorschlag mit Versorger-Hint zurückgibt
//       bzw. per Codable aus einer Dummy-JSON rekonstruiert.
//
//  Der Stub loggt den Prompt und den geschwärzten Text nur in DEBUG,
//  damit man die Pipeline lokal prüfen kann, ohne Netzwerk-Traffic.
//

import Foundation

enum AIExtraktionsFehler: Error, LocalizedError {
    case parseFehler(underlying: Error?)
    case netzwerk(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .parseFehler(let u):
            return "AI-Antwort konnte nicht geparst werden: "
                + "\(u?.localizedDescription ?? "unbekannter Fehler")"
        case .netzwerk(let u):
            return "Netzwerk-Fehler: \(u.localizedDescription)"
        }
    }
}

/// Typ-freies JSON-Datenmodell für die Worker-Antwort. Wird in
/// `AIVorschlag` gemappt — bewusst als Struct, nicht als Entity,
/// damit der Parse-Schritt frei von SwiftData-Kontext ist.
struct AIVorschlagJSON: Codable, Sendable, Equatable {
    var dokumentDatum: Date?
    var versorger: String?
    var betragBrutto: Decimal?
    var mwstSatz: Decimal?
    var rechnungsNr: String?
    var leistungszeitraumStart: Date?
    var leistungszeitraumEnde: Date?
    var kostenartVorschlag: String?
    var positionenJSON: String?
    /// Dict: Feldname → Konfidenz 0…1.
    var konfidenzJeFeld: [String: Double]?
}

enum AIExtraktionService {

    /// Stub-Implementation. Wählt typ-spezifischen Prompt (kommt
    /// C4), wendet PII-Schwärzung an (kommt C5), loggt in DEBUG und
    /// gibt einen leeren AIVorschlag mit übergebenem Versorger-Hint
    /// zurück. Wird in einem späteren Release durch den echten
    /// Cloudflare-Worker-Call ersetzt.
    static func extrahiere(
        ocrText: String,
        typ: Dokumenttyp,
        versorgerHint: String?
    ) async throws -> AIVorschlagJSON {
        let prompt = AIPrompts.fuer(typ: typ)
        let geschwaerzt = PIISchwaerzung.apply(text: ocrText, kontext: .leer)

        #if DEBUG
        print("""
        [AIExtraktion-Stub]
          typ: \(typ)
          prompt: \(prompt.prefix(60))…
          ocrLen: \(geschwaerzt.count)
        """)
        #endif

        var vorschlag = AIVorschlagJSON()
        vorschlag.versorger = versorgerHint
        return vorschlag
    }

    // MARK: - Parsing

    /// Parst einen Claude-Response-JSON in ein AIVorschlagJSON.
    /// Bei Parse-Fehler → leeres AIVorschlagJSON (kein Crash), damit
    /// die UI trotzdem weiterläuft. Fehler werden optional via
    /// `onParseFehler` nach außen gereicht.
    static func parseWorkerAntwort(
        data: Data,
        onParseFehler: ((Error) -> Void)? = nil
    ) -> AIVorschlagJSON {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(AIVorschlagJSON.self, from: data)
        } catch {
            onParseFehler?(error)
            return AIVorschlagJSON()
        }
    }

    // MARK: - Mapping JSON → @Model

    /// Kopiert die Felder aus dem Codable-Struct in die @Model-
    /// Entity. Konfidenz-Dict wird als JSON-Data serialisiert.
    @MainActor
    static func uebertrage(
        _ json: AIVorschlagJSON,
        nach entity: AIVorschlag
    ) {
        entity.dokumentDatum = json.dokumentDatum
        entity.versorger = json.versorger
        entity.betragBrutto = json.betragBrutto
        entity.mwstSatz = json.mwstSatz
        entity.rechnungsNr = json.rechnungsNr
        entity.leistungszeitraumStart = json.leistungszeitraumStart
        entity.leistungszeitraumEnde = json.leistungszeitraumEnde
        entity.kostenartVorschlag = json.kostenartVorschlag
        entity.positionenJSON = json.positionenJSON
        if let conf = json.konfidenzJeFeld {
            entity.konfidenzJeFeld = try? JSONEncoder().encode(conf)
        } else {
            entity.konfidenzJeFeld = nil
        }
    }

    /// Liest das Konfidenz-Dict zurück aus der Entity.
    static func konfidenzen(aus entity: AIVorschlag) -> [String: Double] {
        guard let data = entity.konfidenzJeFeld else { return [:] }
        return (try? JSONDecoder().decode([String: Double].self, from: data)) ?? [:]
    }
}

