//
//  ScanKlassifikator.swift
//  NebenkostenApp — Services
//
//  Erkennt nach einem Universal-Scan den Dokumenttyp + extrahiert die
//  relevanten Felder. Aktuell **Stub** — echte Claude-Klassifikation
//  folgt, wenn der Cloudflare-Worker-Proxy produktiv ist (CLAUDE.md
//  Phase 1).
//
//  Der Stub trifft bewusst KEINE Typ-Vermutung (Ergebnis: `.unbekannt`).
//  Damit sieht der User im `UniversellerAnalyseScreen` den User-Picker
//  — identisch zum spaeteren „Typ nicht erkannt"-Fallback der echten
//  Klassifikation. So kann der Call-Pfad bereits jetzt verdrahtet und
//  in den Sub-Flows durchgetestet werden, ohne spekulative Heuristik.
//
//  Das Klassifikations-API-Shape ist bewusst async + throws, damit der
//  echte Claude-Call spaeter ohne Call-Site-Aenderung einspringen kann.
//

import Foundation

/// Ergebnis einer Scan-Klassifikation. `felder` ist ein Typ-unabhaengiges
/// Dictionary, der `UniversellerAnalyseScreen` bereitet die passenden
/// Felder pro Typ auf.
struct ScanKlassifikationsErgebnis: Sendable {
    let typ: Dokumenttyp
    /// Konfidenz 0…1. Der Stub liefert 0, der echte Claude-Call fuellt
    /// diesen Wert spaeter aus der Response.
    let konfidenz: Double
    /// Typ-abhaengige Roh-Felder als Key/Value-Strings. Jeder Wert ist
    /// bereits als Anzeige-String formatiert — `UniversellerAnalyse
    /// Screen` rendert sie 1:1.
    let felder: [String: String]
}

@MainActor
enum ScanKlassifikator {

    /// Stub-Klassifikation. Liefert `.unbekannt` mit leeren Feldern —
    /// die UI faellt auf den User-Picker zurueck. Async, damit die
    /// Signatur stabil bleibt, wenn der echte Claude-Call folgt.
    static func klassifiziere(
        dokument: GespeichertesDokument
    ) async -> ScanKlassifikationsErgebnis {
        ScanKlassifikationsErgebnis(
            typ: .unbekannt,
            konfidenz: 0,
            felder: [:]
        )
    }
}
