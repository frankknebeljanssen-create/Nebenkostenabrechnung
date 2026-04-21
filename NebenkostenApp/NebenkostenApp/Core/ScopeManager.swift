//
//  ScopeManager.swift
//  NebenkostenApp — Core
//
//  App-weiter Kontext-Owner. Haelt drei Achsen der aktuellen Sicht:
//    1. Scope — Gesamt-Objekt vs. einzelne Einheit
//    2. Aktuelle Immobilie — UUID der angezeigten Liegenschaft
//    3. Aktuelle Periode — UUID der angezeigten Abrechnungsperiode
//       (pro Immobilie separat gemerkt)
//
//  Reine Anzeige-Ebene — beruehrt KEINE Berechnungs-Logik im
//  AbrechnungsService. Alle drei Achsen werden in UserDefaults
//  persistiert und ueberleben App-Neustart.
//
//  Architekturentscheidung aus c7dfa66: ScopeManager wird erweitert
//  (nicht umschlossen), weil er bereits der App-weite Kontext-Owner
//  ist. Wechsel der Immobilie setzt den Scope automatisch auf
//  .objekt zurueck — der alte Einheit-Scope passt ansonsten oft
//  nicht ins neue Objekt (andere Bezeichnungen).
//

import Foundation

enum AbrechnungsScope: Equatable, Hashable, Sendable, Codable {
    case objekt
    /// Einheit-ID: Wohneinheit.bezeichnung (z.B. "KG", "EG", "OG") —
    /// menschenlesbar und stabil.
    case einheit(id: String)
}

/// Alias für den Design-Handoff (tokens.jsx verwendet "AppScope").
/// Identisch zu AbrechnungsScope — zwei Namen, ein Typ.
typealias AppScope = AbrechnungsScope

@Observable
@MainActor
final class ScopeManager {
    private let storageKey           = "currentScope.v1"
    private let immobilieStorageKey  = "currentImmobilieID.v1"
    private let periodenStorageKey   = "currentPeriodeID.v1"

    private let defaults: UserDefaults

    var scope: AbrechnungsScope = .objekt {
        didSet { persist() }
    }

    /// Aktuell gewaehlte Immobilie. Wechsel zwischen zwei nicht-nil
    /// IDs setzt `scope` automatisch auf `.objekt` zurueck — der
    /// Einheit-Scope des alten Objekts ist im neuen selten gueltig.
    /// Initial-Set (nil → irgendeine ID) laesst den Scope in Ruhe,
    /// damit ein frischer App-Start keinen unerwarteten Seiteneffekt
    /// ausloest.
    var aktuelleImmobilieID: UUID? = nil {
        didSet {
            guard aktuelleImmobilieID != oldValue else { return }
            if aktuelleImmobilieID != nil, oldValue != nil {
                scope = .objekt
            }
            persistImmobilie()
        }
    }

    /// Per-Immobilie zuletzt gewaehlte Periode. `aktuellePeriodeID`
    /// liest/schreibt darauf, damit der User beim Objektwechsel
    /// seine letzte Perioden-Auswahl pro Objekt zurueckbekommt.
    private var periodenWahl: [UUID: UUID] = [:]

    /// Aktuelle Periode fuer `aktuelleImmobilieID`. Getter liefert
    /// `nil`, wenn keine Immobilie gesetzt oder fuer die Immobilie
    /// noch nichts gemerkt ist.
    var aktuellePeriodeID: UUID? {
        get {
            guard let immo = aktuelleImmobilieID else { return nil }
            return periodenWahl[immo]
        }
        set {
            guard let immo = aktuelleImmobilieID else { return }
            if let v = newValue {
                periodenWahl[immo] = v
            } else {
                periodenWahl.removeValue(forKey: immo)
            }
            persistPerioden()
        }
    }

