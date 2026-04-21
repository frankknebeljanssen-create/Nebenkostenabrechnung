//
//  AppFont.swift
//  NebenkostenApp — Core/Design
//
//  Zentrale Typografie-Skala nach design_handoff/typografie-spec.html.
//  Jede Style-Funktion liefert ein `AppFontStyle`-Value, das Font +
//  Tracking + optional Textcase bündelt. Konsumiert wird es per
//  `.appFont(_:)`-Modifier auf jeder Text- oder Label-View.
//
//  Struktur: die Spec hat pro Screen eine Tabelle. Jede Screen-Rolle
//  bekommt ihre eigene Methode — das macht Drift sichtbar und beugt
//  Copy-Paste-Fehlern vor. Generische Rollen wandern in `Basis`.
//
//  Families:
//    IBMPlexSans — Body / Titel / Labels (Gewichte 400/500/600, 700
//                  nicht gebundelt)
//    IBMPlexMono — alle Zahlen, Datumsangaben, Beträge, m², Prozent
//                  (Gewichte 400/500/600 — KEIN 700 laut Spec)
//
//  Regel "Zahlen = Mono, Text = Sans, keine Mischformen in einer
//  Zeile" — siehe Core/Design/TextComponents.swift für Helpers.
//

import SwiftUI

struct AppFontStyle: Equatable {
    let font: Font
    let tracking: CGFloat
    let uppercase: Bool
}

enum AppFont {

    // MARK: - Basis (generisch, screen-unabhängig)

