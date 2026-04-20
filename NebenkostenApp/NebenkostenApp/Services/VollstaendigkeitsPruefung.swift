//
//  VollstaendigkeitsPruefung.swift
//  NebenkostenApp — Services
//
//  Übersetzt den aktuellen SwiftData-Bestand (Immobilie + Periode) in
//  eine Liste von DatenAnforderungen mit Status. Einzige Quelle der
//  Wahrheit für Dashboard-Kacheln, Inspektor-Sheet und Abrechnungs-
//  Service-Pre-Flight — so können alle drei Views identisch
//  entscheiden, ob die Abrechnung machbar ist.
//

import Foundation
import SwiftData

@MainActor
enum VollstaendigkeitsPruefung {

    /// Baut für die gegebene Immobilie + Periode die vollständige Liste
    /// der Anforderungen mit aktuellem Status. Reihenfolge: Stammdaten,
    /// Zählerstände, Rechnungen.
    static func pruefe(
        immobilie: Immobilie,
        periode: Abrechnungsperiode
    ) -> [AnforderungMitStatus] {
        var liste: [AnforderungMitStatus] = []
        liste.append(contentsOf: stammdatenAnforderungen(immobilie: immobilie))
        liste.append(contentsOf: zaehlerAnforderungen(immobilie: immobilie, periode: periode))
        liste.append(contentsOf: rechnungsAnforderungen(immobilie: immobilie, periode: periode))
        return liste
    }

    // MARK: - Stammdaten

    private static func stammdatenAnforderungen(immobilie: Immobilie) -> [AnforderungMitStatus] {
        var ergebnis: [AnforderungMitStatus] = []

        // 1. Gesamtfläche
        let flaeche = DatenAnforderung(
            id: "stammdaten-gesamtflaeche",
            kategorie: .stammdaten,
            titel: "Objekt-Gesamtfläche",
            details: "Summe aller Einheiten in m²",
            erforderlich: true
        )
        ergebnis.append(.init(
            anforderung: flaeche,
            status: immobilie.gesamtflaecheM2 > 0 ? .erfuellt : .offen,
            hinweis: nil
        ))

        // 2. Mindestens 1 Wohneinheit mit Fläche
        let einheiten = immobilie.wohneinheiten ?? []
        let einheitenMitFlaeche = einheiten.filter { $0.flaecheM2 > 0 }
        let einheitAnf = DatenAnforderung(
            id: "stammdaten-wohneinheiten",
            kategorie: .stammdaten,
            titel: "Wohneinheiten mit Fläche",
            details: "Pro Einheit Bezeichnung und m²",
            erforderlich: true
        )
        let einheitStatus: AnforderungsStatus
        let einheitHinweis: String?
        if einheitenMitFlaeche.isEmpty {
            einheitStatus = .offen
            einheitHinweis = nil
        } else if einheitenMitFlaeche.count < einheiten.count {
            einheitStatus = .teilweise
            let fehlen = einheiten.count - einheitenMitFlaeche.count
            einheitHinweis = "\(fehlen) Einheit\(fehlen == 1 ? "" : "en") ohne Fläche"
        } else {
            einheitStatus = .erfuellt
            einheitHinweis = nil
        }
        ergebnis.append(.init(
            anforderung: einheitAnf,
            status: einheitStatus,
            hinweis: einheitHinweis
        ))

        // 3. Aktives Mietverhältnis pro Einheit (außer Leerstand)
        let aktiveEinheiten = einheiten.filter { $0.nutzungsart != .leerstand }
        let einheitenMitMieter = aktiveEinheiten.filter { e in
            (e.mietverhaeltnisse ?? []).contains(where: { $0.auszugAm == nil })
        }
        let mieterAnf = DatenAnforderung(
            id: "stammdaten-mieter",
            kategorie: .stammdaten,
            titel: "Mieter je Einheit",
            details: "Aktives Mietverhältnis (außer Leerstand)",
            erforderlich: true
        )
        let mieterStatus: AnforderungsStatus
        let mieterHinweis: String?
        if aktiveEinheiten.isEmpty {
            mieterStatus = .offen
            mieterHinweis = nil
        } else if einheitenMitMieter.count < aktiveEinheiten.count {
            let fehlen = aktiveEinheiten.count - einheitenMitMieter.count
            mieterStatus = .teilweise
            mieterHinweis = "\(fehlen) Einheit\(fehlen == 1 ? "" : "en") ohne aktiven Mieter"
        } else {
            mieterStatus = .erfuellt
            mieterHinweis = nil
        }
        ergebnis.append(.init(
            anforderung: mieterAnf,
            status: mieterStatus,
            hinweis: mieterHinweis
        ))

        return ergebnis
    }

    // MARK: - Zählerstände

    private static func zaehlerAnforderungen(
        immobilie: Immobilie,
        periode: Abrechnungsperiode
    ) -> [AnforderungMitStatus] {
        let haupt = immobilie.hauptzaehler ?? []
        let wohnung = (immobilie.wohneinheiten ?? []).flatMap { $0.zaehler ?? [] }
        let alle = haupt + wohnung

        return alle.map { z -> AnforderungMitStatus in
            let titel = anzeigeNameZaehler(z)
            let einheitenName = z.wohneinheit?.bezeichnung ?? "Hauptzähler"
            let details = "\(einheitenName) · \(mediumName(z.medium))"
                + (z.seriennummer.isEmpty ? "" : " · SN \(z.seriennummer)")
            let anf = DatenAnforderung(
                id: "zaehler-\(z.id.uuidString)",
                kategorie: .zaehlerstand,
                titel: titel,
                details: details,
                erforderlich: true
            )
            let (status, hinweis) = zaehlerStatus(z, periode: periode)
            return .init(anforderung: anf, status: status, hinweis: hinweis)
        }
    }

