//
//  AbrechnungVorschauView.swift
//  NebenkostenApp — UI/Abrechnungen
//
//  Zeigt pro aktivem Mieter eine Karte mit Saldo. Tap öffnet das
//  Detail inkl. PDF-Export.
//

import SwiftUI
import SwiftData

struct AbrechnungVorschauView: View {
    let periode: Abrechnungsperiode
    @Bindable var immobilie: Immobilie

    private var mieterAbrechnungen: [Mieterabrechnung] {
        AbrechnungsService.aggregiere(periode: periode, immobilie: immobilie)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                periodeKopf
                if mieterAbrechnungen.isEmpty {
                    leerZustand
                } else {
                    VStack(spacing: 12) {
                        ForEach(mieterAbrechnungen) { abrechnung in
                            NavigationLink(value: abrechnung) {
                                mieterKarte(abrechnung)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Vorschau")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Mieterabrechnung.self) { a in
            MieterAbrechnungsDetailView(abrechnung: a, periode: periode, immobilie: immobilie)
        }
    }

    // MARK: - Sektionen

    private var periodeKopf: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Nebenkostenabrechnung")
                .font(.title3.bold())
            Text(formatierePeriode())
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(immobilie.adresse)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var leerZustand: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.square.badge.xmark")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Keine aktiven Mieter in dieser Periode.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Mieter-Karte

    private func mieterKarte(_ a: Mieterabrechnung) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(a.mieterName.isEmpty ? "Ohne Namen" : a.mieterName)
                        .font(.body.weight(.semibold))
                    Text("Einheit \(a.einheitBezeichnung)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(a.positionen.count) Posten")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Capsule())
            }

            Divider()

            VStack(spacing: 6) {
                zeile("Gesamtkosten",   betrag: a.gesamtkostenEuro,    foreground: .primary)
                zeile("Vorauszahlungen", betrag: -a.vorauszahlungenEuro, foreground: .primary)
                Divider()
                saldoZeile(a)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func zeile(_ label: String, betrag: Decimal, foreground: Color) -> some View {
        HStack {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Text(formatiereEuro(betrag))
                .font(.callout.monospacedDigit())
                .foregroundStyle(foreground)
        }
    }

    private func saldoZeile(_ a: Mieterabrechnung) -> some View {
        HStack {
            Text(a.saldoEuro >= 0 ? "Nachzahlung" : "Erstattung")
                .font(.body.weight(.semibold))
            Spacer()
            Text(formatiereEuro(a.saldoEuro.magnitude))
                .font(.body.weight(.bold).monospacedDigit())
                .foregroundStyle(a.saldoEuro >= 0 ? .orange : .green)
        }
    }

    // MARK: - Formatter

    private func formatierePeriode() -> String {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "de_DE")
        return "\(f.string(from: periode.von)) – \(f.string(from: periode.bis))"
    }

    private func formatiereEuro(_ betrag: Decimal) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = "EUR"
        nf.locale = Locale(identifier: "de_DE")
        return nf.string(from: NSDecimalNumber(decimal: betrag)) ?? "\(betrag) €"
    }
}
