//
//  ObjektDashboardViewModel.swift
//  NebenkostenApp — UI/Objekt/ViewModels
//
//  Leitet aus einer Immobilie und einer aktiven Abrechnungsperiode die
//  Anzeigewerte für das Dashboard ab: 4 Kachel-Status und den
//  Completion-Ring-Prozent. Pure Value-Logik, kein State.
//
//  Zähler und Rechnungen werden periodenabhängig gezählt (Stände bzw.
//  Rechnungsdatum innerhalb der Periode). Mieter und Kostenarten sind
//  im MVP periodenunabhängig.
//

import Foundation

@MainActor
struct ObjektDashboardViewModel {
    let immobilie: Immobilie
    let aktivePeriode: Abrechnungsperiode?

    init(immobilie: Immobilie, aktivePeriode: Abrechnungsperiode? = nil) {
        self.immobilie = immobilie
        self.aktivePeriode = aktivePeriode
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
        // MVP-Scope: nur Wohnungs-Zähler, Hauptzähler der Liegenschaft
        // werden separat behandelt (Task später). Pro Zähler zwei Stände
        // erwartet (Anfangs- + Endstand in der aktiven Periode).
        let einheitZaehler = (immobilie.wohneinheiten ?? []).flatMap { $0.zaehler ?? [] }
        let ist = einheitZaehler
            .flatMap { $0.staende ?? [] }
            .filter { istInPeriode($0.ablesedatum) }
            .count
        let soll = max(einheitZaehler.count * 2, 1)
        return KachelDaten(status: status(ist: ist, soll: soll), ist: ist, soll: soll)
    }

    var rechnungen: KachelDaten {
        let ist = (immobilie.rechnungen ?? [])
            .filter { istInPeriode($0.rechnungsdatum) }
            .count
        let soll = 5
        return KachelDaten(status: status(ist: ist, soll: soll), ist: ist, soll: soll)
    }

    var kostenarten: KachelDaten {
        let ist = (immobilie.kostenarten ?? []).filter { $0.aktiv }.count
        let soll = 5
        return KachelDaten(status: status(ist: ist, soll: soll), ist: ist, soll: soll)
    }

    // MARK: - Completion-Ring

    var completionProzent: Double {
        let werte = [mieter.status, zaehler.status, rechnungen.status, kostenarten.status]
            .map(\.prozent)
        return werte.reduce(0, +) / Double(werte.count)
    }

    // MARK: - Perioden-Formatierung

    var periodeBezeichnung: String {
        guard let aktivePeriode else { return "Keine Periode" }
        return Self.formatiere(aktivePeriode)
    }

    static func formatiere(_ periode: Abrechnungsperiode) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "de_DE")
        return "\(formatter.string(from: periode.von)) – \(formatter.string(from: periode.bis))"
    }

    // MARK: - Helfer

    private func istInPeriode(_ datum: Date) -> Bool {
        guard let aktivePeriode else { return false }
        return datum >= aktivePeriode.von && datum <= aktivePeriode.bis
    }

    private func status(ist: Int, soll: Int) -> KachelStatus {
        if soll <= 0 || ist >= soll { return .gruen }
        if ist == 0                 { return .rot }
        return .gelb
    }
}
