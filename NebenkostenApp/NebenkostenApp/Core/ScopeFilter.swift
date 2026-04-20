//
//  ScopeFilter.swift
//  NebenkostenApp — Core
//
//  Typisierter Scope-Filter für die Tab-Views. Zentralisiert die
//  Switch-Logik, die sich sonst in jeder View wiederholen würde,
//  und macht sie testbar. Jede Methode bekommt den unfilterten
//  Input + den aktuellen Scope und gibt die sichtbare Teilmenge
//  zurück.
//
//  Konvention für Einheit-Scope-Filter: Case-insensitive
//  Vergleich auf die Bezeichnung (`"EG" == "eg"`), weil der User
//  bei der Erfassung beides eingibt — der Scope-Manager speichert
//  den Wert aber verbatim wie vom User eingegeben.
//

import Foundation

@MainActor
enum ScopeFilter {

    // MARK: - Zähler

    /// Zähler-Sicht je Scope.
    /// - objekt: alle Haupt- und Einheiten-Zähler.
    /// - einheit(id): nur Zähler der Einheit mit dieser Bezeichnung,
    ///   PLUS alle Hauptzähler (objektweit relevant, z.B. Gas-Haupt).
    static func sichtbareZaehler(
        immobilie: Immobilie,
        scope: AbrechnungsScope
    ) -> [Zaehler] {
        switch scope {
        case .objekt:
            let einheit = (immobilie.wohneinheiten ?? []).flatMap { $0.zaehler ?? [] }
            let haupt = immobilie.hauptzaehler ?? []
            return einheit + haupt
        case .einheit(let id):
            let einheitZaehler = (immobilie.wohneinheiten ?? [])
                .first(where: { $0.bezeichnung.caseInsensitiveCompare(id) == .orderedSame })?
                .zaehler ?? []
            let haupt = immobilie.hauptzaehler ?? []
            return einheitZaehler + haupt
        }
    }

    /// Detaillierte Zähler-Sicht für die ZaehlerView — trennt Haupt-
    /// und Wohnungs-Zähler und filtert im Einheit-Scope Hauptzähler
    /// komplett heraus (dort werden sie in einem dedizierten Header
    /// erwähnt, aber nicht in der Hauptliste gezeigt).
    static func zaehlerGetrennt(
        hauptzaehler: [Zaehler],
        einheiten: [Wohneinheit],
        scope: AbrechnungsScope
    ) -> (haupt: [Zaehler], wohnung: [Zaehler]) {
        switch scope {
        case .objekt:
            let wohnung = einheiten.flatMap { $0.zaehler ?? [] }
            return (haupt: hauptzaehler, wohnung: wohnung)
        case .einheit(let id):
            let ziel = einheiten.first(where: {
                $0.bezeichnung.caseInsensitiveCompare(id) == .orderedSame
            })
            return (haupt: [], wohnung: ziel?.zaehler ?? [])
        }
    }

    // MARK: - Mieterabrechnungen

    /// Mieterabrechnungs-Sicht je Scope.
    /// - objekt: alle Abrechnungen.
    /// - einheit(id): nur die Abrechnung dieser Einheit.
    static func sichtbareAbrechnungen(
        alle: [Mieterabrechnung],
        scope: AbrechnungsScope
    ) -> [Mieterabrechnung] {
        switch scope {
        case .objekt:
            return alle
        case .einheit(let id):
            return alle.filter {
                $0.einheitBezeichnung.caseInsensitiveCompare(id) == .orderedSame
            }
        }
    }

    // MARK: - Belege / Dokumente

    /// Filter für GespeichertesDokument. Objekt-Scope gibt alle zurück,
    /// Einheit-Scope nur die, deren `einheitId` (case-insensitive) auf
    /// den Scope-Wert passt.
    static func sichtbareDokumente(
        alle: [GespeichertesDokument],
        scope: AbrechnungsScope
    ) -> [GespeichertesDokument] {
        switch scope {
        case .objekt:
            return alle
        case .einheit(let id):
            return alle.filter {
                guard let e = $0.einheitId else { return false }
                return e.caseInsensitiveCompare(id) == .orderedSame
            }
        }
    }

    // MARK: - Rechnungen

    /// Rechnungen sind aktuell IMMER objekt-level — sie werden über
    /// den Umlageschlüssel der Kostenart auf Einheiten verteilt. Die
    /// Funktion existiert trotzdem, damit zukünftige Einheit-
    /// spezifische Rechnungen (z.B. "direkte" Umlage) hier filterbar
    /// werden, ohne jede View zu ändern.
    static func sichtbareRechnungen(
        alle: [Rechnung],
        scope: AbrechnungsScope
    ) -> [Rechnung] {
        switch scope {
        case .objekt:  return alle
        case .einheit: return alle
        }
    }

    /// Rechnungen in einer bestimmten Periode (Rechnungsdatum im
    /// Zeitfenster, beide Seiten inklusiv).
    static func rechnungenInPeriode(
        alle: [Rechnung],
        periode: Abrechnungsperiode,
        scope: AbrechnungsScope
    ) -> [Rechnung] {
        sichtbareRechnungen(alle: alle, scope: scope).filter {
            $0.rechnungsdatum >= periode.von && $0.rechnungsdatum <= periode.bis
        }
    }

    // MARK: - Einheiten

    /// Einheiten-Sicht je Scope, sortiert nach Geschoss-Rang.
    ///   objekt    → alle
    ///   einheit   → nur die aktive Einheit (falls sie existiert)
    static func sichtbareEinheiten(
        alle: [Wohneinheit],
        scope: AbrechnungsScope
    ) -> [Wohneinheit] {
        let sortiert = alle.sorted { einheitRang($0.bezeichnung) < einheitRang($1.bezeichnung) }
        switch scope {
        case .objekt:
            return sortiert
        case .einheit(let id):
            return sortiert.filter {
                $0.bezeichnung.caseInsensitiveCompare(id) == .orderedSame
            }
        }
    }

    /// Gibt die Sortier-Rangzahl für eine Einheiten-Bezeichnung
    /// (KG=0, EG=1, OG=2, "2. OG"=3, DG=4, sonst 99). Exportiert,
    /// damit Tests und Views auf dieselbe Reihenfolge-Semantik
    /// zugreifen.
    static func einheitRang(_ bezeichnung: String) -> Int {
        switch bezeichnung.uppercased().trimmingCharacters(in: .whitespaces) {
        case "KG", "UG": return 0
        case "EG":       return 1
        case "OG":       return 2
        case "2. OG":    return 3
        case "DG":       return 4
        default:         return 99
        }
    }
}
