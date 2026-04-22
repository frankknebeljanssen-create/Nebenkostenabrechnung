//
//  ZaehlerstandErfassenView.swift
//  NebenkostenApp — UI/Zaehler
//

import SwiftUI
import SwiftData

struct ZaehlerstandErfassenView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var vm: ZaehlerstandErfassenViewModel
    @State private var zeigeScanner = false
    @FocusState private var wertFokus: Bool

    init(zaehler: Zaehler) {
        _vm = State(wrappedValue: ZaehlerstandErfassenViewModel(zaehler: zaehler))
    }

    var body: some View {
        NavigationStack {
            Form {
                zaehlerKontextSection
                erfassungsModusSection

                Section("Datum") {
                    DatePicker(
                        "Ablesedatum",
                        selection: $vm.datum,
                        displayedComponents: .date
                    )
                    .environment(\.locale, Locale(identifier: "de_DE"))
                }

                Section("Quelle") {
                    Picker("Ablesequelle", selection: $vm.quelle) {
                        ForEach(ZaehlerstandErfassenViewModel.verfuegbareQuellen, id: \.self) { q in
                            Text(q.anzeigeName).tag(q)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Zählerstand") {
                    HStack {
                        TextField("0,00", text: $vm.wertText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .focused($wertFokus)
                        Text(vm.zaehler.einheit.isEmpty ? "—" : vm.zaehler.einheit)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Notiz (optional)") {
                    TextField("z.B. Gerät wurde gewechselt",
                              text: $vm.notiz,
                              axis: .vertical)
                        .lineLimit(1...3)
                }

                if let hinweis = vm.plausiHinweis {
                    Section {
                        Label(hinweis, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }
            }
            .sheetTitelHeader("Zählerstand erfassen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetToolbar.abbrechen { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    SheetToolbar.primaer(
                        titel: "Speichern",
                        istAktiv: vm.istGueltig
                    ) { speichernMitPruefung() }
                }
            }
            .keyboardFertigButton()
            .fullScreenCover(isPresented: $zeigeScanner) {
                NavigationStack {
                    ZifferScannerView(onErkannt: { text in
                        vm.wertText = zifferText(aus: text)
                        vm.quelle = .kiExtrahiert
                    })
                    .ignoresSafeArea()
                    .navigationTitle("Ziffern scannen")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            SheetToolbar.abbrechen { zeigeScanner = false }
                        }
                    }
                }
            }
            .alert("Rücklauf erkannt",
                   isPresented: $vm.zeigeRuecklaufAlert,
                   actions: {
                       Button("Korrigieren", role: .cancel) {}
                       Button("Trotzdem speichern") { persistiere() }
                   },
                   message: {
                       Text("Der neue Stand ist kleiner als der vorherige. Sicher, dass das stimmt?")
                   })
        }
    }

    // MARK: - Kontext-Block (welchen Zaehler erfasst der User?)

    /// Zeigt oben im Form, WELCHEN Zaehler wir gerade erfassen.
    /// Wichtig beim Aufruf aus der AbrechnungsKachel — dort oeffnet
    /// sich das Sheet ohne vorherigen Tab-Wechsel, also ohne visuellen
    /// Kontext, welcher Zaehler adressiert ist. Nie interne Slug-IDs
    /// zeigen — nur `anzeigename` und `anzeigetyp` (beide bereinigt
    /// in `ZaehlerAnzeige.swift`).
    @ViewBuilder
    private var zaehlerKontextSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: MediumMeta.sfSymbol(vm.zaehler.medium))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(MediumMeta.farbe(vm.zaehler.medium))
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.zaehler.anzeigename)
                        .appFont(AppFont.Basis.bodySemi())
                        .foregroundStyle(DesignTokens.text)
                        .lineLimit(2)
                    Text(vm.zaehler.anzeigetyp)
                        .appFont(AppFont.Basis.caption())
                        .foregroundStyle(DesignTokens.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
        }
    }

    // MARK: - Modus-Section (Kamera / Manuell)

    /// Zwei Buttons oben im Sheet. Kamera ist nur auf echten Geraeten
    /// sichtbar — DataScanner laeuft nicht im Simulator und faellt aus
    /// der Row raus, wenn `istVerfuegbar` false ist. Manuell fokussiert
    /// das Wert-TextField und oeffnet die Tastatur; das passt auch zu
    /// dem Fall, in dem der User nach einem Kamera-Scan nur einen Wert
    /// nachpolieren moechte.
    @ViewBuilder
    private var erfassungsModusSection: some View {
        Section {
            HStack(spacing: 12) {
                if ZifferScannerView.istVerfuegbar {
                    modusButton(
                        titel: "Kamera",
                        symbol: "camera.fill",
                        primaer: true
                    ) {
                        zeigeScanner = true
                    }
                }
                modusButton(
                    titel: "Manuell",
                    symbol: "pencil",
                    primaer: !ZifferScannerView.istVerfuegbar
                ) {
                    wertFokus = true
                }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
        } footer: {
            if !ZifferScannerView.istVerfuegbar {
                Text("Kamera-Erkennung ist auf diesem Gerät nicht verfügbar. Der Wert kann unten direkt eingegeben werden.")
            }
        }
    }

    private func modusButton(
        titel: String,
        symbol: String,
        primaer: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                Text(titel)
                    .appFont(AppFont.Basis.bodySemi())
            }
            .foregroundStyle(primaer ? Color.white : DesignTokens.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(primaer ? DesignTokens.accent : DesignTokens.bgSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        primaer ? Color.clear : DesignTokens.separator,
                        lineWidth: 0.5
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Text-Normalisierung

    /// Zieht aus einem DataScanner-Transcript die reinen Ziffern
    /// (plus Dezimalseparator) raus. Beispiel „Serien-Nr. 8SEN021"
    /// laesst sich so schwer benutzen, aber „12345,678 kWh" wird
    /// zu "12345,678". Alles andere bleibt an der User-Kontrolle.
    private func zifferText(aus transcript: String) -> String {
        let erlaubt: Set<Character> = Set("0123456789,.")
        let gefiltert = transcript.filter { erlaubt.contains($0) }
        return gefiltert.isEmpty ? transcript : gefiltert
    }

    // MARK: - Speichern

    private func speichernMitPruefung() {
        if vm.hatRuecklauf {
            vm.zeigeRuecklaufAlert = true
        } else {
            persistiere()
        }
    }

    private func persistiere() {
        guard let wert = vm.wertDecimal else { return }
        let zs = Zaehlerstand()
        zs.ablesedatum = vm.datum
        zs.stand = wert
        zs.quelle = vm.quelle
        zs.notizen = vm.notiz.trimmingCharacters(in: .whitespaces)
        zs.zaehler = vm.zaehler
        modelContext.insert(zs)
        try? modelContext.save()
        dismiss()
    }
}
