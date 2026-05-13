import Foundation
import SwiftData

enum DataDeletionService {

    struct DeletionResult {
        var abrechnungenGeloescht: Int = 0
        var mietobjekteGeloescht: Int = 0
        var auditEntriesGeloescht: Int = 0
        var profilGeloescht: Bool = false
        var keychainGeloescht: Bool = false
        var consentGeloescht: Bool = false
    }

    /// Löscht ALLE Benutzerdaten — DSGVO Art. 17 „Recht auf Löschung".
    @MainActor
    @discardableResult
    static func deleteAllUserData(modelContext: ModelContext) -> DeletionResult {
        var result = DeletionResult()

        // 1. SwiftData: GespeicherteAbrechnung
        if let abrechnungen = try? modelContext.fetch(FetchDescriptor<GespeicherteAbrechnung>()) {
            result.abrechnungenGeloescht = abrechnungen.count
            for a in abrechnungen { modelContext.delete(a) }
        }

        // 2. SwiftData: Mietobjekte
        if let objekte = try? modelContext.fetch(FetchDescriptor<Mietobjekt>()) {
            result.mietobjekteGeloescht = objekte.count
            for o in objekte { modelContext.delete(o) }
        }

        // 3. SwiftData: Audit-Log
        if let entries = try? modelContext.fetch(FetchDescriptor<APIAuditEntry>()) {
            result.auditEntriesGeloescht = entries.count
            for e in entries { modelContext.delete(e) }
        }

        try? modelContext.save()

        // 4. UserDefaults komplett leeren (Profil, Settings, Consent, Onboarding)
        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
            UserDefaults.standard.synchronize()
            result.profilGeloescht = true
            result.consentGeloescht = true
        }

        // 5. Keychain: API-Key
        result.keychainGeloescht = KeychainService.deleteAPIKey()

        return result
    }

    /// Löscht nur die Prüfungs-Historie (Profil/Settings bleiben).
    @MainActor
    @discardableResult
    static func deleteHistory(modelContext: ModelContext) -> Int {
        guard let abrechnungen = try? modelContext.fetch(FetchDescriptor<GespeicherteAbrechnung>()) else {
            return 0
        }
        let count = abrechnungen.count
        for a in abrechnungen { modelContext.delete(a) }
        try? modelContext.save()
        return count
    }
}
