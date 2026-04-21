//
//  MietvertragsExtraktion.swift
//  NebenkostenApp — Services
//
//  Datentypen + Stub-Service fuer die Mietvertrags-KI-Extraktion.
//  Eingangs-Pfad: scanned PDF/Image → OCR → Claude via Proxy →
//  `MietvertragsExtraktion` mit Feldern + Konfidenzen. Die UI
//  (NeuesObjektSheet) rendert die Vorschau mit Ampel-Punkten pro
//  Feld und laesst den User jeden Wert ueberschreiben.
//
//  Status: STUB. Der Service liefert deterministische Dummy-Daten
//  nach einer kuerzen simulierten Verzoegerung, damit der komplette
//  UI-Flow ohne laufendes Backend entwickelt werden kann. Die echte
//  Anbindung an Claude (inkl. PII-Schwaerzung und typ-spezifischem
//  Prompt) kommt in einem Folge-Commit, dann mit CloudflareProxy-
//  URL und ggf. Fallback auf Foundation Models. Der Prompt-Name
//  „mietvertrag" ist in `AIPrompts.fuer(typ:)` aktuell auf
//  `fallback` gemapped — dort in M2 einen dedizierten Prompt
//  ergaenzen.
//
//  DSGVO-Hinweis (fuer M2): vor jedem Claude-Call muessen Mieter-
//  Namen, Adressen, Telefon, E-Mail, IBAN geschwaerzt werden
//  (siehe PIISchwaerzung.swift). Der Stub hier greift nicht auf
//  echte Daten zu und ist deshalb privacy-neutral.
//

import Foundation
import UIKit

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

    /// Ampel-Kategorie fuer die UI.
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

/// Strukturiertes Extraktionsergebnis eines Mietvertrags. Alle
/// Felder sind optional; was der KI nicht klar war, bleibt `nil`
/// mit Konfidenz 0.
struct MietvertragsExtraktion: Equatable, Sendable {
    // Objekt-Ebene
    var adresse: FeldMitKonfidenz<String>
    var plz: FeldMitKonfidenz<String>
    var stadt: FeldMitKonfidenz<String>
    var gesamtflaecheM2: FeldMitKonfidenz<Decimal>

    // Wohneinheit
    var einheitBezeichnung: FeldMitKonfidenz<String>
    var einheitFlaecheM2: FeldMitKonfidenz<Decimal>

    // Mieter
    var mieterName: FeldMitKonfidenz<String>
    var mieterAnschrift: FeldMitKonfidenz<String>
    var einzugAm: FeldMitKonfidenz<Date>

    // Nebenkosten
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

/// Service-Schnittstelle. Aktuell nur Stub — spaeter hier
/// `extrahiere(ausBildern: [UIImage])` + Claude-Proxy ergaenzen.
@MainActor
enum MietvertragsExtraktionService {

    enum Fehler: Error, LocalizedError {
        case keineBilder
        case netzwerk
        case parseFehler

        var errorDescription: String? {
            switch self {
            case .keineBilder:  return "Keine Seiten gescannt."
            case .netzwerk:     return "Netzwerkfehler bei der KI-Analyse."
            case .parseFehler:  return "KI-Antwort konnte nicht interpretiert werden."
            }
        }
    }

    /// Stub-Implementierung: simuliert 1.5 s Denkzeit und liefert
    /// dummy Demo-Daten. Damit laesst sich der UI-Flow komplett
    /// durchspielen — die echte Claude-Anbindung haengen wir in M2
    /// statt des Stubs hier ein.
    static func extrahiere(ausBildern bilder: [UIImage]) async throws -> MietvertragsExtraktion {
        guard !bilder.isEmpty else { throw Fehler.keineBilder }
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        return demoExtraktion
    }

    /// Deterministische Demo-Extraktion — passt zu einem fiktiven
    /// Mietvertrag „Am Dorfteich 4, 16818 Schmachtenhagen", damit
    /// der Flow mit realistischen Daten testbar ist. Konfidenzen
    /// bewusst gemischt (gruen/gelb/rot), damit die UI-Ampeln
    /// sichtbar werden.
    private static var demoExtraktion: MietvertragsExtraktion {
        let kal = Calendar(identifier: .gregorian)
        let einzug = kal.date(from: DateComponents(year: 2024, month: 3, day: 1)) ?? Date()

        return MietvertragsExtraktion(
            adresse:                   .init(wert: "Am Dorfteich 4",       konfidenz: 0.93),
            plz:                       .init(wert: "16818",                konfidenz: 0.95),
            stadt:                     .init(wert: "Schmachtenhagen",      konfidenz: 0.91),
            gesamtflaecheM2:           .init(wert: 65,                     konfidenz: 0.74),
            einheitBezeichnung:        .init(wert: "Datsche",              konfidenz: 0.62),
            einheitFlaecheM2:          .init(wert: 65,                     konfidenz: 0.74),
            mieterName:                .init(wert: "Hans Beispielmieter",  konfidenz: 0.88),
            mieterAnschrift:           .init(wert: "Musterweg 12, 10115 Berlin", konfidenz: 0.71),
            einzugAm:                  .init(wert: einzug,                 konfidenz: 0.84),
            vorauszahlungMonatEuro:    .init(wert: 120,                    konfidenz: 0.79),
            abrechnungsturnus:         .init(wert: "jährlich",             konfidenz: 0.46),
            kaution:                   .init(wert: 900,                    konfidenz: 0.38),
            besondereNKVereinbarungen: .leer
        )
    }
}
