//
//  ScopeFilter.swift
//  NebenkostenApp — Core
//
//  Reine Filter-Helfer, die aus einer Immobilie + Scope die sichtbare
//  Zähler-, Rechnungs- oder Abrechnungs-Liste bauen. Ausgelagert aus
//  den Views, damit die Filter-Logik direkt testbar ist.
//

import Foundation

@MainActor
enum ScopeFilter {

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
                .first(where: { $0.bezeichnung == id })?
                .zaehler ?? []
            let haupt = immobilie.hauptzaehler ?? []
            return einheitZaehler + haupt
        }
    }

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
            return alle.filter { $0.einheitBezeichnung == id }
        }
    }
}
