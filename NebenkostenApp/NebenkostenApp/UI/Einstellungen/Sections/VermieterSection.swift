//
//  VermieterSection.swift
//  NebenkostenApp — UI/Einstellungen/Sections
//
//  Stammdaten des Vermieters (AppUser). Readonly — ein Edit-Modus
//  wird in einem späteren Task hinzugefügt. Kein Eintrag angelegt?
//  Hinweis-Zeile zeigt das Setup-Onboarding an.
//

import SwiftUI
import SwiftData

struct VermieterSection: View {
    @Query(sort: \AppUser.erstelltAm) private var user: [AppUser]

    private var vermieter: AppUser? { user.first }

    var body: some View {
        Section {
            if let v = vermieter {
                eintrag("Name", wert: v.name)
                eintrag("Anschrift", wert: v.anschrift, mehrfachzeilig: true)
                eintrag("E-Mail", wert: v.email)
                if !v.telefon.isEmpty {
                    eintrag("Telefon", wert: v.telefon)
                }
                if !v.steuerID.isEmpty {
                    eintrag("Steuer-ID", wert: v.steuerID)
                }
                if !v.iban.isEmpty {
                    eintrag("IBAN", wert: v.iban, mono: true)
                }
            } else {
                Text("Noch kein Vermieter-Profil angelegt.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Vermieter")
        } footer: {
            Text("Änderungen am Vermieter-Profil folgen in einem späteren Update.")
                .appFont(AppFont.smallCaption())
                .foregroundStyle(DesignTokens.textTertiary)
        }
    }

    @ViewBuilder
    private func eintrag(_ label: String, wert: String, mehrfachzeilig: Bool = false, mono: Bool = false) -> some View {
        if mehrfachzeilig {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .foregroundStyle(.secondary)
                    .appFont(AppFont.caption())
                Text(wert)
                    .appFont(mono ? AppFont.monoCaption() : AppFont.body())
                    .foregroundStyle(.primary)
            }
            .padding(.vertical, 2)
        } else {
            HStack {
                Text(label)
                    .foregroundStyle(.primary)
                Spacer()
                Text(wert)
                    .appFont(mono ? AppFont.monoCaption() : AppFont.body())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}
