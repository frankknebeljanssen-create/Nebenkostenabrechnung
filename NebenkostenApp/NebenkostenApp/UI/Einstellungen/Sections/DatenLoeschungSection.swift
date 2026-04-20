//
//  DatenLoeschungSection.swift
//  NebenkostenApp — UI/Einstellungen/Sections
//

import SwiftUI
import SwiftData

struct DatenLoeschungSection: View {
    @Environment(\.modelContext) private var modelContext

    @State private var zeigeStufe1 = false
    @State private var zeigeStufe2 = false
    @State private var bestaetigungsText: String = ""
    @State private var fehlermeldung: String?

    var body: some View {
        Section {
            Button(role: .destructive) {
                zeigeStufe1 = true
            } label: {
                Label("Alle Daten unwiderruflich löschen", systemImage: "trash.fill")
            }
        } header: {
            Text("Daten löschen")
        } footer: {
            Text("Löscht alle Objekte, Mieter, Zähler, Rechnungen, Abrechnungen und Ihre Stammdaten. Nach Art. 17 DSGVO (Recht auf Löschung). Nicht rückgängig zu machen — die App startet danach im Welcome-Screen.")
        }
        .alert(
            "Alle Daten löschen?",
            isPresented: $zeigeStufe1,
            actions: {
                Button("Abbrechen", role: .cancel) {}
                Button("Fortfahren", role: .destructive) {
                    // Kurz verzögert, damit die Alert-Animation abgeschlossen
                    // ist, bevor die zweite Stufe öffnet.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        zeigeStufe2 = true
                    }
                }
            },
            message: {
                Text("Möchten Sie wirklich alle Daten löschen? Dies kann nicht rückgängig gemacht werden.")
            }
        )
        .alert(
            "Zur Bestätigung LÖSCHEN eintippen",
            isPresented: $zeigeStufe2,
            actions: {
                TextField("LÖSCHEN", text: $bestaetigungsText)
                    .textInputAutocapitalization(.characters)
                Button("Löschen", role: .destructive) {
                    versucheLoeschung()
                }
                .disabled(bestaetigungsText.trimmingCharacters(in: .whitespaces) != "LÖSCHEN")
                Button("Abbrechen", role: .cancel) {
                    bestaetigungsText = ""
                }
            },
            message: {
                Text("Dies entfernt alle App-Daten unwiderruflich.")
            }
        )
        .alert(
            "Löschen fehlgeschlagen",
            isPresented: Binding(
                get: { fehlermeldung != nil },
                set: { if !$0 { fehlermeldung = nil } }
            ),
            actions: { Button("OK", role: .cancel) {} },
            message: { Text(fehlermeldung ?? "") }
        )
    }

    private func versucheLoeschung() {
        let eingabe = bestaetigungsText.trimmingCharacters(in: .whitespaces)
        guard eingabe == "LÖSCHEN" else {
            fehlermeldung = "Bitte tippen Sie exakt LÖSCHEN."
            return
        }
        do {
            try DatenLoeschService.loescheAlles(in: modelContext)
            bestaetigungsText = ""
            // Nach save() liefert @Query in ContentView eine leere
            // AppUser-Liste → automatischer Wechsel zum OnboardingFlow.
        } catch {
            fehlermeldung = error.localizedDescription
        }
    }
}
