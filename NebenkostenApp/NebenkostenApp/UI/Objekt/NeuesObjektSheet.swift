//
//  NeuesObjektSheet.swift
//  NebenkostenApp — UI/Objekt
//
//  Sheet zum Anlegen eines neuen Objekts inklusive seiner Wohneinheiten.
//  Die Formular-Abschnitte werden später in Task 0.13 (Onboarding)
//  wiederverwendet.
//

import SwiftUI
import SwiftData

struct NeuesObjektSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let onAngelegt: (Immobilie) -> Void

    @State private var adresse: String = ""
    @State private var ort: String = ""
    @State private var gesamtflaecheText: String = ""
    @State private var abrechnungsstartMonat: Int = 1
    @State private var abrechnungsstartTag: Int = 1
    @State private var heizungsart: Heizungsart = .gasZentral
    @State private var warmwasser: Warmwasserbereitung = .zentralMitHeizung
    @State private var wohneinheiten: [EinheitEntwurf] = [EinheitEntwurf()]

    var body: some View {
        NavigationStack {
            Form {
                Section("Adresse") {
                    TextField("Straße und Hausnummer", text: $adresse)
                        .textContentType(.streetAddressLine1)
                    TextField("PLZ und Ort", text: $ort)
                        .textContentType(.addressCity)
                }

                Section("Eckdaten") {
                    TextField("Gesamtfläche m²", text: $gesamtflaecheText)
                        .keyboardType(.decimalPad)
                    Stepper(value: $abrechnungsstartMonat, in: 1...12) {
                        HStack {
                            Text("Abrechnungsstart-Monat")
                            Spacer()
                            Text("\(abrechnungsstartMonat)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Stepper(value: $abrechnungsstartTag, in: 1...31) {
                        HStack {
                            Text("Abrechnungsstart-Tag")
                            Spacer()
                            Text("\(abrechnungsstartTag)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Heizung") {
                    Picker("Heizungsart", selection: $heizungsart) {
                        ForEach(Heizungsart.allCases, id: \.self) { art in
                            Text(art.rawValue).tag(art)
                        }
                    }
                    Picker("Warmwasser", selection: $warmwasser) {
                        ForEach(Warmwasserbereitung.allCases, id: \.self) { bereitung in
                            Text(bereitung.rawValue).tag(bereitung)
                        }
                    }
                }

                Section("Wohneinheiten") {
                    ForEach($wohneinheiten) { $entwurf in
                        EinheitZeile(entwurf: $entwurf)
                    }
                    .onDelete { offsets in
                        wohneinheiten.remove(atOffsets: offsets)
                    }

                    Button {
                        wohneinheiten.append(EinheitEntwurf())
                    } label: {
                        Label("Einheit hinzufügen", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("Neues Objekt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetToolbar.abbrechen { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    SheetToolbar.primaer(
                        titel: "Anlegen",
                        istAktiv: istGueltig
                    ) { anlegen() }
                }
            }
        }
    }

    // MARK: - Validierung

    private var istGueltig: Bool {
        !adresse.trimmingCharacters(in: .whitespaces).isEmpty
            && (gesamtflaecheDecimal ?? 0) > 0
            && !wohneinheiten.isEmpty
            && wohneinheiten.allSatisfy {
                !$0.bezeichnung.trimmingCharacters(in: .whitespaces).isEmpty
                    && $0.flaecheM2 > 0
            }
    }

    private var gesamtflaecheDecimal: Decimal? {
        Decimal(string: gesamtflaecheText.replacingOccurrences(of: ",", with: "."))
    }

    // MARK: - Anlegen

    private func anlegen() {
        let objekt = Immobilie()
        objekt.adresse = adresse.trimmingCharacters(in: .whitespaces)
        objekt.ort = ort.trimmingCharacters(in: .whitespaces)
        objekt.gesamtflaecheM2 = gesamtflaecheDecimal ?? 0
        objekt.abrechnungsstartMonat = abrechnungsstartMonat
        objekt.abrechnungsstartTag = abrechnungsstartTag
        objekt.heizungsart = heizungsart
        objekt.warmwasserbereitung = warmwasser
        modelContext.insert(objekt)

        for entwurf in wohneinheiten {
            let wohneinheit = Wohneinheit()
            wohneinheit.bezeichnung = entwurf.bezeichnung.trimmingCharacters(in: .whitespaces)
            wohneinheit.flaecheM2 = entwurf.flaecheM2
            wohneinheit.nutzungsart = entwurf.nutzungsart
            wohneinheit.immobilie = objekt
            modelContext.insert(wohneinheit)
        }

        try? modelContext.save()
        onAngelegt(objekt)
        dismiss()
    }
}

// MARK: - Wohneinheit-Zeile

struct EinheitEntwurf: Identifiable, Equatable, Sendable {
    let id: UUID = UUID()
    var bezeichnung: String = ""
    var flaecheM2: Decimal = 0
    var nutzungsart: Nutzungsart = .wohnung
}

private struct EinheitZeile: View {
    @Binding var entwurf: EinheitEntwurf
    @State private var flaecheText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Bezeichnung (z.B. EG, OG, KG)", text: $entwurf.bezeichnung)

            HStack {
                TextField("Fläche m²", text: $flaecheText)
                    .keyboardType(.decimalPad)
                    .onChange(of: flaecheText) { _, neu in
                        entwurf.flaecheM2 = Decimal(string: neu.replacingOccurrences(of: ",", with: ".")) ?? 0
                    }

                Picker("Nutzung", selection: $entwurf.nutzungsart) {
                    ForEach(Nutzungsart.allCases, id: \.self) { art in
                        Text(art.rawValue.capitalized).tag(art)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            if flaecheText.isEmpty && entwurf.flaecheM2 > 0 {
                flaecheText = NSDecimalNumber(decimal: entwurf.flaecheM2).stringValue
            }
        }
    }
}
