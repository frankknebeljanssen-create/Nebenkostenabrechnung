//
//  WohneinheitZeile.swift
//  NebenkostenApp — UI/Objekt/Components
//
//  Einzel-Card für eine Wohneinheit unterhalb des Kachel-Grids.
//  Icon, Bezeichnung · Nutzungsart, Mietername, Status-Ampel.
//

import SwiftUI

struct WohneinheitZeile: View {
    let wohneinheit: Wohneinheit

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(titel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(mieterText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Circle()
                    .fill(status.farbe)
                    .frame(width: 12, height: 12)
                Text(statusText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Abgeleitete Werte

    private var symbol: String {
        switch wohneinheit.nutzungsart {
        case .gewerbe:    return "building.2"
        case .leerstand:  return "questionmark.square.dashed"
        default:          return "house"
        }
    }

    private var titel: String {
        let bez = wohneinheit.bezeichnung.isEmpty ? "Unbenannt" : wohneinheit.bezeichnung
        let nutzung = wohneinheit.nutzungsart.rawValue.capitalized
        return "\(bez) · \(nutzung)"
    }

    private var aktiverMieter: Mietverhaeltnis? {
        (wohneinheit.mietverhaeltnisse ?? [])
            .first { $0.auszugAm == nil }
    }

    private var hatZaehlerstaende: Bool {
        (wohneinheit.zaehler ?? [])
            .contains(where: { ($0.staende ?? []).isEmpty == false })
    }

    private var mieterText: String {
        if let mieter = aktiverMieter {
            let name = mieter.mieterName.trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? "Mieter ohne Namen" : name
        }
        return "Kein aktiver Mietvertrag"
    }

    private var status: KachelStatus {
        if aktiverMieter == nil   { return .rot }
        if !hatZaehlerstaende      { return .gelb }
        return .gruen
    }

    private var statusText: String {
        switch status {
        case .rot:   return "Mietvertrag fehlt"
        case .gelb:  return "Zählerstände fehlen"
        case .gruen: return "Alle Daten da"
        }
    }
}
