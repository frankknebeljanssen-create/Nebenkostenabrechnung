//
//  TokenProbeView.swift
//  NebenkostenApp — UI/Debug
//
//  Debug-Ansicht: zeigt alle DesignTokens als Swatch-Liste. Hilft
//  beim visuellen Abgleich mit dem Handoff. Nur im DEBUG-Build
//  erreichbar — das EinstellungenSheet hängt den Link per
//  `#if DEBUG` ein.
//

import SwiftUI

struct TokenProbeView: View {

    struct TokenEntry: Identifiable {
        let name: String
        let farbe: Color
        var id: String { name }
    }

    private let entries: [TokenEntry] = [
        .init(name: "bgApp",           farbe: DesignTokens.bgApp),
        .init(name: "bgAppCompact",    farbe: DesignTokens.bgAppCompact),
        .init(name: "bgSurface",       farbe: DesignTokens.bgSurface),
        .init(name: "separator",       farbe: DesignTokens.separator),
        .init(name: "separatorStrong", farbe: DesignTokens.separatorStrong),
        .init(name: "text",            farbe: DesignTokens.text),
        .init(name: "textSecondary",   farbe: DesignTokens.textSecondary),
        .init(name: "textTertiary",    farbe: DesignTokens.textTertiary),
        .init(name: "accent",          farbe: DesignTokens.accent),
        .init(name: "accentHover",     farbe: DesignTokens.accentHover),
        .init(name: "accentSoft",      farbe: DesignTokens.accentSoft),
        .init(name: "accentText",      farbe: DesignTokens.accentText),
        .init(name: "statusOk",        farbe: DesignTokens.statusOk),
        .init(name: "statusOkSoft",    farbe: DesignTokens.statusOkSoft),
        .init(name: "statusWarn",      farbe: DesignTokens.statusWarn),
        .init(name: "statusWarnSoft",  farbe: DesignTokens.statusWarnSoft),
        .init(name: "statusError",     farbe: DesignTokens.statusError),
        .init(name: "statusErrorSoft", farbe: DesignTokens.statusErrorSoft),
        .init(name: "statusMuted",     farbe: DesignTokens.statusMuted),
        .init(name: "statusMutedSoft", farbe: DesignTokens.statusMutedSoft),
        .init(name: "unitObjekt",      farbe: DesignTokens.unitObjekt),
        .init(name: "unitObjektSoft",  farbe: DesignTokens.unitObjektSoft),
        .init(name: "unitKG",          farbe: DesignTokens.unitKG),
        .init(name: "unitKGSoft",      farbe: DesignTokens.unitKGSoft),
        .init(name: "unitEG",          farbe: DesignTokens.unitEG),
        .init(name: "unitEGSoft",      farbe: DesignTokens.unitEGSoft),
        .init(name: "unitOG",          farbe: DesignTokens.unitOG),
        .init(name: "unitOGSoft",      farbe: DesignTokens.unitOGSoft),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(entries) { e in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(e.farbe)
                            .frame(width: 40, height: 28)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(DesignTokens.separator, lineWidth: 0.5)
                            )
                        Text(e.name)
                            .appFont(AppFont.monoCaption())
                            .foregroundStyle(DesignTokens.text)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    DividerLine()
                }
            }
        }
        .background(DesignTokens.bgApp)
        .navigationTitle("Design-Tokens")
        .navigationBarTitleDisplayMode(.inline)
    }
}
