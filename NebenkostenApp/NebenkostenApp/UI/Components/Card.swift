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
//               Papier-Ton-Hintergrund abhebt.
//
//  Optionaler Farbbalken links:
//    `balkenFarbe: Color?` — wenn gesetzt, haengt ein 4-pt-
//    UnitBalken in der uebergebenen Farbe am linken Innenrand.
//    Nutzt zusammen mit Home-Scope-Farben drei Home-Cards im
//    gleichen Look (Wohneinheit, Status, Naechster Schritt).
//

import SwiftUI

struct Card<Content: View>: View {
    enum Tiefe {
        case flach
        case erhoben
    }

    private let content: Content
    private let tiefe: Tiefe
    private let balkenFarbe: Color?

    init(
        tiefe: Tiefe = .flach,
        balkenFarbe: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.tiefe = tiefe
        self.balkenFarbe = balkenFarbe
    }

    var body: some View {
        innereHuelle
            .frame(maxWidth: .infinity, alignment: .leading)
            // Oben 14 pt, unten 10 pt — der untere Teil faellt
            // visuell etwas flacher aus, damit die Cards weniger
            // Hoehe verbrauchen.
            .padding(.top, 14)
            .padding(.bottom, 10)
            .padding(.horizontal, 16)
            .background(DesignTokens.bgSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(randFarbe, lineWidth: randBreite)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: schattenFarbe, radius: schattenRadius, x: 0, y: schattenY)
    }

    @ViewBuilder
    private var innereHuelle: some View {
        if let farbe = balkenFarbe {
            HStack(alignment: .top, spacing: 12) {
                UnitBalken(farbe: farbe)
                    .frame(maxHeight: .infinity)
                VStack(alignment: .leading, spacing: 0) { content }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            VStack(alignment: .leading, spacing: 0) { content }
        }
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
