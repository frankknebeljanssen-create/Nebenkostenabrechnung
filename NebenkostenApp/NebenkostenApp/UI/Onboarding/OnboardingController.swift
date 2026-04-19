//
//  OnboardingController.swift
//  NebenkostenApp — UI/Onboarding
//

import Foundation
import SwiftData

@MainActor
@Observable
final class OnboardingController {
    var schritt: OnboardingStep = .willkommen

    // Zustimmungen
    var datenschutzAkzeptiert: Bool = false
    var avvAkzeptiert: Bool = false

    // User-Stammdaten
    var userName: String = ""
    var userAnschrift: String = ""
    var userOrt: String = ""
    var userEmail: String = ""
    var userTelefon: String = ""
    var userSteuerID: String = ""
    var userRolle: UserRolle = .privat
    var userIban: String = ""

    // Validierung
    var darfVonDatenschutzWeiter: Bool { datenschutzAkzeptiert }
    var darfVonAvvWeiter: Bool { avvAkzeptiert }
    var darfVonUserStammdatenWeiter: Bool {
        !userName.trimmingCharacters(in: .whitespaces).isEmpty
            && istEMailPlausibel(userEmail)
    }

    // Navigation
    func weiter() {
        if let naechste = schritt.naechste { schritt = naechste }
    }

    func zurueck() {
        if let vorherige = schritt.vorherige { schritt = vorherige }
    }

    // Persistenz
    func anlegen(in modelContext: ModelContext) {
        let jetzt = Date()
        let user = AppUser()
        user.name = userName.trimmingCharacters(in: .whitespaces)
        user.anschrift = userAnschrift.trimmingCharacters(in: .whitespaces)
        user.ort = userOrt.trimmingCharacters(in: .whitespaces)
        user.email = userEmail.trimmingCharacters(in: .whitespaces)
        user.telefon = userTelefon.trimmingCharacters(in: .whitespaces)
        user.steuerID = userSteuerID.trimmingCharacters(in: .whitespaces)
        user.rolle = userRolle
        user.iban = userIban.trimmingCharacters(in: .whitespaces)
        user.datenschutzZustimmungAm = datenschutzAkzeptiert ? jetzt : nil
        user.avvZustimmungAm = avvAkzeptiert ? jetzt : nil
        modelContext.insert(user)
        try? modelContext.save()
    }

    private func istEMailPlausibel(_ text: String) -> Bool {
        let tr = text.trimmingCharacters(in: .whitespaces)
        return tr.contains("@") && tr.contains(".") && tr.count >= 5
    }
}
