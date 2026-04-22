//
//  PeriodeEditView.swift
//  NebenkostenApp — UI/Abrechnungen
//
//  Bearbeitet eine Abrechnungsperiode (Von, Bis). `.neu`-Modus
//  legt eine weitere Periode an der Immobilie an. Abgeschlossene
//  Perioden lassen sich nicht editieren — `bearbeiten` guarded
//  gegen `abgeschlossen == true` mit einer Readonly-Ansicht.
//

import SwiftUI
import SwiftData

struct PeriodeEditView: View {
    enum Modus {
        case neu(immobilie: Immobilie)
        case bearbeiten(Abrechnungsperiode)
    }

    let modus: Modus

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var von: Date
    @State private var bis: Date

    init(modus: Modus) {
        self.modus = modus
        switch modus {
        case .neu:
            let start = Date.ersterDesMonats
            let endeBerechnet = Calendar(identifier: .gregorian)
                .date(byAdding: .year, value: 1, to: start)
                .flatMap { Calendar(identifier: .gregorian).date(byAdding: .day, value: -1, to: $0) }
                ?? start
            _von = State(initialValue: start)
            _bis = State(initialValue: endeBerechnet)
        case .bearbeiten(let p):
            _von = State(initialValue: p.von)
            _bis = State(initialValue: p.bis)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if istAbgeschlossen {
                    Section {
                        Text("Diese Periode ist abgeschlossen und kann nicht mehr bearbeitet werden.")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Zeitraum") {
                    DatePicker(
                        "Von",
                        selection: $von,
                        displayedComponents: .date
                    )
                    .disabled(istAbgeschlossen)
                    DatePicker(
                        "Bis",
                        selection: $bis,
                        displayedComponents: .date
                    )
                    .disabled(istAbgeschlossen)
                }
                if !istValide {
                    Section {
                        Text("\u{201E}Bis\u{201C} muss nach \u{201E}Von\u{201C} liegen.")
                            .foregroundStyle(DesignTokens.statusError)
                    }
                }
            }
            .sheetTitelHeader(titel)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetToolbar.abbrechen { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !istAbgeschlossen {
                        SheetToolbar.primaer(
                            titel: "Speichern",
                            istAktiv: istValide
                        ) { speichern() }
                    }
                }
            }
        }
    }

    // MARK: - State

    private var titel: String {
        switch modus {
        case .neu:        return "Neue Periode"
        case .bearbeiten: return "Periode bearbeiten"
        }
    }

    private var istAbgeschlossen: Bool {
        if case .bearbeiten(let p) = modus {
            return p.abgeschlossen
        }
        return false
    }

    private var istValide: Bool { von < bis }

    private func speichern() {
        switch modus {
        case .neu(let immobilie):
            let p = Abrechnungsperiode()
            p.von = von
            p.bis = bis
            p.immobilie = immobilie
            modelContext.insert(p)
        case .bearbeiten(let p):
            p.von = von
            p.bis = bis
        }
        try? modelContext.save()
        dismiss()
    }
}
