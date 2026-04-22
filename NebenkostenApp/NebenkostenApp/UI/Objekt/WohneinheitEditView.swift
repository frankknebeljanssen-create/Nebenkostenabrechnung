//
//  WohneinheitEditView.swift
//  NebenkostenApp — UI/Objekt
//
//  Bearbeitet eine bestehende Wohneinheit (Bezeichnung, Flaeche,
//  Nutzungsart, Selbstnutzung). `.neu`-Modus legt eine neue
//  Einheit an derselben Immobilie an — beide Modi teilen die
//  Form, nur Speichern-Logik und Toolbar-Titel unterscheiden sich.
//

import SwiftUI
import SwiftData

struct WohneinheitEditView: View {
    enum Modus {
        case neu(immobilie: Immobilie)
        case bearbeiten(Wohneinheit)
    }

    let modus: Modus

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var bezeichnung: String
    @State private var flaecheText: String
    @State private var nutzungsart: Nutzungsart
    @State private var selbstnutzung: Bool

    init(modus: Modus) {
        self.modus = modus
        switch modus {
        case .neu:
            _bezeichnung = State(initialValue: "")
            _flaecheText = State(initialValue: "")
            _nutzungsart = State(initialValue: .wohnung)
            _selbstnutzung = State(initialValue: false)
        case .bearbeiten(let we):
            _bezeichnung = State(initialValue: we.bezeichnung)
            _flaecheText = State(initialValue: Self.formatFlaeche(we.flaecheM2))
            _nutzungsart = State(initialValue: we.nutzungsart)
            _selbstnutzung = State(initialValue: we.selbstnutzung)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Einheit") {
                    TextField("Bezeichnung (z.B. EG, OG, Keller)", text: $bezeichnung)
                        .textInputAutocapitalization(.characters)
                    HStack {
                        TextField("Fläche", text: $flaecheText)
                            .keyboardType(.decimalPad)
                        Text("m²").foregroundStyle(.secondary)
                    }
                }
                Section("Nutzung") {
                    Picker("Nutzungsart", selection: $nutzungsart) {
                        Text("Wohnung").tag(Nutzungsart.wohnung)
                        Text("Einliegerwohnung").tag(Nutzungsart.einliegerwohnung)
                        Text("Gewerbe").tag(Nutzungsart.gewerbe)
                        Text("Leerstand").tag(Nutzungsart.leerstand)
                    }
                    Toggle("Selbstnutzung (Vermieter wohnt hier)", isOn: $selbstnutzung)
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
                        istAktiv: istValide
                    ) { speichern() }
                }
            }
            .keyboardFertigButton()
        }
    }

    // MARK: - State

    private var titel: String {
        switch modus {
        case .neu:        return "Neue Einheit"
        case .bearbeiten: return "Einheit bearbeiten"
        }
    }

    private var istValide: Bool {
        !bezeichnung.trimmingCharacters(in: .whitespaces).isEmpty
            && parseFlaeche() >= 0
    }

    private func speichern() {
        let flaeche = parseFlaeche()
        switch modus {
        case .neu(let immobilie):
            let we = Wohneinheit()
            we.bezeichnung = bezeichnung.trimmingCharacters(in: .whitespaces)
            we.flaecheM2 = flaeche
            we.nutzungsart = nutzungsart
            we.selbstnutzung = selbstnutzung
            we.immobilie = immobilie
            modelContext.insert(we)
        case .bearbeiten(let we):
            we.bezeichnung = bezeichnung.trimmingCharacters(in: .whitespaces)
            we.flaecheM2 = flaeche
            we.nutzungsart = nutzungsart
            we.selbstnutzung = selbstnutzung
        }
        try? modelContext.save()
        dismiss()
    }

    // MARK: - Helper

    private func parseFlaeche() -> Decimal {
        let normalisiert = flaecheText
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        return Decimal(string: normalisiert) ?? 0
    }

    private static func formatFlaeche(_ wert: Decimal) -> String {
        guard wert > 0 else { return "" }
        let nf = NumberFormatter()
        nf.locale = Locale(identifier: "de_DE")
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 2
        return nf.string(from: NSDecimalNumber(decimal: wert)) ?? ""
    }
}
