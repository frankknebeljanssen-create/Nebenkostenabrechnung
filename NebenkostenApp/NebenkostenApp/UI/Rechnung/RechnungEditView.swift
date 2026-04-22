//
//  RechnungEditView.swift
//  NebenkostenApp — UI/Rechnung
//

import SwiftUI
import SwiftData

struct RechnungEditView: View {
    enum Modus {
        case neu(immobilie: Immobilie)
        case bearbeiten(Rechnung)
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

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
                if case .bearbeiten(let r) = modus, let data = r.anhang {
                    BelegVorschauSheet(
                        anhang: data,
                        anhangTyp: r.anhangTyp,
                        titel: r.lieferant.isEmpty ? "Originalbeleg" : r.lieferant
                    )
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

    @ViewBuilder
    private var belegSektion: some View {
        if case .bearbeiten(let r) = modus {
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
