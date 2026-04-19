//
//  RechnungListeView.swift
//  NebenkostenApp — UI/Rechnung
//

import SwiftUI
import SwiftData

struct RechnungListeView: View {
    @Bindable var immobilie: Immobilie
    @State private var zeigeNeu = false
    @State private var auswahl: Rechnung?

    private var sortierte: [Rechnung] {
        (immobilie.rechnungen ?? [])
            .sorted { $0.rechnungsdatum > $1.rechnungsdatum }
    }

    var body: some View {
        List {
            if sortierte.isEmpty {
                Section {
                    leerZustand
                }
            } else {
                Section {
                    ForEach(sortierte) { r in
                        Button {
                            auswahl = r
                        } label: {
                            zeile(r)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Rechnungen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    zeigeNeu = true
                } label: {
                    Label("Neue Rechnung", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $zeigeNeu) {
            RechnungEditView(modus: .neu(immobilie: immobilie))
        }
        .sheet(item: $auswahl) { r in
            RechnungEditView(modus: .bearbeiten(r))
        }
    }

    private var leerZustand: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Noch keine Rechnungen erfasst")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                zeigeNeu = true
            } label: {
                Label("Erste Rechnung anlegen", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private func zeile(_ r: Rechnung) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(r.lieferant.isEmpty ? "Ohne Lieferant" : r.lieferant)
                    .font(.body.weight(.semibold))
                HStack(spacing: 6) {
                    if let kostenart = r.kostenart {
                        Text(kostenart.bezeichnung)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("ohne Kostenart")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(r.rechnungsdatum.formatted(date: .numeric, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatiertBetrag(r.betragBruttoEuro))
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                if r.geprueft {
                    Label("Geprüft", systemImage: "checkmark.seal.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }
        }
        .contentShape(Rectangle())
    }

    private func formatiertBetrag(_ betrag: Decimal) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = "EUR"
        nf.locale = Locale(identifier: "de_DE")
        return nf.string(from: NSDecimalNumber(decimal: betrag)) ?? "\(betrag) €"
    }
}
