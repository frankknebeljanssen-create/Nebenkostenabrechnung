//
//  KostenartEditView.swift
//  NebenkostenApp — UI/Kostenart
//
//  Sheet zum Anlegen oder Bearbeiten einer Kostenart.
//

import SwiftUI
import SwiftData

struct KostenartEditView: View {
    enum Modus {
        case neu(immobilie: Immobilie)
        case bearbeiten(Kostenart)
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let modus: Modus

    @State private var bezeichnung: String
    @State private var betrKvKategorie: String
    @State private var umlageschluessel: Umlageschluessel
    @State private var paragraph35a: Bool
    @State private var paragraph35aNurLohnanteil: Bool
    @State private var aktiv: Bool

    @State private var zeigeLoeschenBestaetigung = false

    init(modus: Modus) {
        self.modus = modus
        switch modus {
        case .neu:
            _bezeichnung = State(initialValue: "")
            _betrKvKategorie = State(initialValue: "")
            _umlageschluessel = State(initialValue: .flaeche)
            _paragraph35a = State(initialValue: false)
            _paragraph35aNurLohnanteil = State(initialValue: false)
            _aktiv = State(initialValue: true)
        case .bearbeiten(let ka):
            _bezeichnung = State(initialValue: ka.bezeichnung)
            _betrKvKategorie = State(initialValue: ka.betrKvKategorie)
            _umlageschluessel = State(initialValue: ka.umlageschluessel)
            _paragraph35a = State(initialValue: ka.paragraph35a)
            _paragraph35aNurLohnanteil = State(initialValue: ka.paragraph35aNurLohnanteil)
            _aktiv = State(initialValue: ka.aktiv)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Bezeichnung") {
                    TextField("z.B. Grundsteuer", text: $bezeichnung)
                        .textContentType(.none)
                }

                Section("BetrKV-Kategorie") {
                    TextField("z.B. 1, 4a, 13", text: $betrKvKategorie)
                        .textInputAutocapitalization(.never)
                    Text("BetrKV §2 definiert 17 Kategorien umlagefähiger Betriebskosten.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Umlageschlüssel") {
                    Picker("Umlage", selection: $umlageschluessel) {
                        ForEach(Umlageschluessel.allCases, id: \.self) { s in
                            Text(s.anzeigeName).tag(s)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Steuerlich") {
                    Toggle("§ 35a EStG-relevant", isOn: $paragraph35a)
                    if paragraph35a {
                        Toggle("Nur Lohnanteil absetzbar", isOn: $paragraph35aNurLohnanteil)
                    }
                    Text("§ 35a EStG: haushaltsnahe Dienstleistungen (20 %, max. 4.000 €) und Handwerker (20 %, max. 1.200 €).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Status") {
                    Toggle("Aktiv in Abrechnung", isOn: $aktiv)
                }

                if case .bearbeiten = modus {
                    Section {
                        Button("Kostenart löschen", role: .destructive) {
                            zeigeLoeschenBestaetigung = true
                        }
                    }
                }
            }
            .navigationTitle(titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { speichern() }
                        .disabled(!istGueltig)
                }
            }
            .alert(
                "Kostenart löschen?",
                isPresented: $zeigeLoeschenBestaetigung,
                actions: {
                    Button("Abbrechen", role: .cancel) {}
                    Button("Löschen", role: .destructive) { loeschen() }
                },
                message: {
                    Text("Die Kostenart wird unwiderruflich entfernt. Bereits verknüpfte Rechnungen bleiben erhalten, verlieren aber die Kostenart-Zuordnung.")
                }
            )
        }
    }

    private var titel: String {
        switch modus {
        case .neu:        return "Neue Kostenart"
        case .bearbeiten: return "Kostenart"
        }
    }

    private var istGueltig: Bool {
        !bezeichnung.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func speichern() {
        let ka: Kostenart
        switch modus {
        case .neu(let immobilie):
            ka = Kostenart()
            ka.immobilie = immobilie
            ka.sortierung = ((immobilie.kostenarten ?? [])
                .map(\.sortierung).max() ?? 0) + 10
            modelContext.insert(ka)
        case .bearbeiten(let existing):
            ka = existing
        }
        ka.bezeichnung = bezeichnung.trimmingCharacters(in: .whitespaces)
        ka.betrKvKategorie = betrKvKategorie.trimmingCharacters(in: .whitespaces)
        ka.umlageschluessel = umlageschluessel
        ka.paragraph35a = paragraph35a
        ka.paragraph35aNurLohnanteil = paragraph35a ? paragraph35aNurLohnanteil : false
        ka.aktiv = aktiv

        try? modelContext.save()
        dismiss()
    }

    private func loeschen() {
        if case .bearbeiten(let ka) = modus {
            modelContext.delete(ka)
            try? modelContext.save()
            dismiss()
        }
    }
}
