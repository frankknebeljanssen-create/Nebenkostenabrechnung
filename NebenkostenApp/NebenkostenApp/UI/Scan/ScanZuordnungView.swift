//
//  ScanZuordnungView.swift
//  NebenkostenApp — UI/Scan
//
//  Nach dem Import: "Wozu gehört dieser Scan?" — Picker für Rechnung
//  oder Zählerstand (oder "Ohne Zuordnung"). Setzt die Relation am
//  GespeichertesDokument und speichert.
//

import SwiftUI
import SwiftData

struct ScanZuordnungView: View {
    @Bindable var dokument: GespeichertesDokument
    let onFertig: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Rechnung.rechnungsdatum, order: .reverse)
    private var rechnungen: [Rechnung]

    @Query(sort: \Zaehlerstand.ablesedatum, order: .reverse)
    private var staende: [Zaehlerstand]

    @State private var modus: Modus = .ohne

    enum Modus: Hashable {
        case ohne
        case rechnung
        case zaehlerstand
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    thumbnailZeile
                    datenZeile
                }

                Section("Wozu gehört dieser Scan?") {
                    Picker("Zuordnung", selection: $modus) {
                        Text("Ohne Zuordnung").tag(Modus.ohne)
                        Text("Zu Rechnung").tag(Modus.rechnung)
                        Text("Zu Zählerstand").tag(Modus.zaehlerstand)
                    }
                    .pickerStyle(.segmented)
                }

                switch modus {
                case .ohne:
                    Section {
                        Text("Das Dokument erscheint nur im Dokumente-Tab.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                case .rechnung:
                    Section("Rechnung auswählen") {
                        if rechnungen.isEmpty {
                            Text("Noch keine Rechnungen angelegt.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(rechnungen) { r in
                                Button {
                                    dokument.rechnung = r
                                    dokument.zaehlerstand = nil
                                    speichereUndBeende()
                                } label: {
                                    rechnungZeile(r)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                case .zaehlerstand:
                    Section("Zählerstand auswählen") {
                        if staende.isEmpty {
                            Text("Noch keine Zählerstände erfasst.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(staende) { s in
                                Button {
                                    dokument.zaehlerstand = s
                                    dokument.rechnung = nil
                                    speichereUndBeende()
                                } label: {
                                    standZeile(s)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Wozu gehört dieser Scan?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Später") {
                        speichereUndBeende()
                    }
                }
                if modus == .ohne {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig") {
                            dokument.rechnung = nil
                            dokument.zaehlerstand = nil
                            speichereUndBeende()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Zeilen

    @ViewBuilder
    private var thumbnailZeile: some View {
        HStack(spacing: 12) {
            if let bild = thumbnailBild {
                Image(uiImage: bild)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "doc.text")
                    .font(.title)
                    .foregroundStyle(.secondary)
                    .frame(width: 64, height: 64)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(dokument.dateiname.components(separatedBy: "/").last ?? "")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(quelleName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var datenZeile: some View {
        HStack {
            Text("\(dokument.seitenAnzahl) Seite\(dokument.seitenAnzahl == 1 ? "" : "n")")
                .font(.caption)
            Spacer()
            Text(groesseFormatiert(dokument.dateigroesseBytes))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func rechnungZeile(_ r: Rechnung) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(r.lieferant.isEmpty ? "Ohne Lieferant" : r.lieferant)
                    .font(.callout.weight(.medium))
                Text(r.rechnungsdatum.formatted(date: .numeric, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(betragFormatiert(r.betragBruttoEuro))
                .font(.caption.monospacedDigit())
        }
        .contentShape(Rectangle())
    }

    private func standZeile(_ s: Zaehlerstand) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(s.zaehler?.bezeichnung ?? "Zähler")
                    .font(.callout.weight(.medium))
                Text(s.ablesedatum.formatted(date: .numeric, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(NSDecimalNumber(decimal: s.stand).stringValue) \(s.zaehler?.einheit ?? "")")
                .font(.caption.monospacedDigit())
        }
        .contentShape(Rectangle())
    }

    // MARK: - Helper

    private var thumbnailBild: UIImage? {
        guard !dokument.thumbnailPfad.isEmpty,
              let url = try? DokumentAblageService.absoluterPfad(fuer: dokument.thumbnailPfad),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return UIImage(data: data)
    }

    private var quelleName: String {
        switch dokument.quelle {
        case .kamera: return "Kamera-Scan"
        case .galerie: return "Aus Fotos"
        case .datei: return "Datei-Import"
        }
    }

    private func speichereUndBeende() {
        try? modelContext.save()
        onFertig()
        dismiss()
    }

    private func betragFormatiert(_ d: Decimal) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = "EUR"
        nf.locale = Locale(identifier: "de_DE")
        return nf.string(from: NSDecimalNumber(decimal: d)) ?? "\(d) €"
    }

    private func groesseFormatiert(_ bytes: Int) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f.string(fromByteCount: Int64(bytes))
    }
}
