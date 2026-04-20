//
//  ScopeManager.swift
//  NebenkostenApp — Core
//
//  App-weiter Umschalter zwischen Gesamt-Objekt-Sicht und Sicht einer
//  einzelnen Wohneinheit. Reine Anzeige-Ebene — Scope filtert Views,
//  aber berührt KEINE Berechnungs-Logik im AbrechnungsService. Scope
//  wird in UserDefaults persistiert und überlebt App-Neustart.
//

import Foundation

enum AbrechnungsScope: Equatable, Hashable, Sendable {
    case objekt
    /// Einheit-ID: Wohneinheit.bezeichnung (z.B. "KG", "EG", "OG") —
    /// menschenlesbar und stabil.
    case einheit(id: String)
}

@Observable
@MainActor
final class ScopeManager {
    private let storageKey = "currentScope.v1"
    private let defaults: UserDefaults

    var scope: AbrechnungsScope = .objekt {
        didSet { persist() }
    }

    /// Default-Init nutzt `.standard`. Tests können eine eigene
    /// UserDefaults-Suite übergeben, damit der persistierte Scope
    /// nicht mit Runtime-Daten kollidiert.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        scope = geladeneScope() ?? .objekt
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
    /// nicht mehr vorkommt, Scope automatisch auf .objekt zurückfallen.
    func bereinige(verfuegbareEinheitIDs ids: Set<String>) {
        if case .einheit(let id) = scope, !ids.contains(id) {
            scope = .objekt
        }
    }

    // MARK: - Persistenz

    private func persist() {
        switch scope {
        case .objekt:
            defaults.set("objekt", forKey: storageKey)
        case .einheit(let id):
            defaults.set("einheit:\(id)", forKey: storageKey)
        }
    }

    private func geladeneScope() -> AbrechnungsScope? {
        guard let raw = defaults.string(forKey: storageKey) else {
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
}
