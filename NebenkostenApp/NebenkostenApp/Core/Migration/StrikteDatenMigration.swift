//
//  StrikteDatenMigration.swift
//  NebenkostenApp — Core/Migration
//
//  Einmalige Migration für den Strikte-Daten-Task. Markiert
//  bestehende Mieter-Vorauszahlungen und Zählerstände als erfasst,
//  damit der neue PreFlight-Check die Bestandsdaten (Phase-0-Seed
//  und bereits eingespielte User-Daten) nicht plötzlich blockiert.
//
//  Wird beim App-Start aufgerufen (NebenkostenAppApp.init). Läuft
//  exakt einmal pro Installation — ein UserDefaults-Flag
//  `migration.strikte_daten.v1.done` verhindert Wiederholung.
//
//  Konservative Regeln:
//   - Mieter.vorauszahlungErfasst wird auf `true` gesetzt, wenn
//     bisher ein Betrag > 0 existierte. Ein Default-0 ohne expliziten
//     User-Input bleibt auf `false`, damit der PreFlight-Check in
//     Echt-Nutzungsfällen nicht fälschlich durchwinkt.
//   - Zaehlerstand.erfasstAm wird auf `ablesedatum` gesetzt, wenn
//     der Stand einen Wert != 0 hat. Stände mit Wert 0 UND ohne
//     `erfasstAm` bleiben unmarkiert — das sind die, die wir als
//     "unbrauchbar" behandeln wollen.
//   - Rechnungen wurden schon vorher per Default auf
//     `validierungsStatus = .importiert` gesetzt (siehe
//     Models/DataModel.swift, Commit "Strikte-Daten · 1"); dieser
//     Migration-Schritt ist damit abgedeckt.
//

import Foundation
import SwiftData

@MainActor
enum StrikteDatenMigration {

    /// UserDefaults-Key, der das einmalige Ausführen garantiert.
    /// Wenn sich die Regeln ändern, Version hochziehen (v1 → v2).
    static let flagKey = "migration.strikte_daten.v1.done"

    /// Führt die Migration aus, wenn das Flag noch nicht gesetzt ist.
    /// Idempotent: zweiter Aufruf ist No-Op.
    static func fuehrAusWennNoetig(
        in context: ModelContext,
        defaults: UserDefaults = .standard
    ) {
        if defaults.bool(forKey: flagKey) { return }

        markiereVorauszahlungen(in: context)
        markiereZaehlerstaende(in: context)

        try? context.save()
        defaults.set(true, forKey: flagKey)
    }

    // MARK: - Mieter-Vorauszahlung

    private static func markiereVorauszahlungen(in context: ModelContext) {
        guard let alle = try? context.fetch(FetchDescriptor<Mietverhaeltnis>()) else {
            return
        }
        for mv in alle {
            // Nur Bestandsdaten umstellen, die schon eine
            // Vorauszahlung > 0 haben. Neue Mietverhältnisse mit
            // Default-0 bleiben als "nicht erfasst" — der User soll
            // den Wert aktiv setzen.
            if mv.vorauszahlungMonatEuro > 0 {
                mv.vorauszahlungErfasst = true
            }
        }
    }

    // MARK: - Zählerstände

    private static func markiereZaehlerstaende(in context: ModelContext) {
        guard let alle = try? context.fetch(FetchDescriptor<Zaehlerstand>()) else {
            return
        }
        for stand in alle {
            // Wenn `erfasstAm` bereits gesetzt ist (neuer User-
            // Eintrag nach dem Task): nicht anfassen.
            if stand.erfasstAm != nil { continue }
            // Seed-Daten und Import-Stände haben Wert != 0 — als
            // erfasst übernehmen. Stände mit 0 ohne erfasstAm
            // lassen wir unmarkiert, weil das unseriöse Platzhalter
            // aus früheren Versionen sein können.
            if stand.stand != 0 {
                stand.erfasstAm = stand.ablesedatum
            }
        }
    }
}
