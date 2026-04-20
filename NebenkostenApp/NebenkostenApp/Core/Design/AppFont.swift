//
//  AppFont.swift
//  NebenkostenApp — Core/Design
//
//  Zentrale Typografie-Skala nach Design-Handoff. Jede Style-
//  Funktion liefert ein `AppFontStyle`-Value, das Font + Tracking +
//  optional Textcase bündelt. Konsumiert wird es per
//  `.appFont(_:)`-Modifier auf jeder Text- oder Label-View.
//
//  Familien:
//    IBMPlexSans  — Body / Titel / Labels
//    IBMPlexMono  — alle Geld- und Messwerte
//
//  System-Fallback ist aktiv, wenn die TTFs nicht geladen sind —
//  SwiftUI nutzt dann automatisch das Default-Font.
//

import SwiftUI

struct AppFontStyle: Equatable {
    let font: Font
    let tracking: CGFloat
    let uppercase: Bool
}

enum AppFont {

    // MARK: - Sans

    static func navTitle() -> AppFontStyle {
        .init(font: plexSans(.semibold, 30), tracking: -0.6, uppercase: false)
    }
    static func navTitleCompact() -> AppFontStyle {
        .init(font: plexSans(.semibold, 26), tracking: -0.5, uppercase: false)
    }
    static func heroSaldo() -> AppFontStyle {
        .init(font: plexSans(.semibold, 28), tracking: -0.3, uppercase: false)
    }
    static func statValue() -> AppFontStyle {
        // Spec: statValue = 19 pt, 600, tracking -0.3, MONO.
        .init(font: plexMono(.semibold, 19), tracking: -0.3, uppercase: false)
    }
    static func body() -> AppFontStyle {
        .init(font: plexSans(.regular, 15), tracking: 0, uppercase: false)
    }
    static func bodyMedium() -> AppFontStyle {
        .init(font: plexSans(.medium, 15), tracking: 0, uppercase: false)
    }
    static func bodySemi() -> AppFontStyle {
        .init(font: plexSans(.semibold, 15), tracking: 0, uppercase: false)
    }
    static func subtitle() -> AppFontStyle {
        .init(font: plexSans(.regular, 13), tracking: -0.1, uppercase: false)
    }
    static func caption() -> AppFontStyle {
        .init(font: plexSans(.regular, 12), tracking: 0, uppercase: false)
    }
    static func captionMedium() -> AppFontStyle {
        .init(font: plexSans(.medium, 12), tracking: 0, uppercase: false)
    }
    static func smallCaption() -> AppFontStyle {
        .init(font: plexSans(.regular, 11), tracking: 0, uppercase: false)
    }
    static func smallCaptionSemi() -> AppFontStyle {
        .init(font: plexSans(.semibold, 11), tracking: 0, uppercase: false)
    }
    static func uppercaseLabel() -> AppFontStyle {
        .init(font: plexSans(.semibold, 12), tracking: 0.6, uppercase: true)
    }
    static func micro() -> AppFontStyle {
        .init(font: plexSans(.regular, 10), tracking: 0.2, uppercase: false)
    }

    // MARK: - Mono

    static func monoLarge() -> AppFontStyle {
        .init(font: plexMono(.semibold, 22), tracking: 0, uppercase: false)
    }
    static func monoHero() -> AppFontStyle {
        .init(font: plexMono(.semibold, 28), tracking: 0, uppercase: false)
    }
    static func monoStat() -> AppFontStyle {
        .init(font: plexMono(.semibold, 19), tracking: -0.3, uppercase: false)
    }
    static func monoBody() -> AppFontStyle {
        .init(font: plexMono(.medium, 15), tracking: 0, uppercase: false)
    }
    static func monoCaption() -> AppFontStyle {
        .init(font: plexMono(.regular, 12), tracking: 0, uppercase: false)
    }
    static func monoSmall() -> AppFontStyle {
        .init(font: plexMono(.regular, 11), tracking: 0, uppercase: false)
    }
    static func monoMicro() -> AppFontStyle {
        .init(font: plexMono(.regular, 10), tracking: 0, uppercase: false)
    }

    // MARK: - Intern

    enum PlexSchnitt: String {
        case regular  = "Regular"
        case medium   = "Medium"
        case semibold = "SemiBold"
    }

    static func plexSans(_ schnitt: PlexSchnitt, _ size: CGFloat) -> Font {
        .custom("IBMPlexSans-\(schnitt.rawValue)", size: size)
    }

    static func plexMono(_ schnitt: PlexSchnitt, _ size: CGFloat) -> Font {
        .custom("IBMPlexMono-\(schnitt.rawValue)", size: size)
    }
}

// MARK: - View-Modifier

private struct AppFontModifier: ViewModifier {
    let style: AppFontStyle
    func body(content: Content) -> some View {
        content
            .font(style.font)
            .tracking(style.tracking)
            .textCase(style.uppercase ? .uppercase : nil)
    }
}

extension View {
    /// Wendet Font + Tracking + optional Uppercase in einem Aufruf an.
    /// Beispiel: `Text("Gesamtkosten").appFont(AppFont.body())`
    func appFont(_ style: AppFontStyle) -> some View {
        modifier(AppFontModifier(style: style))
    }
}
