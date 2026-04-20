//
//  EinheitKacheln.swift
//  NebenkostenApp — UI/Objekt/Components
//
//  Spezialisierte Dashboard-Kacheln, die nur im Einheit-Scope
//  erscheinen: Saldo-Kachel (Nachzahlung/Erstattung), Mieter-Kachel.
//  Alle teilen sich das Layout-Skelett der StatusKachel (gleiche
//  Größe, gleicher Hintergrund), zeigen aber einheit-fokussierte
//  Werte statt erledigt/offen-Counts.
//

import SwiftUI

// MARK: - Saldo-Kachel

struct SaldoKachel: View {
    /// Mieterabrechnung der Einheit. Nil → "Daten unvollständig".
    let abrechnung: Mieterabrechnung?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.tint)
                Spacer()
                Circle()
                    .fill(statusFarbe)
                    .frame(width: 12, height: 12)
                    .accessibilityLabel(accessibilityStatus)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Abrechnung")
                    .font(.subheadline.weight(.semibold))
                if let a = abrechnung {
                    Text(betragFormatiert(a.saldoEuro.magnitude))
                        .font(.callout.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(a.saldoEuro >= 0 ? .orange : .green)
                    Text(a.saldoEuro >= 0 ? "Nachzahlung" : "Erstattung")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Daten unvollständig")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text("Inspektor öffnen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    private var statusFarbe: Color {
        guard let a = abrechnung else { return .orange }
        return a.saldoEuro >= 0 ? .orange : .green
    }

    private var accessibilityStatus: String {
        guard let a = abrechnung else { return "unvollständig" }
        return a.saldoEuro >= 0 ? "Nachzahlung" : "Erstattung"
    }

    private func betragFormatiert(_ d: Decimal) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = "EUR"
        nf.locale = Locale(identifier: "de_DE")
        return nf.string(from: NSDecimalNumber(decimal: d)) ?? "\(d) €"
    }
}

// MARK: - Mieter-Kachel (Einheit-Scope)

struct MieterEinheitKachel: View {
    let mieterName: String
    let mieterTyp: String
    let istLeerstand: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.tint)
                Spacer()
                Circle()
                    .fill(istLeerstand ? Color.gray : Color.green)
                    .frame(width: 12, height: 12)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Mieter")
                    .font(.subheadline.weight(.semibold))
                if istLeerstand {
                    Text("Leerstand")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else {
                    Text(mieterName.isEmpty ? "Ohne Namen" : mieterName)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    if !mieterTyp.isEmpty {
                        Text(mieterTyp)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    private var icon: String {
        istLeerstand ? "house.slash" : "person.fill"
    }
}
