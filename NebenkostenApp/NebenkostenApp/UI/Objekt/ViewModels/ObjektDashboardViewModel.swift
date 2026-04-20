//
//  ObjektDashboardViewModel.swift
//  NebenkostenApp — UI/Objekt/ViewModels
//
//  Übersetzt Immobilie + Periode in Dashboard-Anzeigewerte. Greift auf
//  VollstaendigkeitsPruefung zurück — dieselbe Quelle wie Inspektor-
//  Sheet und AbrechnungsService-Pre-Flight.
//

import Foundation

@MainActor
struct ObjektDashboardViewModel {
    let immobilie: Immobilie
    let aktivePeriode: Abrechnungsperiode?
    let anforderungen: [AnforderungMitStatus]

    init(immobilie: Immobilie, aktivePeriode: Abrechnungsperiode? = nil) {
        self.immobilie = immobilie
        self.aktivePeriode = aktivePeriode
        if let p = aktivePeriode {
            self.anforderungen = VollstaendigkeitsPruefung.pruefe(
                immobilie: immobilie, periode: p
            )
        } else {
            self.anforderungen = []
        }
    }

    // MARK: - Kacheln

    struct KachelDaten: Sendable {
        let erledigt: Int
        let inArbeit: Int
        let offen: Int

        var total: Int { erledigt + inArbeit + offen }

        var status: KachelStatus {
            if total == 0 { return .gelb }
            if offen == 0 && inArbeit == 0 { return .gruen }
            if erledigt == 0 && inArbeit == 0 { return .rot }
            return .gelb
        }
    }

    /// Mieter: pro aktiver Einheit ein "Mieter vorhanden"-Check.
    var mieter: KachelDaten {
        let einheiten = (immobilie.wohneinheiten ?? [])
            .filter { $0.nutzungsart != .leerstand }
        let mit = einheiten.filter { e in
            (e.mietverhaeltnisse ?? []).contains { $0.auszugAm == nil }
        }.count
        let ohne = einheiten.count - mit
        return KachelDaten(erledigt: mit, inArbeit: 0, offen: ohne)
    }

    var zaehler: KachelDaten {
        anforderungen
            .filter { $0.anforderung.kategorie == .zaehlerstand }
            .kachelCounts
    }

    var rechnungen: KachelDaten {
        anforderungen
            .filter { $0.anforderung.kategorie == .rechnung }
            .kachelCounts
    }

    /// Kostenarten: rein informativ, kein "offen/erledigt" sondern die
    /// Anzahl aktiver Kostenarten — Stammdaten-Konfig.
    var kostenarten: KachelDaten {
        let aktiv = (immobilie.kostenarten ?? []).filter(\.aktiv).count
        return KachelDaten(erledigt: aktiv, inArbeit: 0, offen: 0)
    }

    // MARK: - Fortschritt / Zusammenfassung

    var zusammenfassung: VollstaendigkeitsPruefung.Zusammenfassung {
        VollstaendigkeitsPruefung.zusammenfassung(fuer: anforderungen)
    }

    /// Sind alle Anforderungen erledigt? Basis für den Pre-Flight-Check
    /// vor PDF-Erzeugung.
    var bereitZurAbrechnung: Bool { zusammenfassung.bereit }

    /// Der Schreibkommentar unter dem Fortschrittsbalken.
    var bereitschaftsText: String {
        let z = zusammenfassung
        if z.total == 0 { return "Keine Periode gewählt." }
        if z.bereit {
            return "Bereit zur Abrechnung."
        }
        let fehlt = z.offen + z.teilweise
        return "Abrechnung kann noch nicht erstellt werden. "
            + "\(fehlt) Eintrag\(fehlt == 1 ? "" : "e") \(fehlt == 1 ? "fehlt" : "fehlen") noch."
    }

    var fortschrittsText: String {
        let z = zusammenfassung
        var teile: [String] = ["\(z.erfuellt) von \(z.total - z.nichtErwartet) Einträgen vollständig"]
        if z.teilweise > 0 {
            teile.append("\(z.teilweise) in Arbeit")
        }
        if z.offen > 0 {
            teile.append("\(z.offen) offen")
        }
        return teile.joined(separator: ", ")
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
}

// MARK: - Array-Helper

private extension Array where Element == AnforderungMitStatus {
    var kachelCounts: ObjektDashboardViewModel.KachelDaten {
        var e = 0, a = 0, o = 0
        for item in self {
            switch item.status {
            case .erfuellt:       e += 1
            case .teilweise:      a += 1
            case .offen:          o += 1
            case .nichtErwartet:  break
            }
        }
        return ObjektDashboardViewModel.KachelDaten(erledigt: e, inArbeit: a, offen: o)
    }
}
