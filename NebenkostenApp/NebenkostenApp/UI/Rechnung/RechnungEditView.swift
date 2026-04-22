//
//  RechnungEditView.swift
//  NebenkostenApp — UI/Rechnung
//

import SwiftUI
import SwiftData
import UIKit

struct RechnungEditView: View {
    enum Modus {
        case neu(immobilie: Immobilie)
        case bearbeiten(Rechnung)
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Alle Dokumente — fuer den Scan-Lookup oben im Form (Beleg-
    /// Foto aus `GespeichertesDokument`, verknuepft via
    /// `dokument.rechnungId == rechnung.id`). Frueher wurde nur
    /// `rechnung.anhang: Data?` angezeigt; das bleibt als Fallback.
    @Query private var alleDokumente: [GespeichertesDokument]

    let modus: Modus

    @State private var lieferant: String
    @State private var rechnungsnummer: String
    @State private var rechnungsdatum: Date
    @State private var leistungVon: Date
    @State private var leistungBis: Date
    @State private var betragText: String
    @State private var lohnanteilAktiv: Bool
    @State private var lohnanteilText: String
    @State private var kostenartID: UUID?
    @State private var notizen: String
    @State private var geprueft: Bool

    @State private var zeigeLoeschen = false
    @State private var zeigeBelegVollbild = false

    init(modus: Modus) {
        self.modus = modus
        switch modus {
        case .neu:
            let heute = Date()
            _lieferant = State(initialValue: "")
            _rechnungsnummer = State(initialValue: "")
            _rechnungsdatum = State(initialValue: heute)
            _leistungVon = State(initialValue: heute)
            _leistungBis = State(initialValue: heute)
            _betragText = State(initialValue: "")
            _lohnanteilAktiv = State(initialValue: false)
            _lohnanteilText = State(initialValue: "")
            _kostenartID = State(initialValue: nil)
            _notizen = State(initialValue: "")
            _geprueft = State(initialValue: false)
        case .bearbeiten(let r):
            _lieferant = State(initialValue: r.lieferant)
            _rechnungsnummer = State(initialValue: r.rechnungsnummer)
            _rechnungsdatum = State(initialValue: r.rechnungsdatum)
            _leistungVon = State(initialValue: r.leistungVon)
            _leistungBis = State(initialValue: r.leistungBis)
            _betragText = State(initialValue: Self.formatBetrag(r.betragBruttoEuro))
            _lohnanteilAktiv = State(initialValue: r.lohnanteilBruttoEuro != nil)
            _lohnanteilText = State(initialValue: r.lohnanteilBruttoEuro.map(Self.formatBetrag) ?? "")
            _kostenartID = State(initialValue: r.kostenart?.id)
            _notizen = State(initialValue: r.extraktionsNotizen)
            _geprueft = State(initialValue: r.geprueft)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if case .bearbeiten = modus {
                    belegSektion
                }
                lieferantSektion
                zeitraumSektion
                betragSektion
                kostenartSektion
                notizSektion
                geprueftSektion
                if case .bearbeiten = modus {
                    Section {
                        Button("Rechnung löschen", role: .destructive) {
                            zeigeLoeschen = true
                        }
                    }
                }
            }
            .sheetTitelHeader(titel)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetToolbar.abbrechen { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    SheetToolbar.primaer(
                        titel: "Speichern",
                        istAktiv: istGueltig
                    ) { speichern() }
                }
            }
            .keyboardFertigButton()
            .sheet(isPresented: $zeigeBelegVollbild) {
                if case .bearbeiten(let r) = modus {
                    if let url = verknuepftesDokumentURL(fuer: r) {
                        // Scan-Pfad: PDF aus DokumentAblageService.
                        NavigationStack {
                            PDFVorschauView(url: url)
                                .ignoresSafeArea(edges: .bottom)
                                .navigationTitle(r.lieferant.isEmpty ? "Originalbeleg" : r.lieferant)
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItem(placement: .cancellationAction) {
                                        SheetToolbar.abbrechen(titel: "Schließen") {
                                            zeigeBelegVollbild = false
                                        }
                                    }
                                }
                        }
                    } else if let data = r.anhang {
                        // Legacy-Pfad: direkter `Rechnung.anhang`.
                        BelegVorschauSheet(
                            anhang: data,
                            anhangTyp: r.anhangTyp,
                            titel: r.lieferant.isEmpty ? "Originalbeleg" : r.lieferant
                        )
                    }
                }
            }
            .alert(
                "Rechnung löschen?",
                isPresented: $zeigeLoeschen,
                actions: {
                    Button("Abbrechen", role: .cancel) {}
                    Button("Löschen", role: .destructive) { loeschen() }
                },
                message: {
                    Text("Die Rechnung wird unwiderruflich entfernt.")
                }
            )
        }
    }

    // MARK: - Beleg-Sektion

    /// Oben im Edit-Sheet: Beleg-Foto.
    ///   1. Wenn ein `GespeichertesDokument` via `rechnungId`
    ///      verknuepft ist, wird sein Thumbnail angezeigt.
    ///      Tap oeffnet das volle PDF.
    ///   2. Sonst faellt die Sektion auf den alten
    ///      `rechnung.anhang`-Pfad zurueck (BelegVorschauCard).
    ///   3. Wenn weder Dokument noch anhang da sind, rendert die
    ///      Section gar nichts — kein Foto-Platzhalter (Design-
    ///      Entscheidung aus Stufe 2).
    @ViewBuilder
    private var belegSektion: some View {
        if case .bearbeiten(let r) = modus {
            if let bild = verknuepftesDokumentThumbnail(fuer: r) {
                Section {
                    Image(uiImage: bild)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(DesignTokens.separator, lineWidth: 0.5)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { zeigeBelegVollbild = true }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                } header: {
                    Text("Originalbeleg")
                } footer: {
                    Text("Tippen zum Vergrößern")
                        .appFont(AppFont.Basis.smallCaption())
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            } else if r.anhang != nil {
                Section {
                    BelegVorschauCard(
                        anhang: r.anhang,
                        anhangTyp: r.anhangTyp,
                        onTap: {
                            if r.anhang != nil {
                                zeigeBelegVollbild = true
                            }
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Originalbeleg")
                }
            }
        }
    }

    // MARK: - Verknuepftes Scan-Dokument

    private func verknuepftesDokument(fuer rechnung: Rechnung) -> GespeichertesDokument? {
        alleDokumente.first { $0.rechnungId == rechnung.id }
    }

    private func verknuepftesDokumentThumbnail(fuer r: Rechnung) -> UIImage? {
        guard let doc = verknuepftesDokument(fuer: r),
              !doc.thumbnailPfad.isEmpty,
              let url = try? DokumentAblageService.absoluterPfad(fuer: doc.thumbnailPfad),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return UIImage(data: data)
    }

    private func verknuepftesDokumentURL(fuer r: Rechnung) -> URL? {
        guard let doc = verknuepftesDokument(fuer: r) else { return nil }
        return try? DokumentAblageService.absoluterPfad(fuer: doc.dateipfadRelativ)
    }

    // MARK: - Sektionen

    private var lieferantSektion: some View {
        Section("Lieferant") {
            TextField("z.B. GASAG", text: $lieferant)
            TextField("Rechnungsnummer", text: $rechnungsnummer)
                .textInputAutocapitalization(.never)
        }
    }

    private var zeitraumSektion: some View {
        Section("Zeitraum") {
            DatePicker("Rechnungsdatum",
                       selection: $rechnungsdatum,
                       displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "de_DE"))
            DatePicker("Leistung von",
                       selection: $leistungVon,
                       displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "de_DE"))
            DatePicker("Leistung bis",
                       selection: $leistungBis,
                       in: leistungVon...,
                       displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "de_DE"))
        }
    }

    private var betragSektion: some View {
        Section("Betrag (brutto)") {
            HStack {
                TextField("0,00", text: $betragText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                Text("€").foregroundStyle(.secondary)
            }
            Toggle("Lohnanteil ausgewiesen (§ 35a)", isOn: $lohnanteilAktiv)
            if lohnanteilAktiv {
                HStack {
                    TextField("0,00", text: $lohnanteilText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                    Text("€").foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var kostenartSektion: some View {
        if let kostenarten = immobilieFuerPicker?.kostenarten, !kostenarten.isEmpty {
            Section("Kostenart") {
                Picker("Kostenart", selection: $kostenartID) {
                    Text("Bitte wählen…").tag(UUID?.none)
                    ForEach(sortierteAktive(kostenarten)) { ka in
                        Text(ka.bezeichnung).tag(Optional(ka.id))
                    }
                }
                .pickerStyle(.menu)
            }
        } else {
            Section("Kostenart") {
                Text("Keine Kostenarten angelegt.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var notizSektion: some View {
        Section("Notizen (optional)") {
            TextField("z.B. Nachzahlung 2024", text: $notizen, axis: .vertical)
                .lineLimit(1...4)
        }
    }

    private var geprueftSektion: some View {
        Section("Status") {
            Toggle("Als geprüft markieren", isOn: $geprueft)
        }
    }

    // MARK: - Validierung

    private var titel: String {
        switch modus {
        case .neu:        return "Neue Rechnung"
        case .bearbeiten: return "Rechnung"
        }
    }

    private var istGueltig: Bool {
        !lieferant.trimmingCharacters(in: .whitespaces).isEmpty
            && !rechnungsnummer.trimmingCharacters(in: .whitespaces).isEmpty
            && (betragDecimal ?? 0) > 0
            && kostenartID != nil
    }

    private var betragDecimal: Decimal? {
        Self.parseBetrag(betragText)
    }

    private var lohnanteilDecimal: Decimal? {
        guard lohnanteilAktiv else { return nil }
        return Self.parseBetrag(lohnanteilText)
    }

    private var immobilieFuerPicker: Immobilie? {
        switch modus {
        case .neu(let immobilie): return immobilie
        case .bearbeiten(let r):  return r.immobilie
        }
    }

    private func sortierteAktive(_ list: [Kostenart]) -> [Kostenart] {
        list.filter { $0.aktiv }
            .sorted { lhs, rhs in
                if lhs.sortierung != rhs.sortierung { return lhs.sortierung < rhs.sortierung }
                return lhs.bezeichnung.localizedStandardCompare(rhs.bezeichnung) == .orderedAscending
            }
    }

    // MARK: - Persistenz

    private func speichern() {
        let r: Rechnung
        switch modus {
        case .neu(let immobilie):
            r = Rechnung()
            r.immobilie = immobilie
            modelContext.insert(r)
        case .bearbeiten(let existing):
            r = existing
        }

        r.lieferant = lieferant.trimmingCharacters(in: .whitespaces)
        r.rechnungsnummer = rechnungsnummer.trimmingCharacters(in: .whitespaces)
        r.rechnungsdatum = rechnungsdatum
        r.leistungVon = leistungVon
        r.leistungBis = leistungBis
        r.betragBruttoEuro = betragDecimal ?? 0
        r.lohnanteilBruttoEuro = lohnanteilDecimal
        r.extraktionsNotizen = notizen.trimmingCharacters(in: .whitespaces)
        r.geprueft = geprueft

        if let id = kostenartID,
           let kostenart = immobilieFuerPicker?.kostenarten?.first(where: { $0.id == id }) {
            r.kostenart = kostenart
        }

        try? modelContext.save()
        dismiss()
    }

    private func loeschen() {
        if case .bearbeiten(let r) = modus {
            modelContext.delete(r)
            try? modelContext.save()
            dismiss()
        }
    }

    // MARK: - Helfer

    nonisolated private static func parseBetrag(_ text: String) -> Decimal? {
        let normalisiert = text
            .replacingOccurrences(of: ".", with: "")   // Tausendertrennzeichen
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard !normalisiert.isEmpty else { return nil }
        return Decimal(string: normalisiert)
    }

    nonisolated private static func formatBetrag(_ betrag: Decimal) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.locale = Locale(identifier: "de_DE")
        nf.minimumFractionDigits = 2
        nf.maximumFractionDigits = 2
        return nf.string(from: NSDecimalNumber(decimal: betrag)) ?? "\(betrag)"
    }
}
