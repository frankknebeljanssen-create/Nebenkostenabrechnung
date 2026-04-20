//
//  DatenLoeschService.swift
//  NebenkostenApp — Services
//
//  DSGVO Art. 17-konforme Löschung: alle Entitäten werden entfernt.
//  Reihenfolge "Kinder zuerst" — auch wenn DataModel Cascade-Regeln
//  hat, stellen explizite Deletes sicher, dass keine Orphan-Referenzen
//  zurückbleiben.
//

import Foundation
import SwiftData

@MainActor
enum DatenLoeschService {

    static func loescheAlles(in context: ModelContext) throws {
        try loesche(Abrechnungsposition.self, in: context)
        try loesche(Abrechnung.self, in: context)
        try loesche(Abrechnungsperiode.self, in: context)
        try loesche(Zaehlerstand.self, in: context)
        try loesche(Zaehler.self, in: context)
        try loesche(Mietverhaeltnis.self, in: context)
        try loesche(Rechnung.self, in: context)
        try loesche(Kostenart.self, in: context)
        try loesche(Wohneinheit.self, in: context)
        try loesche(Immobilie.self, in: context)
        try loesche(AppUser.self, in: context)
        try context.save()

        leereTemporaereDateien()
    }

    private static func loesche<T: PersistentModel>(
        _: T.Type,
        in context: ModelContext
    ) throws {
        let alle = try context.fetch(FetchDescriptor<T>())
        for element in alle {
            context.delete(element)
        }
    }

    /// Räumt das tmp-Verzeichnis auf — dort liegen ggf. generierte
    /// Export-JSONs und PDF-Dateien aus dem Abrechnungs-Flow.
    private static func leereTemporaereDateien() {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory
        guard let inhalte = try? fm.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil) else {
            return
        }
        for url in inhalte {
            try? fm.removeItem(at: url)
        }
    }
}
