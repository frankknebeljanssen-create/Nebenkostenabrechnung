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
        Abrechnungsposition.self,
        WarnungsAudit.self,
        GespeichertesDokument.self,
        AIVorschlag.self,
        HVAbrechnung.self,
        HVPosition.self,
        HVEigentuemerKosten.self
    ]

    /// Schaltet den CloudKit-Sync ein/aus.
    ///
    /// Aktivierungs-Checkliste (Task 0.21):
    ///   1. Apple Developer Account aktiv
    ///   2. Bundle-ID auf echten Reverse-DNS-Namen umstellen (aktuell
    ///      Placeholder `com-example.NebenkostenApp`) — in Xcode Target →
    ///      General → Identity → Bundle Identifier
    ///   3. iCloud-Container im Developer Portal anlegen mit Identifier
    ///      `iCloudContainerIdentifier` (siehe Konstante unten)
    ///   4. Xcode Target → Signing & Capabilities → "+Capability" →
    ///      iCloud → CloudKit aktivieren, Container aus Schritt 3 wählen
    ///   5. Flag hier auf `true` flippen
    ///   6. Auf echtem Gerät laufen (Simulator kann CloudKit nur mit
    ///      angemeldeter iCloud-ID, aber die Preview-DBs sind unstable)
    ///
    /// Solange `false`: reiner lokaler SwiftData-Betrieb. Vermeidet den
    /// SwiftData-internen CloudKit-Init, der bei fehlender Entitlement
    /// mit NSException bricht (nicht über Swift-`throws` abfangbar).
    static let cloudKitAktiv = false

    /// CloudKit-Container-Identifier. Muss identisch zum iCloud-Container
    /// in den Xcode Capabilities sein. Bei echtem Launch den Placeholder
    /// durch eine Reverse-DNS des User-Team-Accounts ersetzen, z.B.
    /// `iCloud.de.frankknebeljanssen.NebenkostenApp`. Der Identifier muss
    /// MINUSKEL beginnen und darf Punkte enthalten, aber KEINE Underscores.
    static let iCloudContainerIdentifier = "iCloud.com.example.NebenkostenApp"

    /// Haupt-Container für die App. Versucht — falls `cloudKitAktiv` — den
    /// privaten CloudKit-Container und fällt bei Swift-Errors auf lokales
    /// SwiftData zurück. Bis dahin: nur lokaler Store.
    static func app() throws -> ModelContainer {
        let schema = Schema(alleSchemaTypen)

        if cloudKitAktiv {
            do {
                let cloudConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .private(iCloudContainerIdentifier)
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
