//
//  ObjektDashboardViewModel.swift
//  NebenkostenApp — UI/Objekt/ViewModels
//
//  Leitet aus einer Immobilie die Anzeigewerte für das Dashboard ab:
//  4 Kachel-Status und den Completion-Ring-Prozent. Pure Value-Logik —
//  kein State, keine Mutationen. Für MVP: feste Soll-Werte pro Kachel.
//

import Foundation

@MainActor
struct ObjektDashboardViewModel {
    let immobilie: Immobilie

    init(immobilie: Immobilie) {
        self.immobilie = immobilie
    }

    // MARK: - Kachel-Werte

    struct KachelDaten {
        let status: KachelStatus
        let ist: Int
        let soll: Int
    }

    var mieter: KachelDaten {
        let einheiten = immobilie.wohneinheiten ?? []
        let aktiveEinheiten = einheiten.filter { $0.nutzungsart != .leerstand }
        let aktiveMieter = einheiten
            .flatMap { $0.mietverhaeltnisse ?? [] }
            .filter { $0.auszugAm == nil }
        let soll = max(aktiveEinheiten.count, 1)
        let ist = aktiveMieter.count
        return KachelDaten(status: status(ist: ist, soll: soll), ist: ist, soll: soll)
    }

    var zaehler: KachelDaten {
        let hauptzaehlerAnzahl = (immobilie.hauptzaehler ?? []).count
        let einheitZaehler = (immobilie.wohneinheiten ?? [])
            .flatMap { $0.zaehler ?? [] }
            .count
        // MVP-Soll: pro Einheit 3 (Kaltwasser, Warmwasser, WMZ) + 2 Hauptzähler
        // (Gas, Trinkwasser).
        let einheitenAnzahl = (immobilie.wohneinheiten ?? []).count
        let soll = max(einheitenAnzahl * 3 + 2, 1)
        let ist = hauptzaehlerAnzahl + einheitZaehler
        return KachelDaten(status: status(ist: ist, soll: soll), ist: ist, soll: soll)
    }

    var rechnungen: KachelDaten {
        let ist = (immobilie.rechnungen ?? []).count
        // MVP-Soll: Heizung, Wasser, Strom, Grundsteuer, Versicherung.
        let soll = 5
        return KachelDaten(status: status(ist: ist, soll: soll), ist: ist, soll: soll)
    }

    var kostenarten: KachelDaten {
        let ist = (immobilie.kostenarten ?? []).filter { $0.aktiv }.count
        // MVP-Soll: Heizung, Wasser, Grundsteuer, Versicherung, Müll.
        let soll = 5
        return KachelDaten(status: status(ist: ist, soll: soll), ist: ist, soll: soll)
    }

    // MARK: - Completion-Ring

    /// Durchschnitt der vier Kachel-Status (grün 1.0, gelb 0.5, rot 0.0).
    /// Gleichgewichtet im MVP.
    var completionProzent: Double {
        let werte = [mieter.status, zaehler.status, rechnungen.status, kostenarten.status]
            .map(\.prozent)
        return werte.reduce(0, +) / Double(werte.count)
    }

    // MARK: - Abrechnungsperiode

    /// Laufende Abrechnungsperiode relativ zu heute, berechnet aus
    /// immobilie.abrechnungsstartMonat/-Tag.
    var aktuellePeriode: (von: Date, bis: Date) {
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = TimeZone(identifier: "UTC")!

        let heute = Date()
        var startKomponenten = kalender.dateComponents([.year], from: heute)
        startKomponenten.month = immobilie.abrechnungsstartMonat
        startKomponenten.day = immobilie.abrechnungsstartTag
        let startHeuerDate = kalender.date(from: startKomponenten) ?? heute

        // Wenn heute noch vor dem Start dieses Jahres liegt, gehört es zur
        // Vorjahres-Periode.
        let startDatum: Date = heute < startHeuerDate
            ? kalender.date(byAdding: .year, value: -1, to: startHeuerDate) ?? startHeuerDate
            : startHeuerDate

        let endDatum = kalender.date(byAdding: DateComponents(year: 1, day: -1), to: startDatum)
            ?? startDatum

        return (startDatum, endDatum)
    }

    var periodeBezeichnung: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let periode = aktuellePeriode
        return "\(formatter.string(from: periode.von)) – \(formatter.string(from: periode.bis))"
    }

    // MARK: - Helfer

    private func status(ist: Int, soll: Int) -> KachelStatus {
        if soll <= 0 || ist >= soll { return .gruen }
        if ist == 0                 { return .rot }
        return .gelb
    }
}
