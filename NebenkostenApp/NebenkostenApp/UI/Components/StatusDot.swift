//
//  StatusDot.swift
//  NebenkostenApp — UI/Components
//
//  Status-Indikator (8 pt Default) — grün ok / orange warn /
//  rot error / grau muted, aus DesignTokens.
//

import SwiftUI

struct StatusDot: View {
    enum Status {
        case ok, warn, error, muted

        var farbe: Color {
            switch self {
            case .ok:    return DesignTokens.statusOk
            case .warn:  return DesignTokens.statusWarn
            case .error: return DesignTokens.statusError
            case .muted: return DesignTokens.statusMuted
            }
        }
    }

    let status: Status
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(status.farbe)
            .frame(width: size, height: size)
    }
}
