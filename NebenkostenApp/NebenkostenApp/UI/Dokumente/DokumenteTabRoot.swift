//
//  DokumenteTabRoot.swift
//  NebenkostenApp — UI/Dokumente
//
//  Dokumenten-Archiv: Thumbnail-Liste aller GespeichertesDokument-
//  Entities, gruppiert nach Zugehörigkeit (Rechnungen / Zählerstände /
//  Ohne Zuordnung). Tap öffnet den QuickLook-Viewer, Swipe löscht
//  oder wechselt die Zuordnung. Prominenter "+"-Button öffnet
//  ScanEntryView.
//

import SwiftUI
import SwiftData
import UIKit

struct DokumenteTabRoot: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \GespeichertesDokument.erstelltAm, order: .reverse)
    private var dokumente: [GespeichertesDokument]

    @State private var zeigeScan = false
    @State private var vorschauURL: VorschauHost?

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
            .sheet(item: $vorschauURL) { host in
                QuickLookVorschau(url: host.url)
                    .ignoresSafeArea()
            }
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
            Text("Tippen Sie auf +, um eine Rechnung oder einen Zählerstand zu scannen.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                zeigeScan = true
            } label: {
                Label("Dokument scannen", systemImage: "plus.circle.fill")
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
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                gruppenCard(
                    titel: "Alle Dokumente",
                    symbol: "doc.on.doc.fill",
                    liste: dokumente
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func gruppenCard(
        titel: String,
        symbol: String,
        liste: [GespeichertesDokument]
    ) -> some View {
        Group {
            if liste.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: symbol)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.tint)
                            .frame(width: 22)
                        Text("\(titel) (\(liste.count))")
                            .font(.callout.weight(.semibold))
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    Divider().padding(.leading, 14)

                    VStack(spacing: 0) {
                        ForEach(Array(liste.enumerated()), id: \.element.id) { idx, d in
                            dokumentZeile(d)
                            if idx < liste.count - 1 {
                                Divider().padding(.leading, 14)
                            }
                        }
                    }
                    .padding(.bottom, 4)
                }
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func dokumentZeile(_ d: GespeichertesDokument) -> some View {
        HStack(alignment: .center, spacing: 12) {
            thumbnail(d)

            VStack(alignment: .leading, spacing: 2) {
                Text(d.dateiname.components(separatedBy: "/").last ?? "—")
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(d.erstelltAm.formatted(date: .numeric, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·").font(.caption).foregroundStyle(.tertiary)
                    Text(groesse(d.dateigroesseBytes))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if d.seitenanzahl > 1 {
                        Text("·").font(.caption).foregroundStyle(.tertiary)
                        Text("\(d.seitenanzahl) Seiten")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Menu {
                Button {
                    oeffne(d)
                } label: {
                    Label("Vorschau", systemImage: "eye")
                }
                Divider()
                Button(role: .destructive) {
                    DokumentAblageService.loesche(d, context: modelContext)
                    try? modelContext.save()
                } label: {
                    Label("Löschen", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            oeffne(d)
        }
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

    // MARK: - QuickLook

    private func oeffne(_ d: GespeichertesDokument) {
        guard let url = try? DokumentAblageService.absoluterPfad(fuer: d.dateipfadRelativ),
              FileManager.default.fileExists(atPath: url.path) else { return }
        vorschauURL = VorschauHost(url: url)
    }

    private func thumbnailBild(_ d: GespeichertesDokument) -> UIImage? {
        guard !d.thumbnailPfad.isEmpty,
              let url = try? DokumentAblageService.absoluterPfad(fuer: d.thumbnailPfad),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return UIImage(data: data)
    }

    private func groesse(_ bytes: Int) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f.string(fromByteCount: Int64(bytes))
    }
}

/// Identifiable-Wrapper um URL, damit `.sheet(item:)` funktioniert.
private struct VorschauHost: Identifiable {
    let url: URL
    var id: String { url.path }
}
