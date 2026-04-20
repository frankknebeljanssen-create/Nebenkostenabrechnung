//
//  ZaehlerSammelZeile.swift
//  NebenkostenApp — UI/Zaehler/Components
//
//  Zeile in der Zähler-Übersicht: Bezeichnung + Seriennummer links,
//  zwei Mini-Dots für Anfangs- und Endstand-Status rechts, darunter
//  optional der zuletzt erfasste Wert.
//

import SwiftUI

struct ZaehlerSammelZeile: View {
    let zaehler: Zaehler
    let periode: Abrechnungsperiode?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(anzeigeName)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                if !zaehler.seriennummer.isEmpty {
                    Text(zaehler.seriennummer)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let zeile = letzterWertText {
                    Text(zeile)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            statusDots
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    // MARK: - Status-Dots

    private var statusDots: some View {
        HStack(spacing: 6) {
            dot(status: anfangsStatus, label: "A")
            dot(status: endStatus,     label: "E")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Anfang \(ampelName(anfangsStatus)), Ende \(ampelName(endStatus))."
        )
    }

    private func dot(status: AmpelStatus, label: String) -> some View {
        ZStack {
            Circle()
                .fill(status.farbe.opacity(0.22))
                .frame(width: 18, height: 18)
            Circle()
                .fill(status.farbe)
                .frame(width: 10, height: 10)
        }
        .overlay(alignment: .bottom) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
                .offset(y: 9)
        }
    }

    // MARK: - Status-Berechnung

    enum AmpelStatus {
        case gruen      // erfasst, plausibel
        case gelb       // fehlt
        case rot        // Warnung (Rücklauf)
        case grau       // keine Periode
        var farbe: Color {
            switch self {
            case .gruen: return .green
            case .gelb:  return .orange
            case .rot:   return .red
            case .grau:  return .gray
            }
        }
    }

    private var staendeInPeriode: [Zaehlerstand] {
        guard let p = periode else { return [] }
        return (zaehler.staende ?? [])
            .filter { $0.ablesedatum >= p.von && $0.ablesedatum <= p.bis }
            .sorted { $0.ablesedatum < $1.ablesedatum }
    }

    private var anfangsStatus: AmpelStatus {
        guard periode != nil else { return .grau }
        if staendeInPeriode.isEmpty { return .gelb }
        if staendeInPeriode.count >= 2, ruecklaufVorhanden { return .rot }
        return .gruen
    }

    private var endStatus: AmpelStatus {
        guard periode != nil else { return .grau }
        if staendeInPeriode.count < 2 { return .gelb }
        if ruecklaufVorhanden { return .rot }
        return .gruen
    }

    private var ruecklaufVorhanden: Bool {
        guard let first = staendeInPeriode.first,
              let last  = staendeInPeriode.last,
              first.id != last.id
        else { return false }
        return last.stand < first.stand
    }

    private func ampelName(_ s: AmpelStatus) -> String {
        switch s {
        case .gruen: return "grün (erfasst)"
        case .gelb:  return "gelb (fehlt)"
        case .rot:   return "rot (Warnung)"
        case .grau:  return "grau (keine Periode)"
        }
    }

    // MARK: - Texte

    private var anzeigeName: String {
        if !zaehler.bezeichnung.isEmpty { return zaehler.bezeichnung }
        return mediumKurz(zaehler.medium)
    }

    private var letzterWertText: String? {
        guard let last = staendeInPeriode.last else { return nil }
        let zahl = NSDecimalNumber(decimal: last.stand).stringValue
        let einheit = zaehler.einheit.isEmpty ? "" : " \(zaehler.einheit)"
        return "Ende: \(zahl)\(einheit)"
    }

    private func mediumKurz(_ m: Medium) -> String {
        switch m {
        case .strom:         return "Strom"
        case .warmwasser:    return "Warmwasser"
        case .kaltwasser:    return "Kaltwasser"
        case .waermeenergie: return "Wärmemenge"
        case .gas:           return "Gas"
        case .oel:           return "Öl"
        }
    }
}
