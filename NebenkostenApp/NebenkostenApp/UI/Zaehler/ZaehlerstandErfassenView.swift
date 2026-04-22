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

    init(zaehler: Zaehler) {
        _vm = State(wrappedValue: ZaehlerstandErfassenViewModel(zaehler: zaehler))
    }

    var body: some View {
        NavigationStack {
            Form {
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
