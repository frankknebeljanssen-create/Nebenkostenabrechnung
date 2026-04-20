//
//  DatenExportSection.swift
//  NebenkostenApp — UI/Einstellungen/Sections
//

import SwiftUI
import SwiftData

struct DatenExportSection: View {
    @Environment(\.modelContext) private var modelContext

    @State private var exportURL: URL?
    @State private var laeuft: Bool = false
    @State private var fehlermeldung: String?

    var body: some View {
        Section {
            if let url = exportURL {
                ShareLink(item: url) {
                    Label("Export teilen", systemImage: "square.and.arrow.up")
                }
                Button("Neuen Export erstellen") {
                    exportURL = nil
                }
                .foregroundStyle(.secondary)
            } else if laeuft {
                HStack {
                    ProgressView()
                    Text("Export wird vorbereitet …")
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    erstelleExport()
                } label: {
                    Label("Alle Daten exportieren", systemImage: "square.and.arrow.down")
                }
            }
        } header: {
            Text("Meine Daten")
        } footer: {
            Text("Eine JSON-Datei mit allen Ihren Objekten, Mietern, Zählerständen, Rechnungen, Abrechnungen und Stammdaten wird erstellt. Nach Art. 15 DSGVO (Recht auf Auskunft).")
        }
        .alert(
            "Export-Fehler",
            isPresented: Binding(
                get: { fehlermeldung != nil },
                set: { if !$0 { fehlermeldung = nil } }
            ),
            actions: { Button("OK", role: .cancel) {} },
            message: { Text(fehlermeldung ?? "") }
        )
    }

    private func erstelleExport() {
        laeuft = true
        let context = modelContext
        Task { @MainActor in
            defer { laeuft = false }
            do {
                exportURL = try DatenExportService.erstelleExportDatei(in: context)
            } catch {
                fehlermeldung = error.localizedDescription
            }
        }
    }
}
