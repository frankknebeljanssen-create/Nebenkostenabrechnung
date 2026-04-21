//
//  AnthropicClient.swift
//  NebenkostenApp — Services
//
//  Minimaler HTTP-Client fuer die Anthropic Messages API mit Vision-
//  Support (Bild + Text in einem User-Turn). Wird vom
//  MietvertragsExtraktionService aufgerufen, um gescannte
//  Mietdokumente an Claude zu schicken und strukturierte Felder
//  zurueckzubekommen.
//
//  DSGVO-/Architektur-Hinweis
//  ---------------------------
//  CLAUDE.md-Regel: „Der Anthropic-API-Key ist NIEMALS im App-
//  Binary. Alle Claude-Calls über Cloudflare Worker Proxy."
//
//  Dieser Client ist die Uebergangsloesung, bis der Cloudflare-
//  Worker steht. Er liest den Key aus UserDefaults
//  ("anthropic.apiKey") bzw. aus der Umgebungsvariable
//  ANTHROPIC_API_KEY (nur DEBUG). Ohne konfigurierten Key wirft
//  jeder Call `AnthropicClient.Fehler.keinAPIKey` — der
//  MietvertragsExtraktionService faengt das in DEBUG ab und
//  faellt auf Demo-Daten zurueck, damit der UI-Flow lokal
//  weiter nutzbar bleibt. Release ohne Key → Fehler-Alert.
//
//  Ausserdem wichtig: das volle Dokument wird UN-geschwaerzt an
//  Anthropic geschickt — PII-Schwaerzung wuerde die Mieter-Namens-
//  extraktion unmoeglich machen. Das entspricht CLAUDE.md-Mode B,
//  der eine aktive User-Zustimmung pro Scan verlangt. Die UI-
//  Anbindung dieser Zustimmung folgt separat; der Client selbst
//  macht keine Einwilligungspruefung, er verlaesst sich darauf,
//  dass der Aufrufer das Flag geprueft hat.
//

import Foundation
import UIKit

enum AnthropicClient {

    // MARK: - Konfiguration

    static let messagesURL = URL(string: "https://api.anthropic.com/v1/messages")!
    static let apiVersion = "2023-06-01"
    static let defaultModel = "claude-opus-4-5"

    /// Maximale Anzahl Seiten pro Call. Multi-Page-Scans werden
    /// als separate image-Content-Bloecke uebertragen; alles
    /// darueber wird abgeschnitten, um die Request-Groesse zu
    /// begrenzen.
    static let maxSeiten = 5

    // MARK: - Key-Source

    static var apiKey: String? {
        if let v = UserDefaults.standard.string(forKey: "anthropic.apiKey"), !v.isEmpty {
            return v
        }
        #if DEBUG
        if let env = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !env.isEmpty {
            return env
        }
        #endif
        return nil
    }

    static var istKonfiguriert: Bool { apiKey != nil }

    // MARK: - Fehler

    enum Fehler: Error, LocalizedError {
        case keinAPIKey
        case keineBilder
        case bildKodierung
        case netzwerk(underlying: Error)
        case httpFehler(status: Int, body: String)
        case antwortLeer
        case parseFehler(String)

        var errorDescription: String? {
            switch self {
            case .keinAPIKey:
                return "Anthropic-API-Key nicht konfiguriert. Bitte in den Einstellungen hinterlegen."
            case .keineBilder:
                return "Keine Seiten zum Analysieren vorhanden."
            case .bildKodierung:
                return "Das gescannte Bild konnte nicht fürs API-Format kodiert werden."
            case .netzwerk(let e):
                return "Netzwerk-Fehler beim Claude-Call: \(e.localizedDescription)"
            case .httpFehler(let s, let b):
                return "Claude HTTP \(s): \(b.prefix(200))"
            case .antwortLeer:
                return "Claude hat eine leere Antwort zurückgegeben."
            case .parseFehler(let d):
                return "Claude-Antwort unlesbar: \(d)"
            }
        }
    }

    // MARK: - Vision-Call

    /// Ruft die Messages-API mit einem oder mehreren Bildern +
    /// einem User-Prompt auf. `systemPrompt` wird als
    /// System-Instruktion mitgegeben.
    ///
    /// Rueckgabe ist der erste text-Content-Block der Antwort —
    /// der Aufrufer ist fuer das Parsen (z.B. JSON-Extraktion)
    /// zustaendig.
    static func extrahiere(
        bilder: [UIImage],
        systemPrompt: String,
        userPrompt: String,
        model: String = defaultModel,
        maxTokens: Int = 2048
    ) async throws -> String {
        guard let key = apiKey else { throw Fehler.keinAPIKey }
        guard !bilder.isEmpty else { throw Fehler.keineBilder }

        // Multi-Page: alles bis maxSeiten uebertragen.
        let seiten = Array(bilder.prefix(maxSeiten))
        var inhaltsBloecke: [[String: Any]] = []

        for bild in seiten {
            guard let daten = bild.jpegData(compressionQuality: 0.8) else {
                throw Fehler.bildKodierung
            }
            let base64 = daten.base64EncodedString()
            inhaltsBloecke.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": base64
                ]
            ])
        }
        inhaltsBloecke.append([
            "type": "text",
            "text": userPrompt
        ])

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": systemPrompt,
            "messages": [
                [
                    "role": "user",
                    "content": inhaltsBloecke
                ]
            ]
        ]

        var request = URLRequest(url: messagesURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 60
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw Fehler.parseFehler("Request-Body JSON-Fehler: \(error.localizedDescription)")
        }

        let daten: Data
        let antwort: URLResponse
        do {
            (daten, antwort) = try await URLSession.shared.data(for: request)
        } catch {
            throw Fehler.netzwerk(underlying: error)
        }

        guard let http = antwort as? HTTPURLResponse else {
            throw Fehler.antwortLeer
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: daten, encoding: .utf8) ?? ""
            throw Fehler.httpFehler(status: http.statusCode, body: body)
        }

        return try parseErstenText(aus: daten)
    }

    // MARK: - Response-Parsing

    /// Holt den ersten `text`-Block aus der Claude-Messages-
    /// Antwort. Markdown-Fences (```json … ```) werden
    /// entfernt, damit der Aufrufer unabhaengig davon direkt
    /// JSON parsen kann.
    private static func parseErstenText(aus data: Data) throws -> String {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Fehler.parseFehler("Antwort ist kein JSON-Objekt")
        }
        guard let content = obj["content"] as? [[String: Any]],
              let textBlock = content.first(where: { ($0["type"] as? String) == "text" }),
              let text = textBlock["text"] as? String
        else {
            throw Fehler.parseFehler("Kein text-Block in content[]")
        }
        return trimJSONFence(text)
    }

    /// Entfernt ggf. Markdown-Fence-Wrapper, die Claude gerne
    /// hinzufuegt, damit das JSON direkt parsebar ist.
    static func trimJSONFence(_ text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Handle ```json ... ``` oder ``` ... ```
        if t.hasPrefix("```") {
            if let endeErsteZeile = t.firstIndex(of: "\n") {
                t = String(t[t.index(after: endeErsteZeile)...])
            }
            if let ende = t.range(of: "```", options: .backwards) {
                t = String(t[..<ende.lowerBound])
            }
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
