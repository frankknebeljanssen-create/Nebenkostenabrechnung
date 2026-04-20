//
//  StatusPill.swift
//  NebenkostenApp — UI/Components
//
//  Kapsel-Label mit Soft-Farbhintergrund. Verwendet z.B. als
//  "Validiert" (ok), "KI-Vorschlag" (warn), "In Arbeit" (warn),
//  "Fertig" (ok), "Roh" (muted).
//

import SwiftUI

struct StatusPill: View {
    enum Style {
        case ok, warn, error, muted, accent

        var fg: Color {
            switch self {
            case .ok:     return DesignTokens.statusOk
            case .warn:   return DesignTokens.statusWarn
            case .error:  return DesignTokens.statusError
            case .muted:  return DesignTokens.statusMuted
            case .accent: return DesignTokens.accent
            }
        }

        var bg: Color {
            switch self {
            case .ok:     return DesignTokens.statusOkSoft
            case .warn:   return DesignTokens.statusWarnSoft
            case .error:  return DesignTokens.statusErrorSoft
            case .muted:  return DesignTokens.statusMutedSoft
            case .accent: return DesignTokens.accentSoft
            }
        }
    }

    let text: String
    let style: Style

    var body: some View {
        Text(text)
            .appFont(AppFont.captionSemi())
            .foregroundStyle(style.fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(style.bg)
            .clipShape(Capsule())
    }
}
