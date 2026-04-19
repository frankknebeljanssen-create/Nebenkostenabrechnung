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

    /// Haupt-Container für die App, mit CloudKit-Sync über privaten Container.
    ///
    /// Der Container-Identifier muss identisch zum iCloud-Container in den
    /// Xcode Capabilities sein. Beim Produktiv-Launch Placeholder ersetzen.
    static func app() throws -> ModelContainer {
        let schema = Schema(alleSchemaTypen)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.com.example.NebenkostenApp")
        )
        return try ModelContainer(for: schema, configurations: [config])
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
