//
//  ScanEntryView.swift
//  NebenkostenApp — UI/Scan
//
//  Einstiegs-Sheet: drei Optionen (Kamera / Galerie / Datei). Nach
//  erfolgreichem Import wird das Dokument gespeichert, optional
//  direkt zugeordnet (autoRechnung/autoZaehlerstand), sonst wird
//  ScanZuordnungView als Folge-Sheet angezeigt.
//

import SwiftUI
import SwiftData
import UIKit

struct ScanEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Wenn gesetzt, wird das Dokument automatisch dieser Rechnung
    /// zugeordnet und das Sheet schließt direkt nach Import.
    let autoRechnung: Rechnung?
    /// Analog für Zählerstand.
    let autoZaehlerstand: Zaehlerstand?
    /// Callback mit dem neu angelegten Dokument. Wird nach Zuordnung
    /// (oder direkt bei Auto-Zuordnung) aufgerufen.
    let onFertig: (GespeichertesDokument) -> Void

    init(
        autoRechnung: Rechnung? = nil,
        autoZaehlerstand: Zaehlerstand? = nil,
        onFertig: @escaping (GespeichertesDokument) -> Void = { _ in }
    ) {
        self.autoRechnung = autoRechnung
        self.autoZaehlerstand = autoZaehlerstand
        self.onFertig = onFertig
    }

    @State private var zeigeKamera = false
    @State private var zeigeDateiImporter = false
    @State private var importiertesDokument: GespeichertesDokument?
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
                        onFertig: { bilder in speicherGalerie(bilder) },
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

                if let z = autoZaehlerstand {
                    Section("Wird zugeordnet zu") {
                        Label("Zähler \(z.zaehler?.bezeichnung ?? "—")",
                              systemImage: "gauge")
                            .font(.subheadline)
                    }
                } else if let r = autoRechnung {
                    Section("Wird zugeordnet zu") {
                        Label("Rechnung \(r.lieferant)",
                              systemImage: "doc.text")
                            .font(.subheadline)
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
            .sheet(item: $importiertesDokument) { doc in
                ScanZuordnungView(dokument: doc) {
                    onFertig(doc)
                    dismiss()
                }
            }
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
                seitenAnzahl: bilder.count,
                context: modelContext
            )
            zuordnungAnwenden(auf: doc)
            try modelContext.save()
            weiter(mit: doc)
        } catch {
            fehlermeldung = error.localizedDescription
        }
    }

    private func speicherGalerie(_ bilder: [UIImage]) {
        do {
            let doc: GespeichertesDokument
            if bilder.count > 1 {
                let pdf = try DokumentAblageService.pdfAusBildern(bilder)
                doc = try DokumentAblageService.speichere(
                    data: pdf, endung: "pdf",
                    quelle: .galerie, seitenAnzahl: bilder.count,
                    context: modelContext
                )
            } else if let bild = bilder.first,
                      let jpg = bild.jpegData(compressionQuality: 0.85) {
                doc = try DokumentAblageService.speichere(
                    data: jpg, endung: "jpg",
                    quelle: .galerie, seitenAnzahl: 1,
                    context: modelContext
                )
            } else {
                return
            }
            zuordnungAnwenden(auf: doc)
            try modelContext.save()
            weiter(mit: doc)
        } catch {
            fehlermeldung = error.localizedDescription
        }
    }

    private func speicherDatei(_ ergebnis: DateiImportErgebnis) {
        do {
            let seiten = (ergebnis.endung == "pdf") ? 1 : 1
            let doc = try DokumentAblageService.speichere(
                data: ergebnis.data,
                endung: ergebnis.endung,
                quelle: .datei,
                seitenAnzahl: seiten,
                context: modelContext
            )
            zuordnungAnwenden(auf: doc)
            try modelContext.save()
            weiter(mit: doc)
        } catch {
            fehlermeldung = error.localizedDescription
        }
    }

    private func zuordnungAnwenden(auf doc: GespeichertesDokument) {
        doc.rechnung = autoRechnung
        doc.zaehlerstand = autoZaehlerstand
    }

    private func weiter(mit doc: GespeichertesDokument) {
        if autoRechnung != nil || autoZaehlerstand != nil {
            onFertig(doc)
            dismiss()
        } else {
            importiertesDokument = doc
        }
    }
}
