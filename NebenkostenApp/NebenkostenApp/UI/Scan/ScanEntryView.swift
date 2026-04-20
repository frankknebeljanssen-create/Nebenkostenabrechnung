//
//  ScanEntryView.swift
//  NebenkostenApp — UI/Scan
//
//  Einstiegs-Sheet: drei Optionen (Kamera / Mediathek / Datei). Nach
//  erfolgreichem Import wird das Dokument gespeichert; der Folge-
//  Flow (DokumentErfassungView mit Typ/Versorger/Kontext-Erfassung)
//  kommt in Task-1.1-C4 und ersetzt dieses Zwischen-Sheet.
//
//  Bis dahin: das Dokument wird ohne Metadaten gespeichert, Sheet
//  schliesst direkt nach Import.
//

import SwiftUI
import SwiftData
import UIKit

struct ScanEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Callback mit dem neu angelegten Dokument.
    let onFertig: (GespeichertesDokument) -> Void

    init(onFertig: @escaping (GespeichertesDokument) -> Void = { _ in }) {
        self.onFertig = onFertig
    }

    @State private var zeigeKamera = false
    @State private var zeigeDateiImporter = false
    @State private var fehlermeldung: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if DokumentScannerView.istVerfuegbar {
                        Button {
                            zeigeKamera = true
                        } label: {
                            optionZeile(
                                titel: "Mit Kamera scannen",
                                untertitel: "Mehrseitig möglich, Perspektive wird korrigiert",
                                symbol: "camera.fill"
                            )
                        }
                    } else {
                        optionZeile(
                            titel: "Mit Kamera scannen",
                            untertitel: "Nur auf echten Geräten verfügbar",
                            symbol: "camera.fill"
                        )
                        .foregroundStyle(.secondary)
                    }

                    GalerieImportButton(
                        maxAuswahl: 10,
                        onFertig: { bilder in speicherMediathek(bilder) },
                        onFehler: { fehlermeldung = $0.localizedDescription }
                    ) {
                        optionZeile(
                            titel: "Aus Fotos wählen",
                            untertitel: "Bis zu 10 Bilder auf einmal",
                            symbol: "photo.on.rectangle.fill"
                        )
                    }

                    Button {
                        zeigeDateiImporter = true
                    } label: {
                        optionZeile(
                            titel: "Datei auswählen",
                            untertitel: "PDF oder Bild aus Dateien-App",
                            symbol: "folder.fill"
                        )
                    }
                }
            }
            .navigationTitle("Dokument hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $zeigeKamera) {
                DokumentScannerView(
                    onFertig: { bilder in
                        zeigeKamera = false
                        speicherKamera(bilder)
                    },
                    onAbbruch: { zeigeKamera = false },
                    onFehler: { error in
                        zeigeKamera = false
                        fehlermeldung = error.localizedDescription
                    }
                )
                .ignoresSafeArea()
            }
            .dateiImport(
                isPresented: $zeigeDateiImporter,
                onFertig: { e in speicherDatei(e) },
                onFehler: { fehlermeldung = $0.localizedDescription }
            )
            .alert(
                "Fehler beim Import",
                isPresented: .init(
                    get: { fehlermeldung != nil },
                    set: { if !$0 { fehlermeldung = nil } }
                ),
                actions: { Button("OK", role: .cancel) {} },
                message: { Text(fehlermeldung ?? "") }
            )
        }
    }

    // MARK: - Zeile

    private func optionZeile(titel: String, untertitel: String, symbol: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(titel).font(.body.weight(.semibold))
                Text(untertitel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    // MARK: - Speichern

    private func speicherKamera(_ bilder: [UIImage]) {
        do {
            let pdf = try DokumentAblageService.pdfAusBildern(bilder)
            let doc = try DokumentAblageService.speichere(
                data: pdf, endung: "pdf",
                quelle: .kamera,
                seitenanzahl: bilder.count,
                context: modelContext
            )
            try modelContext.save()
            onFertig(doc)
            dismiss()
        } catch {
            fehlermeldung = error.localizedDescription
        }
    }

    private func speicherMediathek(_ bilder: [UIImage]) {
        do {
            let doc: GespeichertesDokument
            if bilder.count > 1 {
                let pdf = try DokumentAblageService.pdfAusBildern(bilder)
                doc = try DokumentAblageService.speichere(
                    data: pdf, endung: "pdf",
                    quelle: .mediathek, seitenanzahl: bilder.count,
                    context: modelContext
                )
            } else if let bild = bilder.first,
                      let jpg = bild.jpegData(compressionQuality: 0.85) {
                doc = try DokumentAblageService.speichere(
                    data: jpg, endung: "jpg",
                    quelle: .mediathek, seitenanzahl: 1,
                    context: modelContext
                )
            } else {
                return
            }
            try modelContext.save()
            onFertig(doc)
            dismiss()
        } catch {
            fehlermeldung = error.localizedDescription
        }
    }

    private func speicherDatei(_ ergebnis: DateiImportErgebnis) {
        do {
            let doc = try DokumentAblageService.speichere(
                data: ergebnis.data,
                endung: ergebnis.endung,
                quelle: .datei,
                seitenanzahl: 1,
                context: modelContext
            )
            try modelContext.save()
            onFertig(doc)
            dismiss()
        } catch {
            fehlermeldung = error.localizedDescription
        }
    }
}
