//
//  ModelContainer+App.swift
//  NebenkostenApp
//
//  CloudKit-konfigurierter ModelContainer für die App.
//  Nutzt den privaten CloudKit-Container pro User → DSGVO-Compliance
//  durch Apples Infrastruktur.
//

import Foundation
import SwiftData

extension ModelContainer {

    /// Liste aller @Model-Klassen. Bei neuer Entität hier ergänzen.
    private static let alleSchemaTypen: [any PersistentModel.Type] = [
        AppUser.self,
        Immobilie.self,
        Wohneinheit.self,
        Mietverhaeltnis.self,
        Zaehler.self,
        Zaehlerstand.self,
        Kostenart.self,
        Rechnung.self,
        Abrechnungsperiode.self,
        Abrechnung.self,
        Abrechnungsposition.self
    ]

    /// Schaltet den CloudKit-Sync ein/aus. Muss in Task 0.21 auf `true`
    /// gestellt werden, sobald
    ///   - der Developer Account bei Apple aktiv ist,
    ///   - der iCloud-Container `iCloud.com.example.NebenkostenApp` im
    ///     Developer Portal angelegt ist,
    ///   - die iCloud-Capability im Xcode-Target aktiviert ist.
    ///
    /// Solange `false`: reiner lokaler SwiftData-Betrieb. Vermeidet den
    /// SwiftData-internen CloudKit-Init, der bei fehlender Entitlement
    /// mit NSException bricht (nicht über Swift-`throws` abfangbar).
    static let cloudKitAktiv = false

    /// Haupt-Container für die App. Versucht — falls `cloudKitAktiv` — den
    /// privaten CloudKit-Container und fällt bei Swift-Errors auf lokales
    /// SwiftData zurück. Bis dahin: nur lokaler Store.
    ///
    /// Der Container-Identifier muss identisch zum iCloud-Container in den
    /// Xcode Capabilities sein. Beim Produktiv-Launch Placeholder ersetzen.
    static func app() throws -> ModelContainer {
        let schema = Schema(alleSchemaTypen)

        if cloudKitAktiv {
            do {
                let cloudConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .private("iCloud.com.example.NebenkostenApp")
                )
                return try ModelContainer(for: schema, configurations: [cloudConfig])
            } catch {
                #if DEBUG
                print("⚠️ CloudKit nicht verfügbar (\(error.localizedDescription)) — Fallback auf lokales SwiftData.")
                #endif
            }
        }

        let lokalConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        return try ModelContainer(for: schema, configurations: [lokalConfig])
    }

    /// In-Memory-Container für Tests und SwiftUI-Previews.
    static func preview() throws -> ModelContainer {
        let schema = Schema(alleSchemaTypen)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}
