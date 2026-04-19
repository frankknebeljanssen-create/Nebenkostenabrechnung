//
//  ZaehlerBlock.swift
//  NebenkostenApp — UI/Wohneinheit/Components
//

import SwiftUI

struct ZaehlerBlock: View {
    let zaehler: [Zaehler]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Zähler")
                    .font(.headline)
                Spacer()
                if !zaehler.isEmpty {
                    Text("\(zaehler.count) Zähler")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(Capsule())
                }
            }

            if zaehler.isEmpty {
                Text("Noch keine Zähler angelegt.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(zaehler) { z in
                        NavigationLink(value: z) {
                            zeile(fuer: z)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Zeile

    private func zeile(fuer z: Zaehler) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon(fuer: z.medium))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(titel(z))
                    .font(.subheadline.weight(.medium))
                Text(untertitel(z))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                rechtePrimaerInfo(fuer: z)
                Circle()
                    .fill(status(fuer: z).farbe)
                    .frame(width: 10, height: 10)
                    .accessibilityLabel(statusBeschreibung(status(fuer: z)))
            }
        }
    }

    @ViewBuilder
    private func rechtePrimaerInfo(fuer z: Zaehler) -> some View {
        if let letzter = letzterStand(z) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(NSDecimalNumber(decimal: letzter.stand).stringValue + " " + z.einheit)
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                Text(letzter.ablesedatum.formatted(date: .numeric, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("Kein Stand")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Status

    private func status(fuer z: Zaehler) -> KachelStatus {
        let anzahl = (z.staende ?? []).count
        if anzahl >= 2 { return .gruen }
        if anzahl == 1 { return .gelb }
        return .rot
    }

    private func statusBeschreibung(_ s: KachelStatus) -> String {
        switch s {
        case .gruen: return "Anfangs- und Endstand erfasst"
        case .gelb:  return "Nur ein Stand erfasst"
        case .rot:   return "Keine Stände erfasst"
        }
    }

    // MARK: - Helfer

    private func icon(fuer medium: Medium) -> String {
        switch medium {
        case .strom:                 return "bolt"
        case .warmwasser:            return "drop.halffull"
        case .kaltwasser:            return "drop"
        case .waermeenergie:         return "flame"
        case .gas:                   return "fuelpump"
        case .oel:                   return "drop.triangle"
        }
    }

    private func titel(_ z: Zaehler) -> String {
        let medium = mediumBezeichnung(z.medium)
        let typSuffix = z.typ == .zwischen ? " (Zwischenzähler)" : ""
        let kennzeichen = z.bezeichnung.isEmpty ? "" : " · \(z.bezeichnung)"
        return "\(medium)\(typSuffix)\(kennzeichen)"
    }

    private func mediumBezeichnung(_ medium: Medium) -> String {
        switch medium {
        case .strom:         return "Strom"
        case .warmwasser:    return "Warmwasser"
        case .kaltwasser:    return "Kaltwasser"
        case .waermeenergie: return "Wärmemengenzähler"
        case .gas:           return "Gas"
        case .oel:           return "Öl"
        }
    }

    private func untertitel(_ z: Zaehler) -> String {
        z.seriennummer.isEmpty ? "Keine Seriennummer" : "Nr. \(z.seriennummer)"
    }

    private func letzterStand(_ z: Zaehler) -> Zaehlerstand? {
        (z.staende ?? []).sorted { $0.ablesedatum > $1.ablesedatum }.first
    }
}
