//
//  DatenSection.swift
//  NebenkostenApp — UI/Einstellungen/Sections
//
//  Gesamte Daten-Verwaltung: Export, Import (Platzhalter, folgt),
//  und zweistufige Löschung mit Textinput-Bestätigung "LÖSCHEN".
//
//  Enthält auch den (existierenden) DSGVO-JSON-Export und ersetzt
//  die alte DatenLoeschungSection.
//

import SwiftUI
import SwiftData

struct DatenSection: View {
    @Environment(\.modelContext) private var modelContext

    @State private var exportURL: URL?
    @State private var exportLaeuft: Bool = false
    @State private var exportFehler: String?

    @State private var zeigeLoesch1 = false
    @State private var zeigeLoesch2 = false
    @State private var loeschText: String = ""
    @State private var loeschLaeuft = false
    @State private var loeschErfolg: Bool = false
    @State private var loeschFehler: String?

    private static let bestaetigungsWort = "LÖSCHEN"

    var body: some View {
        Section {
            // Export (DSGVO Art. 15)
            if let url = exportURL {
                ShareLink(item: url) {
                    Label("Export teilen", systemImage: "square.and.arrow.up")
                }
                Button("Neuen Export erstellen") {
                    exportURL = nil
                }
                .foregroundStyle(.secondary)
            } else if exportLaeuft {
                HStack {
                    ProgressView()
                    Text("Export wird vorbereitet …")
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    starteExport()
                } label: {
                    Label("Daten exportieren", systemImage: "square.and.arrow.down")
                }
            }

            // Import — Placeholder
            Button {
                // TODO: File-Picker + Merge-Logik folgen.
            } label: {
                Label("Daten importieren", systemImage: "arrow.up.doc")
                    .foregroundStyle(.secondary)
            }
            .disabled(true)

            // Löschen (DSGVO Art. 17, zweistufig)
            Button(role: .destructive) {
                zeigeLoesch1 = true
            } label: {
                Label("Alle Daten löschen", systemImage: "trash")
                    .foregroundStyle(DesignTokens.statusError)
            }
        } header: {
            Text("Daten")
        } footer: {
            Text("Exporte nach DSGVO Art. 15. Löschung nach Art. 17 — die App fragt zweifach nach.")
                .appFont(AppFont.smallCaption())
                .foregroundStyle(DesignTokens.textTertiary)
        }
        .alert("Export-Fehler",
               isPresented: Binding(
                   get: { exportFehler != nil },
                   set: { if !$0 { exportFehler = nil } }
               ),
               actions: { Button("OK", role: .cancel) {} },
               message: { Text(exportFehler ?? "") })
        .alert("Wirklich alle Daten löschen?",
               isPresented: $zeigeLoesch1,
               actions: {
                   Button("Abbrechen", role: .cancel) { zeigeLoesch1 = false }
                   Button("Weiter", role: .destructive) {
                       loeschText = ""
                       zeigeLoesch2 = true
                   }
               },
               message: {
                   Text("Diese Aktion kann nicht rückgängig gemacht werden. Alle Objekte, Einheiten, Zählerstände, Rechnungen, Belege und Abrechnungen werden entfernt.")
               })
        .alert("Bestätigung erforderlich",
               isPresented: $zeigeLoesch2,
               actions: {
                   TextField("Tippe LÖSCHEN", text: $loeschText)
                       .textInputAutocapitalization(.characters)
                       .autocorrectionDisabled()
                   Button("Abbrechen", role: .cancel) {
                       loeschText = ""
                       zeigeLoesch2 = false
                   }
                   Button("Löschen", role: .destructive) {
                       versucheLoeschen()
                   }
                   .disabled(loeschText.trimmingCharacters(in: .whitespaces).uppercased() != Self.bestaetigungsWort)
               },
               message: {
                   Text("Tippe »\(Self.bestaetigungsWort)« in Großbuchstaben, um endgültig zu löschen.")
               })
        .alert("Löschung fehlgeschlagen",
               isPresented: Binding(
                   get: { loeschFehler != nil },
                   set: { if !$0 { loeschFehler = nil } }
               ),
               actions: { Button("OK", role: .cancel) {} },
               message: { Text(loeschFehler ?? "") })
    }

    // MARK: - Aktionen

    private func starteExport() {
        exportLaeuft = true
        let context = modelContext
        Task { @MainActor in
            defer { exportLaeuft = false }
            do {
                exportURL = try DatenExportService.erstelleExportDatei(in: context)
            } catch {
                exportFehler = error.localizedDescription
            }
        }
    }

    private func versucheLoeschen() {
        let eingabe = loeschText.trimmingCharacters(in: .whitespaces).uppercased()
        guard eingabe == Self.bestaetigungsWort else {
            loeschFehler = "Bestätigungstext stimmt nicht."
            return
        }
        loeschLaeuft = true
        loeschText = ""
        zeigeLoesch2 = false
        let context = modelContext
        Task { @MainActor in
            defer { loeschLaeuft = false }
            do {
                try DatenLoeschService.loescheAlles(in: context)
                loeschErfolg = true
            } catch {
                loeschFehler = error.localizedDescription
            }
        }
    }
}
