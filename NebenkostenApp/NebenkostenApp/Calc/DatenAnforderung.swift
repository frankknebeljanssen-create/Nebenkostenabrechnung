//
//  DatenAnforderung.swift
//  NebenkostenApp — Calc-Layer
//
//  Pur-value Beschreibung einer einzelnen Datenanforderung für eine
//  Abrechnungsperiode. Wird von der VollstaendigkeitsPruefung erzeugt
//  und vom Dashboard, vom Inspektor-Sheet und (ab Commit 4) vom
//  AbrechnungsService-Pre-Flight konsumiert.
//
//  Einziger erlaubter Import: Foundation.
//

import Foundation

/// Kategorisierung einer Anforderung — bestimmt Gruppierung und Icon.
enum AnforderungsKategorie: String, CaseIterable, Sendable, Codable {
    case stammdaten
    case zaehlerstand
    case rechnung

    var anzeigeName: String {
        switch self {
        case .stammdaten:   return "Stammdaten"
        case .zaehlerstand: return "Zählerstände"
        case .rechnung:     return "Rechnungen"
        }
    }
}

/// Status einer Anforderung im aktuellen Datenbestand.
enum AnforderungsStatus: String, Sendable, Codable {
    /// ✅ grün — Datenpunkt vollständig und plausibel.
    case erfuellt
    /// 🟡 orange — teilweise erfasst oder Plausi-Warnung.
    case teilweise
    /// ❌ grau — nicht erfasst, wird aber erwartet.
    case offen
    /// ⚪ — Anforderung ist bei diesem Objekt nicht relevant.
    case nichtErwartet
}

/// Beschreibt einen konkret erwarteten Datenpunkt für eine Periode.
struct DatenAnforderung: Identifiable, Equatable, Sendable {
    /// Stabile ID wie "zaehler-<UUID>" oder "rechnung-<kostenart-id>".
    /// Wird für View-Identity und Stable-Sortierung verwendet.
    let id: String
    let kategorie: AnforderungsKategorie
    /// Kurzbezeichnung, z.B. "GASAG Jahresrechnung".
    let titel: String
    /// Zusatzhinweis, z.B. "Versorger GASAG · Periode 2024/2025".
    let details: String
    /// `false` = optional (z.B. Aufzugswartung wenn kein Aufzug).
    let erforderlich: Bool

    static func == (lhs: DatenAnforderung, rhs: DatenAnforderung) -> Bool {
        lhs.id == rhs.id
    }
}

/// Schwere einer Anforderung. Trennt Pflichtdaten, ohne die die
/// Abrechnung nicht laufen darf, von Plausibilitäts-Warnungen,
/// die der User zur Kenntnis nehmen, aber nicht zwingend korrigieren
/// muss.
enum AnforderungsSchwere: String, Sendable, Codable {
    /// Blockiert die Berechnung, wenn `status == .offen`. Default-
    /// Verhalten aller bisherigen Regeln.
    case blocker
    /// Informiert den User, blockiert aber nicht. Aktuell
    /// ausschließlich für die WMZ-Plausi-Regel.
    case warnung
}

/// Anforderung zusammen mit konkret ermitteltem Status + optionalem
/// Hinweistext, Sprungziel für direktes UI-Routing und Schwere-
/// Klassifizierung.
struct AnforderungMitStatus: Identifiable, Sendable {
    let anforderung: DatenAnforderung
    let status: AnforderungsStatus
    /// Menschenlesbarer Zusatz, wenn status == .teilweise. Wird vom
    /// Inspektor-Sheet angezeigt.
    let hinweis: String?
    /// Direktes UI-Navigations-Ziel. Die `AppShellRouter`-Instanz
    /// interpretiert das und öffnet den passenden Tab/Sheet.
    let sprungZiel: Sprungziel?
    /// `.blocker` (default) verhindert Berechnung bei `.offen`,
    /// `.warnung` blockiert nie.
    let schwere: AnforderungsSchwere

    init(
        anforderung: DatenAnforderung,
        status: AnforderungsStatus,
        hinweis: String? = nil,
        sprungZiel: Sprungziel? = nil,
        schwere: AnforderungsSchwere = .blocker
    ) {
        self.anforderung = anforderung
        self.status = status
        self.hinweis = hinweis
        self.sprungZiel = sprungZiel
        self.schwere = schwere
    }

    var id: String { anforderung.id }

    /// `true`, wenn diese Anforderung die Berechnung blockiert —
    /// sowohl Schwere `.blocker` als auch Status `.offen` müssen
    /// zusammenkommen. Wird vom AbrechnungsService für den
    /// Blocker-Throw verwendet.
    var blockiertBerechnung: Bool {
        schwere == .blocker && status == .offen
    }
}

/// Fehler-Typ für den AbrechnungsService-Pre-Flight (strikte Daten-
/// anforderung — keine Schätzung).
enum AbrechnungsBlocker: Error, LocalizedError {
    case fehlendeDaten(offeneAnforderungen: [AnforderungMitStatus])

    var errorDescription: String? {
        switch self {
        case .fehlendeDaten(let offen):
            let n = offen.count
            return "Abrechnung nicht möglich — \(n) Datenpunkt\(n == 1 ? "" : "e") "
                + "\(n == 1 ? "fehlt" : "fehlen"). Vollständigkeits-Inspektor öffnen."
        }
    }
}
