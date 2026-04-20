//
//  ScopePill.swift
//  NebenkostenApp — UI/Components
//
//  Kleine Kapsel mit Scope-Kürzel ("HAUS" / "KG" / "EG" / "OG"),
//  Dekorations-Label an einer Row (z.B. Zähler oder Belege). Farbe
//  kommt aus DesignTokens.unitX + unitXSoft.
//

import SwiftUI

struct ScopePill: View {
    /// Scope-Id — "objekt", "HAUS" oder eine Einheit-Bezeichnung
    /// (KG / EG / OG / DG / "2. OG"). Case-insensitive.
    let scopeId: String

    var body: some View {
        Text(label)
            .appFont(AppFont.scopePill())
            .foregroundStyle(farbe)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(softFarbe)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private var normalized: String {
        scopeId.uppercased().trimmingCharacters(in: .whitespaces)
    }

    private var label: String {
        let n = normalized
        if n == "OBJEKT" || n == "HAUS" || n.isEmpty { return "HAUS" }
        return n
    }

    private var farbe: Color {
        switch label {
        case "HAUS": return DesignTokens.unitObjekt
        case "KG":   return DesignTokens.unitKG
        case "EG":   return DesignTokens.unitEG
        case "OG":   return DesignTokens.unitOG
        default:     return DesignTokens.unitObjekt
        }
    }

    private var softFarbe: Color {
        switch label {
        case "HAUS": return DesignTokens.unitObjektSoft
        case "KG":   return DesignTokens.unitKGSoft
        case "EG":   return DesignTokens.unitEGSoft
        case "OG":   return DesignTokens.unitOGSoft
        default:     return DesignTokens.unitObjektSoft
        }
    }
}
