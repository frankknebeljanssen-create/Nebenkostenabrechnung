//
//  MeterReading.swift
//  NebenkostenApp — UI/Zaehler/Components
//
//  Eine einzelne Ablesung (Anfang oder Ende) in einer Zähler-Row.
//  Layout nach design_handoff meters-bills.jsx (MeterReading,
//  Zeilen 127-151), mit Font-Bumps für Zielgruppe 50+:
//
//    [●] ANFANG  01.01.    ← StatusDot + Label + Datum
//    382.471                ← Wert monoBetrag17, Farbe ok/statusError
//

import SwiftUI

struct MeterReading: View {
    enum Art: String {
        case anfang
        case ende

        var label: String {
            switch self {
            case .anfang: return "Anfang"
            case .ende:   return "Ende"
            }
        }
    }

    let art: Art
    let datum: Date?
    let wert: String?
    let status: Status

    enum Status {
        case ok
        case error

        var dotStatus: StatusDot.Status {
            switch self {
            case .ok:    return .ok
            case .error: return .error
            }
        }

        var text: Color {
            switch self {
            case .ok:    return DesignTokens.text
            case .error: return DesignTokens.statusError
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                StatusDot(status: status.dotStatus, size: 6)
                Text(art.label)
                    .appFont(AppFont.messungLabel())
                    .foregroundStyle(DesignTokens.textTertiary)
                if let datum {
                    Text(Self.datumsFormatter.string(from: datum))
                        .appFont(AppFont.monoSmall())
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }
            Text(wert ?? "— — —")
                .appFont(AppFont.monoBetrag17())
                .foregroundStyle(status.text)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static let datumsFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM."
        f.locale = Locale(identifier: "de_DE")
        return f
    }()
}
