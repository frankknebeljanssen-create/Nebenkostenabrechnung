//
//  UebernahmeSheet.swift
//  NebenkostenApp — UI/Validierung
//
//  Ebene-3-Übergang: AI-Vorschlag → validierte Rechnung-Entity.
//
//  Der User bekommt die Felder aus dem AIVorschlag nochmal zur Kontrolle,
//  wählt die Kostenart aus den vorhandenen Kostenarten der Immobilie
//  und bestätigt. Erst dann wird die Rechnung angelegt und
//  `GespeichertesDokument.rechnungId` gesetzt. Das ist die einzige
//  Stelle, an der Ebene-2-Vorschläge zu bindenden Daten werden.
//

import SwiftUI
import SwiftData

struct UebernahmeSheet: View {
    @Bindable var dokument: GespeichertesDokument
    let immobilie: Immobilie?
    let onFertig: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var gewaehlteKostenartID: UUID?
    @State private var versorger: String = ""
    @State private var rechnungsNr: String = ""
    @State private var betragText: String = ""
    @State private var rechnungsdatum: Date = Date()
    @State private var leistungVon: Date = Date()
    @State private var leistungBis: Date = Date()
    @State private var fehler: String?

    var body: some View {
        NavigationStack {
            Form {
                hinweisSektion
                felderSektion
                kostenartSektion
            }
            .sheetTitelHeader("Als Rechnung übernehmen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetToolbar.abbrechen { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    SheetToolbar.primaer(
                        titel: "Übernehmen",
                        istAktiv: istGueltig
                    ) { uebernehmen() }
                }
            }
            .keyboardFertigButton()
            .onAppear(perform: initialisiereFelder)
            .alert(
                "Fehler",
                isPresented: .init(
                    get: { fehler != nil },
                    set: { if !$0 { fehler = nil } }
                ),
                actions: { Button("OK", role: .cancel) {} },
                message: { Text(fehler ?? "") }
            )
        }
    }

    // MARK: - Sektionen

    private var hinweisSektion: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kontrolle vor Übernahme")
                        .font(.callout.weight(.semibold))
                    Text("Die Felder kommen aus dem AI-Vorschlag — bitte prüfen, ggf. korrigieren, dann übernehmen. Ab hier gilt der Wert als validiert.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.tint)
            }
        }
    }

    private var felderSektion: some View {
        Section("Rechnung") {
            TextField("Versorger", text: $versorger)
                .textInputAutocapitalization(.words)
            TextField("Rechnungs-Nr.", text: $rechnungsNr)
                .textInputAutocapitalization(.never)
            HStack {
                TextField("Betrag brutto", text: $betragText)
                    .keyboardType(.decimalPad)
                Text("€").foregroundStyle(.secondary)
            }
            DatePicker("Rechnungsdatum", selection: $rechnungsdatum, displayedComponents: .date)
            DatePicker("Leistung von", selection: $leistungVon, displayedComponents: .date)
            DatePicker("Leistung bis", selection: $leistungBis, displayedComponents: .date)
        }
    }

    private var kostenartSektion: some View {
        Section("Kostenart") {
            let liste = kostenarten
            if liste.isEmpty {
                Text("Keine Kostenarten an dieser Immobilie.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Kostenart", selection: $gewaehlteKostenartID) {
                    Text("— bitte wählen —").tag(UUID?.none)
                    ForEach(liste) { k in
                        Text(k.bezeichnung).tag(Optional(k.id))
                    }
                }
            }
        }
    }

    // MARK: - Init + Gültigkeit

    private var kostenarten: [Kostenart] {
        (immobilie?.kostenarten ?? [])
            .filter(\.aktiv)
            .sorted { $0.sortierung < $1.sortierung }
    }

    private var istGueltig: Bool {
        guard immobilie != nil else { return false }
        guard gewaehlteKostenartID != nil else { return false }
        guard parseBetrag() != nil else { return false }
        return true
    }

    private func initialisiereFelder() {
        guard let v = dokument.aiVorschlag else { return }
        versorger = v.versorger ?? ""
        rechnungsNr = v.rechnungsNr ?? ""
        if let b = v.betragBrutto {
            betragText = NSDecimalNumber(decimal: b).stringValue
        }
        if let d = v.dokumentDatum { rechnungsdatum = d }
        if let s = v.leistungszeitraumStart { leistungVon = s }
        if let e = v.leistungszeitraumEnde { leistungBis = e }

        if let vorschlag = v.kostenartVorschlag {
            let kandidat = kostenarten.first(where: { k in
                k.bezeichnung.localizedCaseInsensitiveContains(vorschlag)
                    || vorschlag.localizedCaseInsensitiveContains(k.bezeichnung)
            })
            gewaehlteKostenartID = kandidat?.id
        }
    }

    private func parseBetrag() -> Decimal? {
        let getrimmt = betragText
            .replacingOccurrences(of: "€", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard !getrimmt.isEmpty else { return nil }
        let norm = getrimmt.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: norm)
    }

    // MARK: - Übernahme

    private func uebernehmen() {
        guard let immobilie else {
            fehler = "Keine Immobilie aktiv."
            return
        }
        guard let kostenartID = gewaehlteKostenartID,
              let kostenart = kostenarten.first(where: { $0.id == kostenartID })
        else {
            fehler = "Bitte Kostenart wählen."
            return
        }
        guard let betrag = parseBetrag() else {
            fehler = "Betrag ungültig."
            return
        }

        let r = Rechnung()
        r.immobilie = immobilie
        r.kostenart = kostenart
        r.lieferant = versorger.trimmingCharacters(in: .whitespaces)
        r.rechnungsnummer = rechnungsNr.trimmingCharacters(in: .whitespaces)
        r.rechnungsdatum = rechnungsdatum
        r.leistungVon = leistungVon
        r.leistungBis = leistungBis
        r.betragBruttoEuro = betrag
        r.geprueft = false

        modelContext.insert(r)
        dokument.rechnungId = r.id

        do {
            try modelContext.save()
            onFertig()
            dismiss()
        } catch {
            fehler = error.localizedDescription
        }
    }
}