    enum Basis {
        /// 30pt / 600 / tracking −0.6 — Screen-Titel in allen Screens.
        static func displayTitle() -> AppFontStyle {
            .init(font: plexSans(.semibold, 30), tracking: -0.6, uppercase: false)
        }
        /// 22pt / 600 / tracking −0.3 — Perioden-Header im HomeScreen.
        /// Iterativ kleiner geworden (ursprünglich 40, dann 26,
        /// jetzt 22) — der Zeitraum bleibt Orientierung oben, aber
        /// die Objekt-Cards übernehmen die visuelle Führung.
        static func periodenHeader() -> AppFontStyle {
            .init(font: plexSans(.semibold, 22), tracking: -0.3, uppercase: false)
        }
        /// Mono 14pt / 400 — Datum unter dem Perioden-Header.
        /// Nochmal +1 pt gegenüber der ersten Feedback-Iteration,
        /// damit das Zeitraum-Label als Sub-Orientierung klar
        /// ablesbar bleibt (Gerätetest 50+).
        static func periodenDatum() -> AppFontStyle {
            .init(font: plexMono(.regular, 14), tracking: 0, uppercase: false)
        }
        /// 14pt / 600 / tracking 0.5 UPPER — Card-Header der
        /// Home-Carousels („OBJEKT", „WOHNEINHEIT"). Gegenüber
        /// dem generischen `kartenKicker` (12 pt / textTertiary)
        /// um 2 pt größer und in `text`-Farbe — der Header soll
        /// klar als Abschnitts-Titel lesbar sein.
        static func homeCardHeader() -> AppFontStyle {
            .init(font: plexSans(.semibold, 14), tracking: 0.5, uppercase: true)
        }
        /// 12pt / 600 / tracking 0.6 UPPER — Sektions-Kicker
        /// ("ABRECHNUNGSPERIODE", "WÄRME" usw.).
        static func kicker() -> AppFontStyle {
            .init(font: plexSans(.semibold, 12), tracking: 0.6, uppercase: true)
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
            .init(font: plexSans(.regular, 13), tracking: 0, uppercase: false)
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
        /// 10pt / 400 / tracking 0.3 — Meta-Labels.
        static func micro() -> AppFontStyle {
            .init(font: plexSans(.regular, 10), tracking: 0.3, uppercase: false)
        }
        /// 22pt / 600 — große Mono-Zahl (Dashboard-Saldo,
        /// Fortschritts-Prozent).
        static func monoLarge() -> AppFontStyle {
            .init(font: plexMono(.semibold, 22), tracking: 0, uppercase: false)
        }
        /// 24pt / 600 — Ergebnis-Hero in Abrechnung-Detail (Spec).
        static func monoHero() -> AppFontStyle {
            .init(font: plexMono(.semibold, 24), tracking: 0, uppercase: false)
        }
        /// 19pt / 600 / tracking −0.3 — KPI-Wert Dashboard.
        static func monoStat() -> AppFontStyle {
            .init(font: plexMono(.semibold, 19), tracking: -0.3, uppercase: false)
        }
        /// 15pt / 500 — Mono Body.
        static func monoBody() -> AppFontStyle {
            .init(font: plexMono(.medium, 15), tracking: 0, uppercase: false)
        }
        /// 15pt / 600 — Mono Body SemiBold, für Rechnungs-Betrag
        /// und Validierungs-Feld-Werte (Zahlen-Variante).
        static func monoBodySemi() -> AppFontStyle {
            .init(font: plexMono(.semibold, 15), tracking: 0, uppercase: false)
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
    }

    // MARK: - Rechnungen-Screen (Spec-Tabelle zeilengenau)

    enum Rechnungen {
        static func screenTitel() -> AppFontStyle { Basis.displayTitle() }
        /// 13pt / 400 — "11 Rechnungen · 2025".
        static func subZeile() -> AppFontStyle {
            .init(font: plexSans(.regular, 13), tracking: 0, uppercase: false)
        }
        /// 14pt / 500 — Adress-Button oben ("Bahnhofstr. 37 ▾").
        static func adresseBtn() -> AppFontStyle {
            .init(font: plexSans(.medium, 14), tracking: 0, uppercase: false)
        }
        /// 12pt / 500 / tracking 0.2 UPPER — "OBJEKT · GESAMTES HAUS".
        static func scopeLabel() -> AppFontStyle {
            .init(font: plexSans(.medium, 12), tracking: 0.2, uppercase: true)
        }
        /// Mono 11pt / 400 — "284 m²".
        static func scopeM2() -> AppFontStyle { Basis.monoSmall() }
        /// 14pt / 400 — Suchfeld-Input.
        static func suchFeld() -> AppFontStyle {
            .init(font: plexSans(.regular, 14), tracking: 0, uppercase: false)
        }
        /// 12pt / 600 / tracking 0.5 UPPER — "Heizung & Warmwasser".
        static func kostenartHeader() -> AppFontStyle {
            .init(font: plexSans(.semibold, 12), tracking: 0.5, uppercase: true)
        }
        /// Mono 12pt / 600 — Kategorie-Summe ("4.127,84 €").
        static func kostenartSumme() -> AppFontStyle {
            .init(font: plexMono(.semibold, 12), tracking: 0, uppercase: false)
        }
        /// 15pt / 500 — Aussteller ("GASAG AG").
        static func issuer() -> AppFontStyle { Basis.bodyMedium() }
        /// Mono 15pt / 600 — Betrag ("4.127,84 €").
        static func betrag() -> AppFontStyle { Basis.monoBodySemi() }
        /// Mono 11pt / 400 — "18.01.2026 · 01.01.2025 – 31.12.2025".
        static func datumPeriode() -> AppFontStyle { Basis.monoSmall() }
        /// 11pt / 600 / tracking 0.1 — Status-Pill-Text.
        static func statusPillText() -> AppFontStyle {
            .init(font: plexSans(.semibold, 11), tracking: 0.1, uppercase: false)
        }
        /// 14pt / 500 — "+ Rechnung manuell hinzufügen".
        static func rechnungManuellHinzu() -> AppFontStyle {
            .init(font: plexSans(.medium, 14), tracking: 0, uppercase: false)
        }
    }

    // MARK: - Dashboard / Übersicht

    enum Dashboard {
        static func screenTitel() -> AppFontStyle { Basis.displayTitle() }
        /// 12pt / 600 / tracking 0.6 UPPER — "ABRECHNUNGSPERIODE".
        static func kartenKicker() -> AppFontStyle { Basis.kicker() }
        /// 11pt / 400 / tracking 0.2 — "Umlagefähige Kosten".
        static func kpiLabel() -> AppFontStyle {
            .init(font: plexSans(.regular, 11), tracking: 0.2, uppercase: false)
        }
        /// Mono 19pt / 600 / tracking −0.3 — "13.576,12 €".
        static func kpiWert() -> AppFontStyle { Basis.monoStat() }
        /// Mono 22pt / 600 — "93%".
        static func fortschrittProzent() -> AppFontStyle { Basis.monoLarge() }
        /// 15pt / 500 — "Endstände aller Zähler erfasst".
        static func offenerPunktTitel() -> AppFontStyle { Basis.bodyMedium() }
        /// 12pt / 400 — "7 von 9 — Warmwasser OG …".
        static func offenerPunktDetail() -> AppFontStyle { Basis.caption() }
        /// 15pt / 600 — Einheits-Karte-Titel "KG Gewerbe".
        static func einheitTitel() -> AppFontStyle { Basis.bodySemi() }
        /// 13pt / 400 — Mieter-Name.
        static func einheitMieter() -> AppFontStyle { Basis.subtitle() }
        /// Mono 14pt / 600 — Vorauszahlung "180,00 €".
        static func einheitVorauszahlung() -> AppFontStyle {
            .init(font: plexMono(.semibold, 14), tracking: 0, uppercase: false)
        }
        /// Mono 22pt / 600 — Nachzahlungs-Saldo "− 5.114,92 €".
        static func nachzahlungSaldo() -> AppFontStyle { Basis.monoLarge() }
    }

    // MARK: - Zähler-Screen

    enum Zaehler {
        /// 12pt / 600 / tracking 0.6 UPPER — "WÄRME".
        static func mediumUeberschrift() -> AppFontStyle { Basis.kicker() }
        /// Mono 11pt / 400 — Counter "1".
        static func mediumCounter() -> AppFontStyle { Basis.monoSmall() }
        /// 10pt / 600 / tracking 0.3 UPPER — Einheit-Chip "KG".
        static func einheitChip() -> AppFontStyle {
            .init(font: plexSans(.semibold, 10), tracking: 0.3, uppercase: true)
        }
        /// 14pt / 500 — "Heizraum KG".
        static func bezeichnung() -> AppFontStyle {
            .init(font: plexSans(.medium, 14), tracking: 0, uppercase: false)
        }
        /// 11pt / 400 — "Wärmemengenzähler zentral".
        static func typ() -> AppFontStyle { Basis.smallCaption() }
        /// 10pt / 400 / tracking 0.3 UPPER — "ANFANG / ENDE / VERBRAUCH".
        static func messwertLabel() -> AppFontStyle {
            .init(font: plexSans(.regular, 10), tracking: 0.3, uppercase: true)
        }
        /// Mono 10pt / 400 — "02.01".
        static func datumAnfangEnde() -> AppFontStyle { Basis.monoMicro() }
        /// Mono 14pt / 600 — "382.471".
        static func standZahl() -> AppFontStyle {
            .init(font: plexMono(.semibold, 14), tracking: 0, uppercase: false)
        }
        /// Mono 10pt / 400 — "kWh".
        static func verbrauchEinheit() -> AppFontStyle { Basis.monoMicro() }
    }

    // MARK: - Abrechnung (Einheit-Detail)

    enum Abrechnung {
        /// 11pt / 400 / tracking 0.5 UPPER — "Abrechnung 2025 · OG".
        static func kopfKicker() -> AppFontStyle {
            .init(font: plexSans(.regular, 11), tracking: 0.5, uppercase: true)
        }
        /// 17pt / 600 — Mietername "Familie Pfaffenbach".
        static func kopfName() -> AppFontStyle {
            .init(font: plexSans(.semibold, 17), tracking: 0, uppercase: false)
        }
        /// 13pt / 400 — Adresse + Periode.
        static func kopfAdresse() -> AppFontStyle { Basis.subtitle() }
        /// 13pt / 500 — Position-Label "Heizung & Warmwasser".
        static func positionLabel() -> AppFontStyle {
            .init(font: plexSans(.medium, 13), tracking: 0, uppercase: false)
        }
        /// Mono 13pt / 600 — Position-Betrag "1.234,56 €".
        static func positionBetrag() -> AppFontStyle {
            .init(font: plexMono(.semibold, 13), tracking: 0, uppercase: false)
        }
        /// Mono 10pt / 400 — Position-Meta "Wohnfläche · 34,5 %".
        static func positionMeta() -> AppFontStyle { Basis.monoMicro() }
        /// 15pt / 600 — Ergebnis-Label "Nachzahlung Mieter".
        static func ergebnisLabel() -> AppFontStyle { Basis.bodySemi() }
        /// Mono 24pt / 600 — Ergebnis-Betrag-Hero.
        static func ergebnisBetrag() -> AppFontStyle { Basis.monoHero() }
        /// 15pt / 600 — Primär-Button "Als PDF exportieren".
        static func primaerButton() -> AppFontStyle { Basis.bodySemi() }
    }

    // MARK: - Dokumente / Validierung

    enum Dokumente {
        /// 15pt / 600 — Scan-Button-Titel "Beleg scannen".
        static func scanButtonTitel() -> AppFontStyle { Basis.bodySemi() }
        /// 12pt / 400 — Scan-Button-Sub "Foto → OCR → …".
        static func scanButtonSub() -> AppFontStyle { Basis.caption() }
        /// 14pt / 500 — Dateiname "GASAG_Jahresrechnung_2025.pdf".
        static func dateiname() -> AppFontStyle {
            .init(font: plexSans(.medium, 14), tracking: 0, uppercase: false)
        }
        /// Mono 10pt / 400 — Seitenzähler "4 S.".
        static func seitenzaehler() -> AppFontStyle { Basis.monoMicro() }
        /// 12pt / 600 / tracking 0.4 UPPER — "Ebene 1 · Rohdaten".
        static func ebeneLabel() -> AppFontStyle {
            .init(font: plexSans(.semibold, 12), tracking: 0.4, uppercase: true)
        }
        /// Mono 10.5pt / 400 — OCR-Volltext. SwiftUI akzeptiert
        /// fractional sizes.
        static func ocrVolltext() -> AppFontStyle {
            .init(font: plexMono(.regular, 10.5), tracking: 0, uppercase: false)
        }
        /// 15pt / 500 — Feld-Wert Sans ("GASAG AG").
        static func feldWertSans() -> AppFontStyle { Basis.bodyMedium() }
        /// Mono 15pt / 500 — Feld-Wert Zahl ("4.127,84 €").
        static func feldWertMono() -> AppFontStyle { Basis.monoBody() }
        /// Mono 10pt / 400 — Konfidenz "· 94 % Konfidenz".
        static func konfidenz() -> AppFontStyle { Basis.monoMicro() }
    }

    // MARK: - Navigation & Chrome

    enum Chrome {
        /// 9.5pt / 500 (aktiv 600) — TabBar-Labels. Wird via UIKit
        /// `UITabBarAppearance` gesetzt, nicht über SwiftUI-AppFont.
        /// Der Wert steht hier als Referenz + für Tests.
        static func tabBarLabel() -> AppFontStyle {
            .init(font: plexSans(.medium, 9.5), tracking: 0, uppercase: false)
        }
        /// 12pt / 500 / tracking 0.2 — ScopeStrip-Label.
        static func scopeStreifen() -> AppFontStyle {
            .init(font: plexSans(.medium, 12), tracking: 0.2, uppercase: true)
        }
        /// Mono 11pt / 400 — ScopeStrip-m².
        static func scopeStreifenM2() -> AppFontStyle { Basis.monoSmall() }
        /// 17pt / 600 — Sheet-Titel ("Scope wechseln").
        static func sheetTitel() -> AppFontStyle {
            .init(font: plexSans(.semibold, 17), tracking: 0, uppercase: false)
        }
        /// 11pt / 600 / tracking 0.1 — generische Status-Pill.
        static func statusPill() -> AppFontStyle {
            .init(font: plexSans(.semibold, 11), tracking: 0.1, uppercase: false)
        }
    }

    // MARK: - Legacy-Aliases (rückwärts-kompatibel, Spec-Werte)
    //
    // Bestehende Views benutzen diese Top-Level-Funktionen. Sie
    // delegieren ab sofort auf die Screen-Enums — und liefern damit
    // automatisch die Spec-Werte. Neue Views sollten direkt die
    // Screen-Enums ansprechen (z.B. `AppFont.Rechnungen.issuer()`).

    static func navTitle() -> AppFontStyle        { Basis.displayTitle() }
    static func navTitleCompact() -> AppFontStyle {
        .init(font: plexSans(.semibold, 26), tracking: -0.5, uppercase: false)
    }
    static func heroSaldo() -> AppFontStyle       { Basis.monoHero() }
    static func statValue() -> AppFontStyle       { Basis.monoStat() }

    static func body() -> AppFontStyle            { Basis.body() }
    static func bodyMedium() -> AppFontStyle      { Basis.bodyMedium() }
    static func bodySemi() -> AppFontStyle        { Basis.bodySemi() }
    static func subtitle() -> AppFontStyle        { Basis.subtitle() }
    static func caption() -> AppFontStyle         { Basis.caption() }
    static func captionMedium() -> AppFontStyle   { Basis.captionMedium() }
    static func smallCaption() -> AppFontStyle    { Basis.smallCaption() }
    static func smallCaptionSemi() -> AppFontStyle {
        .init(font: plexSans(.semibold, 11), tracking: 0, uppercase: false)
    }
    static func uppercaseLabel() -> AppFontStyle  { Basis.kicker() }
    static func micro() -> AppFontStyle           { Basis.micro() }

    static func monoLarge() -> AppFontStyle       { Basis.monoLarge() }
    static func monoHero() -> AppFontStyle        { Basis.monoHero() }
    static func monoStat() -> AppFontStyle        { Basis.monoStat() }
    static func monoBody() -> AppFontStyle        { Basis.monoBody() }
    static func monoCaption() -> AppFontStyle     { Basis.monoCaption() }
    static func monoSmall() -> AppFontStyle       { Basis.monoSmall() }
    static func monoMicro() -> AppFontStyle       { Basis.monoMicro() }

    // — UI-Fix-2/3-Aliases, jetzt auf Spec-Werte zurückgemappt. —
    // Die alten Bumps (17/16 pt etc.) sind aufgelöst. Die Aliases
    // bleiben als Brücke, bis die Views in Commit 2 auf die Screen-
    // Enums umgestellt sind.

    /// → Rechnungen.adresseBtn (14pt/500).
    static func navAddress() -> AppFontStyle       { Rechnungen.adresseBtn() }
    /// → Rechnungen.subZeile (13pt/400).
    static func navSubtitle() -> AppFontStyle      { Rechnungen.subZeile() }
    /// → Chrome.scopeStreifen (12pt/500 tracking 0.2 UPPER).
    static func scopeStripLabel() -> AppFontStyle  { Chrome.scopeStreifen() }
    /// → Chrome.scopeStreifenM2 (Mono 11pt/400).
    static func scopeStripMono() -> AppFontStyle   { Chrome.scopeStreifenM2() }
    /// → Rechnungen.issuer (15pt/500).
    static func bodyMedium16() -> AppFontStyle     { Rechnungen.issuer() }
    /// → Abrechnung.kopfName (17pt/600) für Row-Titel-Emphasis.
    /// Kein direktes Spec-Pendant für Zähler-Bezeichnung (14pt/500) —
    /// dort in Commit 2 auf Zaehler.bezeichnung umstellen.
    static func bodySemi17() -> AppFontStyle       { Abrechnung.kopfName() }
    /// → Rechnungen.betrag (Mono 15pt/600).
    static func monoBetrag17() -> AppFontStyle     { Rechnungen.betrag() }
    /// → Zaehler.standZahl (Mono 14pt/600).
    static func monoMesswert() -> AppFontStyle     { Zaehler.standZahl() }
    /// → Basis.subtitle (13pt/400). Die UI-Fix-Variante war 13pt/500.
    /// Spec sagt 13pt/400 — kein extra weight.
    static func subtitleEmphasis() -> AppFontStyle { Basis.subtitle() }
    /// → Rechnungen.datumPeriode (Mono 11pt/400). Die UI-Fix-Variante
    /// war 12pt/500 Sans — Font UND Größe ändern sich.
    static func captionEmphasis() -> AppFontStyle  { Rechnungen.datumPeriode() }
    /// → Rechnungen.statusPillText (11pt/600 tracking 0.1).
    static func captionSemi() -> AppFontStyle      { Rechnungen.statusPillText() }
    /// → Zaehler.einheitChip (10pt/600 tracking 0.3 UPPER).
    static func scopePill() -> AppFontStyle        { Zaehler.einheitChip() }
    /// → Zaehler.messwertLabel (10pt/400 tracking 0.3 UPPER).
    static func messungLabel() -> AppFontStyle     { Zaehler.messwertLabel() }

    // MARK: - Intern — Plex-Schnitte

    /// Gewichte, die wir gebundelt haben. Plex Mono weight 700 ist
    /// laut Spec verboten — `.bold`/.heavy auf Mono-Fonts werden
    /// daher nicht unterstützt.
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
    /// Beispiel: `Text("GASAG AG").appFont(AppFont.Rechnungen.issuer())`
    func appFont(_ style: AppFontStyle) -> some View {
        modifier(AppFontModifier(style: style))
    }
}