    /// Default-Init nutzt `.standard`. Tests uebergeben eine eigene
    /// UserDefaults-Suite, damit der persistierte Zustand nicht mit
    /// Runtime-Daten kollidiert.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        scope = Self.ladeScope(defaults: defaults, key: storageKey) ?? .objekt
        aktuelleImmobilieID = Self.ladeImmobilie(
            defaults: defaults,
            key: immobilieStorageKey
        )
        periodenWahl = Self.ladePerioden(
            defaults: defaults,
            key: periodenStorageKey
        )
    }

    // MARK: - Convenience

    var isObjekt: Bool {
        if case .objekt = scope { return true }
        return false
    }

    var einheitID: String? {
        if case .einheit(let id) = scope { return id }
        return nil
    }

    /// Setzt den Scope auf .objekt — z.B. wenn die aktuell aktive Einheit
    /// gelöscht wurde.
    func zuruecksetzenAufObjekt() {
        scope = .objekt
    }

    /// Falls die aktuell selektierte Einheit in der neuen Einheiten-Liste
    /// nicht mehr vorkommt, Scope automatisch auf .objekt zurueckfallen.
    func bereinige(verfuegbareEinheitIDs ids: Set<String>) {
        if case .einheit(let id) = scope, !ids.contains(id) {
            scope = .objekt
        }
    }

    /// Wenn die gemerkte Immobilie nicht mehr existiert, auf nil
    /// zurueckfallen. Gleichzeitig werden Perioden-Eintraege
    /// verschwundener Immobilien aus dem Merker entfernt, damit
    /// UserDefaults nicht langsam volllaeuft.
    func bereinigeImmobilie(verfuegbareIDs ids: Set<UUID>) {
        if let id = aktuelleImmobilieID, !ids.contains(id) {
            aktuelleImmobilieID = nil
        }
        let vorher = periodenWahl
        periodenWahl = periodenWahl.filter { ids.contains($0.key) }
        if periodenWahl != vorher {
            persistPerioden()
        }
    }

    /// Wenn die fuer die aktuelle Immobilie gemerkte Periode nicht
    /// mehr existiert, Eintrag entfernen.
    func bereinigePeriode(verfuegbareIDs ids: Set<UUID>) {
        guard let immo = aktuelleImmobilieID else { return }
        if let p = periodenWahl[immo], !ids.contains(p) {
            periodenWahl.removeValue(forKey: immo)
            persistPerioden()
        }
    }

    // MARK: - Persistenz (Scope)

    private func persist() {
        switch scope {
        case .objekt:
            defaults.set("objekt", forKey: storageKey)
        case .einheit(let id):
            defaults.set("einheit:\(id)", forKey: storageKey)
        }
    }

    private static func ladeScope(defaults: UserDefaults, key: String) -> AbrechnungsScope? {
        guard let raw = defaults.string(forKey: key) else {
            return nil
        }
        if raw == "objekt" { return .objekt }
        let prefix = "einheit:"
        if raw.hasPrefix(prefix) {
            let id = String(raw.dropFirst(prefix.count))
            guard !id.isEmpty else { return nil }
            return .einheit(id: id)
        }
        return nil
    }

    // MARK: - Persistenz (Immobilie)

    private func persistImmobilie() {
        if let id = aktuelleImmobilieID {
            defaults.set(id.uuidString, forKey: immobilieStorageKey)
        } else {
            defaults.removeObject(forKey: immobilieStorageKey)
        }
    }

    private static func ladeImmobilie(defaults: UserDefaults, key: String) -> UUID? {
        guard let raw = defaults.string(forKey: key) else { return nil }
        return UUID(uuidString: raw)
    }

    // MARK: - Persistenz (Perioden)

    private func persistPerioden() {
        let roh = periodenWahl.reduce(into: [String: String]()) { acc, pair in
            acc[pair.key.uuidString] = pair.value.uuidString
        }
        defaults.set(roh, forKey: periodenStorageKey)
    }

    private static func ladePerioden(defaults: UserDefaults, key: String) -> [UUID: UUID] {
        guard let roh = defaults.dictionary(forKey: key) as? [String: String] else {
            return [:]
        }
        return roh.reduce(into: [UUID: UUID]()) { acc, pair in
            guard let k = UUID(uuidString: pair.key),
                  let v = UUID(uuidString: pair.value) else { return }
            acc[k] = v
        }
    }
}
