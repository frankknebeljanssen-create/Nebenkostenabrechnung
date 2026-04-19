//
//  Zeitraumabgrenzung.swift
//  NebenkostenApp — Calc-Layer
//
//  Zwei Modi der Zuordnung einer Rechnung zu einer Abrechnungsperiode:
//
//   - .zeitanteilig — tagesanteilige Verteilung über die Überlappung
//     von Rechnungs- und Abrechnungszeitraum (§ 556 BGB-konform).
//     Für 2025/2026 und später die saubere Lösung.
//
//   - .rechnungsdatum — die komplette Rechnung wird in die NK-Periode
//     gebucht, in der das Rechnungsdatum liegt. MVP-Vereinfachung für
//     die 2024/2025-Abrechnung.
//
//  Einziger erlaubter Import: Foundation.
//

import Foundation

enum Zeitraumabgrenzung {

    /// Tagesanteiliger Anteil einer Rechnung an einer Abrechnungsperiode.
    ///
    /// Ergebnis =
    ///   gesamtbetrag · (Überlappungstage / Rechnungstage)
    ///
    /// Bei fehlender Überlappung 0. Tage werden inklusive beider Enden
    /// gezählt: 01.11.–30.11. = 30 Tage.
    static func anteil(
        rechnungVon: Date,
        rechnungBis: Date,
        periodeVon: Date,
        periodeBis: Date,
        gesamtbetrag: Euro
    ) -> Euro {
        let ueberlappungVon = max(rechnungVon, periodeVon)
        let ueberlappungBis = min(rechnungBis, periodeBis)

        guard ueberlappungVon <= ueberlappungBis else { return 0 }

        let ueberlappungsTage = Decimal(tageZwischen(ueberlappungVon, ueberlappungBis))
        let rechnungsTage     = Decimal(tageZwischen(rechnungVon, rechnungBis))

        guard rechnungsTage > 0 else { return 0 }

        return gesamtbetrag * ueberlappungsTage / rechnungsTage
    }

    /// MVP-Modus: die Rechnung wird voll in die NK-Periode gebucht, in
    /// der das Rechnungsdatum liegt; außerhalb → 0. Keine tagesanteilige
    /// Verteilung. Für 2024/2025 als Default verwendet.
    static func anteilNachRechnungsdatum(
        rechnungsdatum: Date,
        periodeVon: Date,
        periodeBis: Date,
        gesamtbetrag: Euro
    ) -> Euro {
        (rechnungsdatum >= periodeVon && rechnungsdatum <= periodeBis)
            ? gesamtbetrag
            : 0
    }

    /// Anzahl Tage zwischen zwei Daten (inkl. beider Enden), z.B.
    /// 01.11. bis 30.11. = 30 Tage.
    private static func tageZwischen(_ von: Date, _ bis: Date) -> Int {
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = TimeZone(identifier: "UTC")!
        let vonAnfang = kalender.startOfDay(for: von)
        let bisAnfang = kalender.startOfDay(for: bis)
        let komponenten = kalender.dateComponents([.day], from: vonAnfang, to: bisAnfang)
        return (komponenten.day ?? 0) + 1
    }
}
