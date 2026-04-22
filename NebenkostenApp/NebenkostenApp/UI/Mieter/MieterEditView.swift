//
//  MieterEditView.swift
//  NebenkostenApp — UI/Mieter
//

import SwiftUI
import SwiftData

struct MieterEditView: View {
    enum Modus {
        /// Neu-Anlegen; optional `vorauswahl` für den Einheit-Picker
        /// (wenn der Flow über eine bestimmte Einheit gestartet wurde).
        case neu(immobilie: Immobilie, vorauswahl: Wohneinheit?)
        case bearbeiten(Mietverhaeltnis)
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let modus: Modus

    @State private var mieterName: String
    @State private var mieterAnschrift: String
    @State private var mieterEmail: String
    @State private var mieterTyp: MieterTyp
    @State private var einheitID: UUID?
    @State private var einzugAm: Date
    @State private var istAusgezogen: Bool
    @State private var auszugAm: Date
    @State private var vorauszahlungText: String
    @State private var anzahlPersonen: Int

    @State private var zeigeLoeschen = false

    init(modus: Modus) {
        self.modus = modus
        switch modus {
        case .neu(_, let vorauswahl):
            _mieterName = State(initialValue: "")
            _mieterAnschrift = State(initialValue: "")
            _mieterEmail = State(initialValue: "")
            _mieterTyp = State(initialValue: .wohnungsmieter)
            _einheitID = State(initialValue: vorauswahl?.id)
            _einzugAm = State(initialValue: Date.ersterDesMonats)
            _istAusgezogen = State(initialValue: false)
            _auszugAm = State(initialValue: Date.ersterDesMonats)
            _vorauszahlungText = State(initialValue: "")
            _anzahlPersonen = State(initialValue: 1)
        case .bearbeiten(let mv):
            _mieterName = State(initialValue: mv.mieterName)
            _mieterAnschrift = State(initialValue: mv.mieterAnschrift)
            _mieterEmail = State(initialValue: mv.mieterEmail)
            _mieterTyp = State(initialValue: mv.mieterTyp)
            _einheitID = State(initialValue: mv.wohneinheit?.id)
            _einzugAm = State(initialValue: mv.einzugAm)
            _istAusgezogen = State(initialValue: mv.auszugAm != nil)
            _auszugAm = State(initialValue: mv.auszugAm ?? Date())
            _vorauszahlungText = State(
                initialValue: mv.vorauszahlungMonatEuro > 0
                    ? Self.formatBetrag(mv.vorauszahlungMonatEuro)
                    : ""
            )
            _anzahlPersonen = State(initialValue: mv.anzahlPersonen)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                mieterSektion
                einheitSektion
                mietverhaeltnisSektion
                vorauszahlungSektion
                if case .bearbeiten = modus {
                    Section {
                        Button("Mietverhältnis löschen", role: .destructive) {
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
            .alert(
                "Mietverhältnis löschen?",
                isPresented: $zeigeLoeschen,
                actions: {
                    Button("Abbrechen", role: .cancel) {}
                    Button("Löschen", role: .destructive) { loeschen() }
                },
                message: {
                    Text("Das Mietverhältnis wird unwiderruflich entfernt. Die Wohneinheit bleibt erhalten.")
                }
            )
        }
    }

    // MARK: - Sektionen

    private var mieterSektion: some View {
        Section("Mieter") {
            TextField("Name (Pflicht)", text: $mieterName)
                .textContentType(.name)
            TextField("Anschrift (optional)", text: $mieterAnschrift)
                .textContentType(.streetAddressLine1)
            TextField("E-Mail (optional)", text: $mieterEmail)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
            Picker("Typ", selection: $mieterTyp) {
                ForEach(MieterTyp.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var einheitSektion: some View {
        let einheiten = verfuegbareEinheiten
        if !einheiten.isEmpty {
            Section("Wohneinheit") {
                Picker("Wohneinheit", selection: $einheitID) {
                    Text("Bitte wählen…").tag(UUID?.none)
                    ForEach(einheiten) { e in
                        Text(einheitLabel(e)).tag(Optional(e.id))
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var mietverhaeltnisSektion: some View {
        Section("Zeitraum") {
            DatePicker("Einzug",
                       selection: $einzugAm,
                       displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "de_DE"))
            Toggle("Bereits ausgezogen", isOn: $istAusgezogen)
            if istAusgezogen {
                DatePicker("Auszug",
                           selection: $auszugAm,
                           in: einzugAm...,
                           displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "de_DE"))
            }
            Stepper(value: $anzahlPersonen, in: 1...20) {
                HStack {
                    Text("Anzahl Personen")
                    Spacer()
                    Text("\(anzahlPersonen)")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var vorauszahlungSektion: some View {
        Section("Nebenkosten-Vorauszahlung") {
            HStack {
                TextField("0,00", text: $vorauszahlungText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                Text("€ / Monat")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Validierung

    private var titel: String {
        switch modus {
        case .neu:        return "Neues Mietverhältnis"
        case .bearbeiten: return "Mietverhältnis"
        }
    }

    private var istGueltig: Bool {
        !mieterName.trimmingCharacters(in: .whitespaces).isEmpty
            && einheitID != nil
    }

    private var immobilieFuerPicker: Immobilie? {
        switch modus {
        case .neu(let immobilie, _): return immobilie
        case .bearbeiten(let mv):    return mv.wohneinheit?.immobilie
        }
    }

    private var verfuegbareEinheiten: [Wohneinheit] {
        (immobilieFuerPicker?.wohneinheiten ?? [])
            .sorted { $0.bezeichnung.localizedStandardCompare($1.bezeichnung) == .orderedAscending }
    }

    private func einheitLabel(_ e: Wohneinheit) -> String {
        let bez = e.bezeichnung.isEmpty ? "Unbenannt" : e.bezeichnung
        let nutzung = e.nutzungsart.rawValue.capitalized
        return "\(bez) · \(nutzung)"
    }

    // MARK: - Persistenz

    private func speichern() {
        let mv: Mietverhaeltnis
        switch modus {
        case .neu:
            mv = Mietverhaeltnis()
            modelContext.insert(mv)
        case .bearbeiten(let existing):
            mv = existing
        }

        mv.mieterName = mieterName.trimmingCharacters(in: .whitespaces)
        mv.mieterAnschrift = mieterAnschrift.trimmingCharacters(in: .whitespaces)
        mv.mieterEmail = mieterEmail.trimmingCharacters(in: .whitespaces)
        mv.mieterTyp = mieterTyp
        mv.einzugAm = einzugAm
        mv.auszugAm = istAusgezogen ? auszugAm : nil
        mv.anzahlPersonen = anzahlPersonen
        mv.vorauszahlungMonatEuro = Self.parseBetrag(vorauszahlungText) ?? 0

        if let id = einheitID,
           let einheit = verfuegbareEinheiten.first(where: { $0.id == id }) {
            mv.wohneinheit = einheit
        }

        try? modelContext.save()
        dismiss()
    }

    private func loeschen() {
        if case .bearbeiten(let mv) = modus {
            modelContext.delete(mv)
            try? modelContext.save()
            dismiss()
        }
    }

    // MARK: - Formatierung

    nonisolated private static func parseBetrag(_ text: String) -> Decimal? {
        let normalisiert = text
            .replacingOccurrences(of: ".", with: "")
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
