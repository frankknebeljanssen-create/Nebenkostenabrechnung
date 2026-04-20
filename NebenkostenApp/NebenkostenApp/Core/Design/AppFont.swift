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
    /// 16 pt / 500 — Row-Titel in Rechnungen/Belege (UI-Fix-2).
    static func bodyMedium16() -> AppFontStyle {
        .init(font: plexSans(.medium, 16), tracking: 0, uppercase: false)
    }
    static func bodySemi() -> AppFontStyle {
        .init(font: plexSans(.semibold, 15), tracking: 0, uppercase: false)
    }
    /// 17 pt / 600 — für Row-Titel nach UI-Fix-2 (Zielgruppe 50+).
    static func bodySemi17() -> AppFontStyle {
        .init(font: plexSans(.semibold, 17), tracking: -0.1, uppercase: false)
    }
    static func subtitle() -> AppFontStyle {
        .init(font: plexSans(.regular, 13), tracking: -0.1, uppercase: false)
    }
    /// 13 pt / 500 — größere Sub-Line für Row-Detail (UI-Fix-2).
    static func subtitleEmphasis() -> AppFontStyle {
        .init(font: plexSans(.medium, 13), tracking: 0, uppercase: false)
    }
    static func caption() -> AppFontStyle {
        .init(font: plexSans(.regular, 12), tracking: 0, uppercase: false)
    }
    /// 12 pt / 500 — für Meta-Zeilen (Datum / Periode) die lesbarer
    /// sein müssen als die 11pt-smallCaption (UI-Fix-2).
    static func captionEmphasis() -> AppFontStyle {
        .init(font: plexSans(.medium, 12), tracking: 0, uppercase: false)
    }
    static func captionMedium() -> AppFontStyle {
        .init(font: plexSans(.medium, 12), tracking: 0, uppercase: false)
    }
    /// 12pt / 600 — für StatusPill-Labels (UI-Fix-2a), damit
    /// "Validiert" / "KI-Vorschlag" ins Auge springt.
    static func captionSemi() -> AppFontStyle {
        .init(font: plexSans(.semibold, 12), tracking: 0, uppercase: false)
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
    /// ScopeStrip-Label — UI-Fix-2a: 15pt/semibold tracking 0.6,
    /// uppercase. Ein Tick größer + mehr Tracking, damit "EINHEIT
    /// · OG Wohnung" ohne Gewichtssprung fett genug rüberkommt.
    static func scopeStripLabel() -> AppFontStyle {
        .init(font: plexSans(.semibold, 15), tracking: 0.6, uppercase: true)
    }
    /// ScopeStrip rechter Mono-Text (m²) — UI-Fix-2: 13pt.
    static func scopeStripMono() -> AppFontStyle {
        .init(font: plexMono(.regular, 13), tracking: 0, uppercase: false)
    }
    /// Adress-Button oben in der AppNavBar — UI-Fix-2: 17pt/500.
    static func navAddress() -> AppFontStyle {
        .init(font: plexSans(.medium, 17), tracking: 0, uppercase: false)
    }
    /// Sub-Title unter dem NavBar-Titel — UI-Fix-2: 16pt/500.
    static func navSubtitle() -> AppFontStyle {
        .init(font: plexSans(.medium, 16), tracking: -0.1, uppercase: false)
    }
    static func micro() -> AppFontStyle {
        .init(font: plexSans(.regular, 10), tracking: 0.2, uppercase: false)
    }
    /// ScopePill (HAUS / KG / EG / OG) — sehr klein, bleibt
    /// Dekorations-Label und wird nicht weiter hochskaliert.
    static func scopePill() -> AppFontStyle {
        .init(font: plexSans(.semibold, 10), tracking: 0.3, uppercase: true)
    }
    /// Label "ANFANG" / "ENDE" / "VERBRAUCH" über einer Messzeile.
    /// UI-Fix-3: 11pt/600 tracking 0.3 — größer als Vorlage (10pt)
    /// wegen Zielgruppe 50+.
    static func messungLabel() -> AppFontStyle {
        .init(font: plexSans(.semibold, 11), tracking: 0.3, uppercase: true)
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
    /// 17 pt / 600 — Rechnungsbetrag-Mono in Row-Trailing.
    static func monoBetrag17() -> AppFontStyle {
        .init(font: plexMono(.semibold, 17), tracking: 0, uppercase: false)
    }
    /// 18 pt / 600 — Zählerstand-Messwerte. UI-Fix-2.
    static func monoMesswert() -> AppFontStyle {
        .init(font: plexMono(.semibold, 18), tracking: 0, uppercase: false)
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
