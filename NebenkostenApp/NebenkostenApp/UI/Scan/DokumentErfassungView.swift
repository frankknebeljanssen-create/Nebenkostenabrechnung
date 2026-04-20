//
//  DokumentErfassungView.swift
//  NebenkostenApp — UI/Scan
//
//  Nach-Scan-Sheet: Vorschau + Pflicht-Dokumenttyp + optionale
//  Metadaten (Versorger, Kontext, Betrag, Einheit). Beim Speichern
//  wird der Dateiname nach Schema neu gebaut, die Datei im Filesystem
//  umbenannt und das SwiftData-Model aktualisiert.
//
//  Pflichtfeld: Dokumenttyp. Alles andere ist optional — Pre-Fills
//  oder App-Vermutungen sind bewusst nicht vorgesehen (Strikte-Daten-
//  Regel, Task-1.1-Spec).
//

import SwiftUI
import SwiftData
import UIKit

struct DokumentErfassungView: View {
    @Bindable var dokument: GespeichertesDokument

    /// Einheits-Bezeichnungen der Ziel-Immobilie (für den Picker).
    /// Leer → Einheit-Picker nur mit "Objektweit".
    let einheitBezeichnungen: [String]

    /// Nach Speichern (Datei ist umbenannt, Model persistiert).
    let onFertig: () -> Void
    /// Bei "Verwerfen" — Caller muss Dokument + Datei entfernen.
    let onVerwerfen: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var typ: Dokumenttyp?
    @State private var versorger = ""
    @State private var kontext = ""
    @State private var betragText = ""
    @State private var einheitId: String?

    var body: some View {
        NavigationStack {
            Form {
                Section { vorschau }

                Section("Dokumenttyp (Pflicht)") {
                    Picker("Typ", selection: $typ) {
                        Text("— bitte wählen —").tag(Dokumenttyp?.none)
                        ForEach(Dokumenttyp.allCases, id: \.self) { t in
                            Text(t.anzeigeName).tag(Optional(t))
                        }
                    }
                }

                Section("Optional") {
                    TextField("Versorger", text: $versorger)
                        .textInputAutocapitalization(.words)
                    TextField("Kontext", text: $kontext)
                        .textInputAutocapitalization(.sentences)
                    HStack {
                        TextField("Betrag brutto", text: $betragText)
                            .keyboardType(.decimalPad)
                        Text("€").foregroundStyle(.secondary)
                    }
                    Picker("Einheit-Zuordnung", selection: $einheitId) {
                        Text("Objektweit").tag(String?.none)
                        ForEach(einheitBezeichnungen, id: \.self) { e in
                            Text(e).tag(Optional(e))
                        }
                    }
                }

                Section {
                    Text("Keine Pre-Fills — nur ausgefüllte Felder werden übernommen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Dokument erfassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Verwerfen", role: .destructive) {
                        onVerwerfen()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        speichern()
                    }
                    .disabled(typ == nil)
                }
            }
        }
    }

    // MARK: - Vorschau

    @ViewBuilder
    private var vorschau: some View {
        if let bild = thumbnailBild {
            HStack {
                Spacer()
                Image(uiImage: bild)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Spacer()
            }
            .listRowInsets(EdgeInsets())
            .padding(.vertical, 8)
        } else {
            HStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading) {
                    Text(dokument.dateiname)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text("Vorschau nicht verfügbar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var thumbnailBild: UIImage? {
        guard !dokument.thumbnailPfad.isEmpty,
              let url = try? DokumentAblageService.absoluterPfad(
                fuer: dokument.thumbnailPfad
              ),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Speichern

    private func speichern() {
        guard let typ else { return }

        dokument.dokumenttyp = typ
        dokument.versorger = leerZuNil(versorger)
        dokument.kontext = leerZuNil(kontext)
        dokument.einheitId = einheitId
        dokument.betragBrutto = parseBetrag()

        benenneDateiUm()

        try? modelContext.save()
        onFertig()
        dismiss()
    }

    /// Baut den Dateinamen nach Schema neu und verschiebt die Datei
    /// im Filesystem. Fehler sind nicht-fatal — die Metadaten sind
    /// im Model persistiert; nur der Dateiname bleibt dann beim
    /// ursprünglichen Import-Namen.
    private func benenneDateiUm() {
        guard let typ = dokument.dokumenttyp as Dokumenttyp? else { return }
        let eingabe = DateinameBuilder.Eingabe(
            datum: dokument.erstelltAm,
            dokumenttyp: typ,
            versorger: dokument.versorger,
            kontext: dokument.kontext,
            betragBrutto: dokument.betragBrutto,
            id: dokument.id
        )
        let neuerName = DateinameBuilder.build(from: eingabe)

        let alterRelPfad = dokument.dateipfadRelativ
        let teile = alterRelPfad.split(separator: "/").map(String.init)
        // Erwartetes Format: "Scans/YYYY/altername.ext"
        guard teile.count == 3,
              teile[0] == DokumentAblageService.scansUnterordner
        else { return }

        let jahr = teile[1]
        let neuerRelPfad = "\(DokumentAblageService.scansUnterordner)/\(jahr)/\(neuerName)"

        do {
            let alte = try DokumentAblageService.absoluterPfad(fuer: alterRelPfad)
            let neu  = try DokumentAblageService.absoluterPfad(fuer: neuerRelPfad)
            if alte != neu {
                if FileManager.default.fileExists(atPath: neu.path) {
                    try FileManager.default.removeItem(at: neu)
                }
                try FileManager.default.moveItem(at: alte, to: neu)
            }
            dokument.dateiname = neuerName
            dokument.dateipfadRelativ = neuerRelPfad
        } catch {
            #if DEBUG
            print("⚠️ Dateiname-Umbenennung fehlgeschlagen: \(error)")
            #endif
        }
    }

    private func leerZuNil(_ s: String) -> String? {
        let getrimmt = s.trimmingCharacters(in: .whitespaces)
        return getrimmt.isEmpty ? nil : getrimmt
    }

    private func parseBetrag() -> Decimal? {
        let getrimmt = betragText
            .replacingOccurrences(of: "€", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard !getrimmt.isEmpty else { return nil }
        let normalisiert = getrimmt.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalisiert)
    }
}