    private static func zaehlerStatus(
        _ z: Zaehler,
        periode: Abrechnungsperiode
    ) -> (AnforderungsStatus, String?) {
        let inPeriode = (z.staende ?? [])
            .filter { $0.ablesedatum >= periode.von && $0.ablesedatum <= periode.bis }
            .sorted { $0.ablesedatum < $1.ablesedatum }

        if inPeriode.isEmpty {
            return (.offen, "Anfangs- und Endstand fehlen")
        }
        if inPeriode.count == 1 {
            return (.teilweise, "Nur ein Stand erfasst, Endstand fehlt")
        }
        if let first = inPeriode.first, let last = inPeriode.last,
           last.stand < first.stand {
            return (.teilweise, "Rücklauf: Endstand < Anfangsstand (Zählerwechsel prüfen)")
        }
        return (.erfuellt, nil)
    }

    private static func anzeigeNameZaehler(_ z: Zaehler) -> String {
        if !z.bezeichnung.isEmpty { return z.bezeichnung }
        let einheit = z.wohneinheit?.bezeichnung
        let basis = mediumName(z.medium)
        if let e = einheit, !e.isEmpty { return "\(basis) \(e)" }
        return "\(basis) Hauptzähler"
    }

    private static func mediumName(_ m: Medium) -> String {
        switch m {
        case .strom:         return "Strom"
        case .warmwasser:    return "Warmwasser"
        case .kaltwasser:    return "Kaltwasser"
        case .waermeenergie: return "Wärmemenge"
        case .gas:           return "Gas"
        case .oel:           return "Öl"
        }
    }

    // MARK: - Rechnungen

    private static func rechnungsAnforderungen(
        immobilie: Immobilie,
        periode: Abrechnungsperiode
    ) -> [AnforderungMitStatus] {
        let kostenarten = (immobilie.kostenarten ?? []).filter { $0.aktiv }
        let rechnungen = immobilie.rechnungen ?? []

        return kostenarten
            .sorted { $0.sortierung < $1.sortierung }
            .map { ka -> AnforderungMitStatus in
                let relevante = rechnungen.filter { r in
                    r.kostenart?.id == ka.id
                        && r.rechnungsdatum >= periode.von
                        && r.rechnungsdatum <= periode.bis
                }
                let anf = DatenAnforderung(
                    id: "rechnung-\(ka.id.uuidString)",
                    kategorie: .rechnung,
                    titel: ka.bezeichnung.isEmpty ? "Ohne Bezeichnung" : ka.bezeichnung,
                    details: rechnungsDetails(kostenart: ka, rechnungen: relevante),
                    erforderlich: true
                )
                let (status, hinweis) = rechnungStatus(
                    kostenart: ka, rechnungen: relevante
                )
                return .init(anforderung: anf, status: status, hinweis: hinweis)
            }
    }

    private static func rechnungsDetails(kostenart: Kostenart, rechnungen: [Rechnung]) -> String {
        if rechnungen.isEmpty {
            return "Mindestens eine Rechnung in der Periode"
        }
        let summe = rechnungen.reduce(Decimal(0)) { $0 + $1.betragBruttoEuro }
        let betrag = formatiere(summe)
        let n = rechnungen.count
        return "\(n) Rechnung\(n == 1 ? "" : "en") · \(betrag)"
    }

    private static func rechnungStatus(
        kostenart: Kostenart,
        rechnungen: [Rechnung]
    ) -> (AnforderungsStatus, String?) {
        if rechnungen.isEmpty { return (.offen, nil) }

        // Kostenart §35a-relevant: Warnung, wenn Lohnanteil fehlt.
        if kostenart.paragraph35a {
            let ohneLohn = rechnungen.filter { $0.lohnanteilBruttoEuro == nil }
            if !ohneLohn.isEmpty {
                return (.teilweise, "§35a-relevant, aber Lohnanteil bei \(ohneLohn.count) Rechnung\(ohneLohn.count == 1 ? "" : "en") fehlt")
            }
        }

        // Ungeprüfte Rechnungen zählen als "in Arbeit".
        let ungeprueft = rechnungen.filter { !$0.geprueft }
        if !ungeprueft.isEmpty {
            return (.teilweise, "\(ungeprueft.count) Rechnung\(ungeprueft.count == 1 ? "" : "en") noch nicht geprüft")
        }

        return (.erfuellt, nil)
    }

    private static func formatiere(_ d: Decimal) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = "EUR"
        nf.locale = Locale(identifier: "de_DE")
        return nf.string(from: NSDecimalNumber(decimal: d)) ?? "\(d) €"
    }

    // MARK: - Convenience

    /// Compact summary: wieviele erfüllt / teilweise / offen / nichtErwartet.
    struct Zusammenfassung: Sendable {
        let erfuellt: Int
        let teilweise: Int
        let offen: Int
        let nichtErwartet: Int
        var total: Int { erfuellt + teilweise + offen + nichtErwartet }
        var bereit: Bool { erfuellt == total - nichtErwartet && total > 0 }
    }

    static func zusammenfassung(fuer anforderungen: [AnforderungMitStatus]) -> Zusammenfassung {
        var e = 0, t = 0, o = 0, n = 0
        for a in anforderungen {
            switch a.status {
            case .erfuellt:       e += 1
            case .teilweise:      t += 1
            case .offen:          o += 1
            case .nichtErwartet:  n += 1
            }
        }
        return Zusammenfassung(erfuellt: e, teilweise: t, offen: o, nichtErwartet: n)
    }
}
