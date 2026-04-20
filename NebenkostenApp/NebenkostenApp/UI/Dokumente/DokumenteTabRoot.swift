//
//  DokumenteTabRoot.swift
//  NebenkostenApp — UI/Dokumente
//
//  Dokumente-Archiv: gruppiert nach Jahr + Monat (nach erstelltAm).
//  Tap → PDFKit-Vorschau-Sheet. Swipe → Löschen mit Bestätigung.
//  Prominenter "+"-Button in der Toolbar öffnet ScanEntryView.
//

import SwiftUI
import SwiftData
import UIKit

struct DokumenteTabRoot: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \GespeichertesDokument.erstelltAm, order: .reverse)
    private var dokumente: [GespeichertesDokument]

    @State private var zeigeScan = false
    @State private var vorschauDokument: GespeichertesDokument?
    @State private var zuLoeschen: GespeichertesDokument?
    @State private var zuValidieren: GespeichertesDokument?

    var body: some View {
        NavigationStack {
            Group {
                if dokumente.isEmpty {
                    leerZustand
                } else {
                    liste
                }
            }
            .navigationTitle("Dokumente")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        zeigeScan = true
                    } label: {
                        Label("Dokument scannen", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $zeigeScan) {
                ScanEntryView { _ in }
            }
            .sheet(item: $zuValidieren) { d in
                ValidierungsView(dokument: d)
            }
            .sheet(item: $vorschauDokument) { d in
                NavigationStack {
                    if let url = try? DokumentAblageService.absoluterPfad(
                        fuer: d.dateipfadRelativ
                    ),
                       FileManager.default.fileExists(atPath: url.path) {
                        PDFVorschauView(url: url)
                            .ignoresSafeArea()
                            .navigationTitle(d.dateiname)
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Fertig") { vorschauDokument = nil }
                                }
                            }
                    } else {
                        Text("Datei nicht gefunden.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .alert(
                "Dokument löschen?",
                isPresented: .init(
                    get: { zuLoeschen != nil },
                    set: { if !$0 { zuLoeschen = nil } }
                ),
                actions: {
                    Button("Abbrechen", role: .cancel) { zuLoeschen = nil }
                    Button("Löschen", role: .destructive) {
                        if let d = zuLoeschen {
                            DokumentAblageService.loesche(d, context: modelContext)
                            try? modelContext.save()
                        }
                        zuLoeschen = nil
                    }
                },
                message: {
                    Text("Datei und Eintrag werden unwiderruflich entfernt.")
                }
            )
        }
    }

    // MARK: - Leer

    private var leerZustand: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Noch keine Dokumente")
                .font(.headline)
            Text("Tippen Sie auf +, um ein Dokument zu scannen oder zu importieren.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                zeigeScan = true
            } label: {
                Label("Dokument hinzufügen", systemImage: "plus.circle.fill")
                    .padding(.horizontal, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Liste

    private var liste: some View {
        List {
            ForEach(monatsgruppen, id: \.schluessel) { gruppe in
                Section {
                    ForEach(gruppe.dokumente, id: \.id) { d in
                        zeile(d)
                            .contentShape(Rectangle())
                            .onTapGesture { vorschauDokument = d }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    zuLoeschen = d
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                                Button {
                                    zuValidieren = d
                                } label: {
                                    Label("Validieren", systemImage: "sparkles")
                                }
                                .tint(.indigo)
                            }
                    }
                } header: {
                    Text(gruppe.ueberschrift)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func zeile(_ d: GespeichertesDokument) -> some View {
        HStack(alignment: .center, spacing: 12) {
            thumbnail(d)

            VStack(alignment: .leading, spacing: 2) {
                Text(d.dateiname)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(d.dokumenttyp.anzeigeName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·").font(.caption).foregroundStyle(.tertiary)
                    Text(d.erstelltAm.formatted(date: .numeric, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if d.seitenanzahl > 1 {
                        Text("·").font(.caption).foregroundStyle(.tertiary)
                        Text("\(d.seitenanzahl) Seiten")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                pipelineBadge(d)
                    .padding(.top, 2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func pipelineBadge(_ d: GespeichertesDokument) -> some View {
        let (text, farbe) = pipelineStatus(d)
        HStack(spacing: 4) {
            Circle().fill(farbe).frame(width: 6, height: 6)
            Text(text).font(.caption2).foregroundStyle(farbe)
        }
    }

    private func pipelineStatus(_ d: GespeichertesDokument) -> (String, Color) {
        if d.rechnungId != nil { return ("Validiert & Rechnung erzeugt", .green) }
        if d.aiVorschlag != nil { return ("AI-Vorschlag vorhanden",       .orange) }
        if d.ocrVolltext != nil { return ("OCR vorhanden",                .blue) }
        return ("Kein OCR", .gray)
    }

    @ViewBuilder
    private func thumbnail(_ d: GespeichertesDokument) -> some View {
        if let bild = thumbnailBild(d) {
            Image(uiImage: bild)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            Image(systemName: "doc.text")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 48, height: 48)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func thumbnailBild(_ d: GespeichertesDokument) -> UIImage? {
        guard !d.thumbnailPfad.isEmpty,
              let url = try? DokumentAblageService.absoluterPfad(
                fuer: d.thumbnailPfad
              ),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Jahr+Monat-Gruppierung

    private struct Monatsgruppe {
        let schluessel: String   // "2026-04"
        let ueberschrift: String // "April 2026"
        let dokumente: [GespeichertesDokument]
    }

    private var monatsgruppen: [Monatsgruppe] {
        let dict = Dictionary(grouping: dokumente) { d -> String in
            monatsSchluessel(d.erstelltAm)
        }
        return dict
            .map { (key, liste) -> Monatsgruppe in
                Monatsgruppe(
                    schluessel: key,
                    ueberschrift: monatsUeberschrift(liste.first?.erstelltAm ?? Date()),
                    dokumente: liste.sorted { $0.erstelltAm > $1.erstelltAm }
                )
            }
            .sorted { $0.schluessel > $1.schluessel }
    }

    private func monatsSchluessel(_ datum: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        f.timeZone = TimeZone.current
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: datum)
    }

    private func monatsUeberschrift(_ datum: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        f.timeZone = TimeZone.current
        f.locale = Locale(identifier: "de_DE")
        return f.string(from: datum)
    }
}
