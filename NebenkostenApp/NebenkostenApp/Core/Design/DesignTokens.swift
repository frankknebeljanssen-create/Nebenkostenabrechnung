//
//  DesignTokens.swift
//  NebenkostenApp — Core/Design
//
//  Single Source of Truth für Farben. Hex-Werte sind 1:1 aus
//  design_handoff_nebenkosten_app/assets/tokens.jsx übernommen —
//  nur die Accent-Farbe weicht ab (Product-Owner-Wahl: Blue #3A5578
//  statt Default-Slate #4B5563, siehe Task UI-0).
//
//  Dark-Mode-Overrides werden erst in einem späteren Task gepflegt;
//  Phase 1 läuft nur in Light-Mode.
//

import SwiftUI

enum DesignTokens {

    // MARK: - Hintergründe

    static let bgApp           = Color(hex: "#F5F1E8")
    static let bgAppCompact    = Color(hex: "#EFEAE0")
    static let bgSurface       = Color(hex: "#FBF8F1")
    static let bgSurfaceAlt    = Color(hex: "#F1ECDF")
    static let bgSheet         = Color(hex: "#F5F1E8")
    /// Warmer Braunton fuer Header (KontextHeader) und Footer
    /// (NebenkostenTabBar-Pill). Eine Stufe dunkler als
    /// bgAppCompact, damit die beiden Chrome-Elemente oben + unten
    /// deutlich vom Content abgesetzt sind und visuell zueinander
    /// gehoeren.
    static let bgHeaderFooter  = Color(hex: "#E4DFD3")

    static let separator       = Color(hex: "#3C3228", alpha: 0.12)
    static let separatorStrong = Color(hex: "#3C3228", alpha: 0.22)

    // MARK: - Text

    static let text            = Color(hex: "#1F2937")
    static let textSecondary   = Color(hex: "#5B6472")
    static let textTertiary    = Color(hex: "#8A8578")
    static let textQuaternary  = Color(hex: "#B8B0A0")

    // MARK: - Accent (Product-Owner-Wahl: Blue)

    static let accent          = Color(hex: "#3A5578")
    static let accentHover     = Color(hex: "#304A6A")
    static let accentSoft      = Color(hex: "#3A5578", alpha: 0.12)
    static let accentText      = Color(hex: "#FBF8F1")

    // MARK: - Einheiten

    static let unitKG          = Color(hex: "#B08968")
    static let unitKGSoft      = Color(hex: "#B08968", alpha: 0.12)
    static let unitEG          = Color(hex: "#7A9070")
    static let unitEGSoft      = Color(hex: "#7A9070", alpha: 0.12)
    static let unitOG          = Color(hex: "#506E8C")
    static let unitOGSoft      = Color(hex: "#506E8C", alpha: 0.12)
    static let unitObjekt      = Color(hex: "#4B5563")
    static let unitObjektSoft  = Color(hex: "#4B5563", alpha: 0.10)

    // MARK: - Status

    static let statusOk        = Color(hex: "#3F7A5B")
    static let statusOkSoft    = Color(hex: "#3F7A5B", alpha: 0.14)
    static let statusWarn      = Color(hex: "#B8841F")
    static let statusWarnSoft  = Color(hex: "#B8841F", alpha: 0.15)
    static let statusError     = Color(hex: "#A63D2A")
    static let statusErrorSoft = Color(hex: "#A63D2A", alpha: 0.12)
    static let statusMuted     = Color(hex: "#8A8578")
    static let statusMutedSoft = Color(hex: "#8A8578", alpha: 0.14)

    // MARK: - AI-Validierungs-Zustände

    static let aiRaw             = Color(hex: "#8A8578")
    static let aiSuggest         = Color(hex: "#B8841F")
    static let aiSuggestBg       = Color(hex: "#B8841F", alpha: 0.10)
    static let aiValidated       = Color(hex: "#3F7A5B")
    static let aiValidatedBg     = Color(hex: "#3F7A5B", alpha: 0.10)
    static let aiLowConfidence   = Color(hex: "#A63D2A")
    static let aiLowConfidenceBg = Color(hex: "#A63D2A", alpha: 0.10)
}

// MARK: - Hex-Konstruktor

extension Color {
    /// Parst "#RRGGBB" oder "RRGGBB" und wendet optional Alpha an.
    /// Ungültige Eingaben werden silent zu Schwarz — DesignTokens
    /// selbst stellt sicher, dass nur gültige Hex-Werte reinkommen.
    init(hex: String, alpha: Double = 1.0) {
        var roh = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if roh.hasPrefix("#") { roh.removeFirst() }
        guard roh.count == 6, let wert = UInt32(roh, radix: 16) else {
            self.init(.sRGB, red: 0, green: 0, blue: 0, opacity: alpha)
            return
        }
        let r = Double((wert >> 16) & 0xFF) / 255.0
        let g = Double((wert >> 8)  & 0xFF) / 255.0
        let b = Double( wert        & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
