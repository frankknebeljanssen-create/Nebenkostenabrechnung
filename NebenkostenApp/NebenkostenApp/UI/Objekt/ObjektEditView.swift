//
//  ObjektEditView.swift
//  NebenkostenApp — UI/Objekt
//
//  Bearbeitet die Stammdaten einer bestehenden Immobilie (Adresse,
//  Ort, Gesamtflaeche, Heizungsart, Warmwasserbereitung,
//  Abrechnungsstart). Wird von der Stammdaten-Kachel als Sheet
//  geoeffnet. Keine Anlage — dafuer existiert `NeuesObjektSheet`
//  mit dem vollen gefuehrten Flow inkl. Wohneinheiten + Periode.
//

import SwiftUI
import SwiftData

struct ObjektEditView: View {
    @Bindable var immobilie: Immobilie

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var adresse: String
    @State private var ort: String
    @State private var gesamtflaecheText: String
    @State private var heizungsart: Heizungsart
    @State private var warmwasser: Warmwasserbereitung
    @State private var startMonat: Int
    @State private var startTag: Int

    init(immobilie: Immobilie) {
        self._immobilie = Bindable(wrappedValue: immobilie)
        _adresse = State(initialValue: immobilie.adresse)
        _ort = State(initialValue: immobilie.ort)
        _gesamtflaecheText = State(initialValue: Self.formatFlaeche(immobilie.gesamtflaecheM2))
        _heizungsart = State(initialValue: immobilie.heizungsart)
        _warmwasser = State(initialValue: immobilie.warmwasserbereitung)
        _startMonat = State(initialValue: immobilie.abrechnungsstartMonat)
        _startTag = State(initialValue: immobilie.abrechnungsstartTag)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Adresse") {
                    TextField("Straße und Hausnummer", text: $adresse)
                        .textInputAutocapitalization(.words)
                    TextField("PLZ und Ort", text: $ort)
                        .textInputAutocapitalization(.words)
                }
                Section("Fläche") {
                    HStack {
                        TextField("Gesamtfläche", text: $gesamtflaecheText)
                            .keyboardType(.decimalPad)
                        Text("m²").foregroundStyle(.secondary)
                    }
                }
                Section("Heizung") {
                    Picker("Heizungsart", selection: $heizungsart) {
                        ForEach(Heizungsart.allCases, id: \.self) { h in
                            Text(h.rawValue).tag(h)
                        }
                    }
                    Picker("Warmwasser", selection: $warmwasser) {
                        ForEach(Warmwasserbereitung.allCases, id: \.self) { w in
                            Text(w.rawValue).tag(w)
                        }
                    }
                }
                Section("Abrechnungsjahr — Startdatum") {
                    Picker("Monat", selection: $startMonat) {
                        ForEach(1...12, id: \.self) { m in
                            Text(monatName(m)).tag(m)
                        }
                    }
                    Stepper(value: $startTag, in: 1...28) {
                        HStack {
                            Text("Tag")
                            Spacer()
                            Text("\(startTag).")
                                .appFont(AppFont.monoCaption())
                        }
                    }
                }
            }
            .navigationTitle("Objekt bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
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

    // MARK: - Speichern

    private var istValide: Bool {
        !adresse.trimmingCharacters(in: .whitespaces).isEmpty
            && parseFlaeche() > 0
    }

    private func speichern() {
        immobilie.adresse = adresse.trimmingCharacters(in: .whitespaces)
        immobilie.ort = ort.trimmingCharacters(in: .whitespaces)
        immobilie.gesamtflaecheM2 = parseFlaeche()
        immobilie.heizungsart = heizungsart
        immobilie.warmwasserbereitung = warmwasser
        immobilie.abrechnungsstartMonat = startMonat
        immobilie.abrechnungsstartTag = startTag
        try? modelContext.save()
        dismiss()
    }

    // MARK: - Helper

    private func parseFlaeche() -> Decimal {
        let normalisiert = gesamtflaecheText
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

    private func monatName(_ monat: Int) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        let monate = f.monthSymbols ?? []
        guard monat >= 1, monat <= 12, monate.count >= 12 else { return "\(monat)" }
        return monate[monat - 1]
    }
}
