//
//  Card.swift
//  NebenkostenApp — UI/Components
//
//  Wiederverwendbarer Card-Container laut Design-Handoff (14 pt
//  vertical, 16 pt horizontal Padding, bgSurface, Radius 14).
//
//  Zwei Tiefen-Varianten:
//    .flach   — 0.5 pt separator-Border, kein Shadow (Default).
//               Für die klassische Listen-Card mit minimaler
//               Erhebung.
//    .erhoben — 0.5 pt separatorStrong + dezenter Shadow. Für
//               Home-Screens, damit sich die Card deutlich vom
//               Papier-Ton-Hintergrund abhebt. Der Shadow ist
//               bewusst ruhig (kleiner Radius, 8 % Schwarz) —
//               seriös statt verspielt.
//

import SwiftUI

struct Card<Content: View>: View {
    enum Tiefe {
        case flach
        case erhoben
    }

    private let content: Content
    private let tiefe: Tiefe

    init(tiefe: Tiefe = .flach, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.tiefe = tiefe
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(DesignTokens.bgSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(randFarbe, lineWidth: randBreite)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: schattenFarbe, radius: schattenRadius, x: 0, y: schattenY)
    }

    private var randFarbe: Color {
        switch tiefe {
        case .flach:   return DesignTokens.separator
        case .erhoben: return DesignTokens.separatorStrong
        }
    }

    private var randBreite: CGFloat {
        tiefe == .erhoben ? 0.5 : 0.5
    }

    private var schattenFarbe: Color {
        switch tiefe {
        case .flach:   return .clear
        case .erhoben: return Color.black.opacity(0.08)
        }
    }

    private var schattenRadius: CGFloat {
        tiefe == .erhoben ? 10 : 0
    }

    private var schattenY: CGFloat {
        tiefe == .erhoben ? 3 : 0
    }
}
