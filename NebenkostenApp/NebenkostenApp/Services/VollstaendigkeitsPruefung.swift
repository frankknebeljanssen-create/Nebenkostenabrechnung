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
        if let plausi = wmzPlausiAnforderung(immobilie: immobilie, periode: periode) {
            liste.append(plausi)
        }
        return liste
    }

    // MARK: - Stammdaten

    private static func stammdatenAnforderungen(immobilie: Immobilie) -> [AnforderungMitStatus] {
        var ergebnis: [AnforderungMitStatus] = []

        // 1. Gesamtfläche
        let flaeche = DatenAnforderung(
            id: "stammdaten-gesamtflaeche",
            kategorie: .stammdaten,
            titel: "Objekt-Gesamtfläche eintragen",
            details: "Summe aller Einheiten in m²",
            erforderlich: true
        )
        ergebnis.append(.init(
            anforderung: flaeche,
            status: immobilie.gesamtflaecheM2 > 0 ? .erfuellt : .offen,
            hinweis: nil,
            sprungZiel: .einstellungenObjekt
        ))

        // 2. Mindestens 1 Wohneinheit mit Fläche
        let einheiten = immobilie.wohneinheiten ?? []
        let einheitenMitFlaeche = einheiten.filter { $0.flaecheM2 > 0 }
        let einheitAnf = DatenAnforderung(
            id: "stammdaten-wohneinheiten",
            kategorie: .stammdaten,
            titel: "Wohneinheiten-Flächen eintragen",
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
            hinweis: einheitHinweis,
            sprungZiel: .einstellungenObjekt
        ))

        // 3. Aktives Mietverhältnis pro Einheit (außer Leerstand)
        let aktiveEinheiten = einheiten.filter { $0.nutzungsart != .leerstand }
        let einheitenMitMieter = aktiveEinheiten.filter { e in
            (e.mietverhaeltnisse ?? []).contains(where: { $0.auszugAm == nil })
        }
        let mieterAnf = DatenAnforderung(
            id: "stammdaten-mieter",
            kategorie: .stammdaten,
            titel: "Mieter eintragen",
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
        // Sprungziel für "Mieter je Einheit": erste Einheit ohne Mieter
        // als Fokus; falls alle erfüllt, springen wir trotzdem in die
        // Mieter-Section.
        let einheitOhneMieter = aktiveEinheiten.first(where: { e in
            !(e.mietverhaeltnisse ?? []).contains(where: { $0.auszugAm == nil })
        })
        let mieterSprungZiel: Sprungziel = einheitOhneMieter.map {
            .mieterVorauszahlung(einheitId: $0.bezeichnung)
        } ?? .einstellungenObjekt
        ergebnis.append(.init(
            anforderung: mieterAnf,
            status: mieterStatus,
            hinweis: mieterHinweis,
            sprungZiel: mieterSprungZiel
        ))

        // 4. Vorauszahlung je aktivem Mietverhältnis explizit erfasst.
        //    Strikte-Daten-Regel: 0 € ist erlaubt (Selbstnutzer), aber
        //    nur wenn `vorauszahlungErfasst == true`. Ein Default-0
        //    ohne Flag blockiert.
        let aktiveMietverhaeltnisse = einheiten
            .flatMap { $0.mietverhaeltnisse ?? [] }
            .filter { $0.auszugAm == nil }
        let vzAnf = DatenAnforderung(
            id: "stammdaten-vorauszahlung",
            kategorie: .stammdaten,
            titel: "Vorauszahlungen eintragen",
            details: "Monatsbetrag je Mieter aktiv gesetzt (0 erlaubt)",
            erforderlich: true
        )
        let vzStatus: AnforderungsStatus
        let vzHinweis: String?
        if aktiveMietverhaeltnisse.isEmpty {
            vzStatus = .nichtErwartet
            vzHinweis = nil
        } else {
            let nichtErfasst = aktiveMietverhaeltnisse.filter { !$0.vorauszahlungErfasst }
            if nichtErfasst.isEmpty {
                vzStatus = .erfuellt
                vzHinweis = nil
            } else {
                let n = nichtErfasst.count
                vzStatus = .offen
                vzHinweis = "\(n) Mieter ohne bestätigte Vorauszahlung (Defaultwert blockiert die Abrechnung)"
            }
        }
        // Sprungziel: erste Einheit ohne bestätigte VZ, sonst erste
        // aktive überhaupt. Das gibt dem User einen konkreten
        // Korrektur-Punkt.
        let vzEinheitId: String? = aktiveMietverhaeltnisse
            .first(where: { !$0.vorauszahlungErfasst })?
            .wohneinheit?.bezeichnung
            ?? aktiveMietverhaeltnisse.first?.wohneinheit?.bezeichnung
        let vzSprungZiel: Sprungziel? = vzEinheitId.map {
            .mieterVorauszahlung(einheitId: $0)
        }
        ergebnis.append(.init(
            anforderung: vzAnf,
            status: vzStatus,
            hinweis: vzHinweis,
            sprungZiel: vzSprungZiel
        ))

        // 5. Periode-Validität: von < bis.
        //    Der Check wird pro Periode aufgerufen — die Anforderung
        //    landet hier in den Stammdaten, weil sie objektweit gilt.
        let periodeAnf = DatenAnforderung(
            id: "stammdaten-periode",
            kategorie: .stammdaten,
            titel: "Abrechnungsperiode prüfen",
            details: "von-Datum liegt vor bis-Datum",
            erforderlich: true
        )
        let periodeStatus: AnforderungsStatus
        let periodeHinweis: String?
        if aktivePeriodeVonKleinerBis(immobilie: immobilie) {
            periodeStatus = .erfuellt
            periodeHinweis = nil
        } else {
            periodeStatus = .offen
            periodeHinweis = "Mindestens eine Periode hat von ≥ bis"
        }
        ergebnis.append(.init(
            anforderung: periodeAnf,
            status: periodeStatus,
            hinweis: periodeHinweis,
            sprungZiel: .einstellungenPeriode
        ))

        return ergebnis
    }

    /// Prüft, ob alle Abrechnungsperioden der Immobilie `von < bis`
    /// haben. Gibt `true` zurück wenn die Immobilie keine Perioden
    /// hat (nichtErwartet-Fall wird an anderer Stelle behandelt).
    private static func aktivePeriodeVonKleinerBis(immobilie: Immobilie) -> Bool {
        let perioden = immobilie.perioden ?? []
        return perioden.allSatisfy { $0.von < $0.bis }
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
            let titel = "Zählerstand erfassen: \(anzeigeNameZaehler(z))"
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
            return .init(
                anforderung: anf,
                status: status,
                hinweis: hinweis,
                sprungZiel: .zaehlerstandErfassen(zaehlerId: z.id)
            )
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
        // Strikte-Daten-Regel: ein Stand zählt nur, wenn er aktiv
        // erfasst wurde (`erfasstAm != nil`). Default-0 ohne Marker
        // blockiert die Berechnung, damit keine stillen Platzhalter
        // in die Abrechnung fließen.
        let erfasste = inPeriode.filter { $0.erfasstAm != nil }
        if erfasste.isEmpty {
            return (.offen, "Stände in Periode vorhanden, aber nicht aktiv erfasst")
        }
        if erfasste.count < inPeriode.count {
            let lose = inPeriode.count - erfasste.count
            return (.teilweise, "\(lose) Stand\(lose == 1 ? "" : "-Einträge") ohne Bestätigung (erfasstAm fehlt)")
        }
        if erfasste.count == 1 {
            return (.teilweise, "Nur ein Stand erfasst, Endstand fehlt")
        }
        if let first = erfasste.first, let last = erfasste.last,
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
                let kaName = ka.bezeichnung.isEmpty ? "Kostenart" : ka.bezeichnung
                let anf = DatenAnforderung(
                    id: "rechnung-\(ka.id.uuidString)",
                    kategorie: .rechnung,
                    titel: "Rechnung prüfen: \(kaName)",
                    details: rechnungsDetails(kostenart: ka, rechnungen: relevante),
                    erforderlich: true
                )
                let (status, hinweis) = rechnungStatus(
                    kostenart: ka, rechnungen: relevante
                )
                return .init(
                    anforderung: anf,
                    status: status,
                    hinweis: hinweis,
                    sprungZiel: .rechnungKostenart(kostenartId: ka.id)
                )
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

        // STRIKTE-DATEN-Regel: AI-Vorschlags-Rechnungen sind NICHT
        // berechnungstauglich. Eine einzige unvalidierte Rechnung
        // blockiert die gesamte Kostenart, damit der AbrechnungsService
        // keine halb-geratenen Zahlen in die Abrechnung nimmt.
        let unvalidiert = rechnungen.filter { !$0.validierungsStatus.istBerechnungstauglich }
        if !unvalidiert.isEmpty {
            return (.offen, "\(unvalidiert.count) KI-Vorschlag\(unvalidiert.count == 1 ? "" : "-Rechnungen") noch nicht validiert")
        }

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

    // MARK: - WMZ-Plausibilität (Warnung, kein Blocker)

    /// Prüft, ob die Summe der Wärmemengenzähler-Deltas in der
    /// Periode im erwarteten Bereich des Gas-Wärmeanteils liegt.
    /// Heuristik nach §9 HeizkostenV: Warmwasser-Anteil bei
    /// zentraler Anlage ca. 18 %, Rest (≈82 %) ist Heizung.
    /// Toleranz 85–115 % — außerhalb blinkt ein Warn-Hinweis
    /// (Schwere = `.warnung`, blockiert NICHT die Berechnung).
    ///
    /// Liefert `nil`, wenn die Regel nicht anwendbar ist (keine
    /// WMZ-Zähler, kein Gas-Verbrauch bekannt). Das tritt in der
    /// UI als "nicht relevant" auf.
    private static func wmzPlausiAnforderung(
        immobilie: Immobilie,
        periode: Abrechnungsperiode
    ) -> AnforderungMitStatus? {
        let wmz = alleZaehler(immobilie).filter { $0.medium == .waermeenergie }
        guard !wmz.isEmpty else { return nil }

        let wmzSumme = wmz.reduce(Decimal(0)) { acc, z in
            acc + deltaInPeriode(z, periode: periode)
        }

        let gasVerbrauch = (immobilie.rechnungen ?? [])
            .filter {
                $0.rechnungsdatum >= periode.von
                    && $0.rechnungsdatum <= periode.bis
                    && ($0.kostenart?.bezeichnung.lowercased().contains("heiz") == true
                        || $0.kostenart?.bezeichnung.lowercased().contains("gas") == true)
            }
            .compactMap { $0.verbrauchMenge }
            .reduce(Decimal(0), +)

        guard gasVerbrauch > 0 else { return nil }

        let heizAnteilFaktor = Decimal(string: "0.82") ?? 0
        let erwartet = gasVerbrauch * heizAnteilFaktor
        let unten    = erwartet * (Decimal(string: "0.85") ?? 0)
        let oben     = erwartet * (Decimal(string: "1.15") ?? 0)

        let anf = DatenAnforderung(
            id: "plausi-wmz",
            kategorie: .zaehlerstand,
            titel: "Wärmemengenzähler prüfen",
            details: "WMZ-Summe sollte 85–115 % des Gas-Heizanteils entsprechen",
            erforderlich: false
        )

        if wmzSumme >= unten && wmzSumme <= oben {
            return .init(
                anforderung: anf,
                status: .erfuellt,
                hinweis: nil,
                sprungZiel: .wmzPlausi,
                schwere: .warnung
            )
        }

        let prozent = prozentAbweichung(gemessen: wmzSumme, erwartet: erwartet)
        let hinweis = "WMZ-Summe bei \(prozent) des Gas-Heizanteils (85–115 % erwartet)"
        return .init(
            anforderung: anf,
            status: .teilweise,
            hinweis: hinweis,
            sprungZiel: .wmzPlausi,
            schwere: .warnung
        )
    }

    // MARK: - Interne Helfer

    private static func alleZaehler(_ immobilie: Immobilie) -> [Zaehler] {
        let haupt = immobilie.hauptzaehler ?? []
        let wohnung = (immobilie.wohneinheiten ?? []).flatMap { $0.zaehler ?? [] }
        return haupt + wohnung
    }

    private static func deltaInPeriode(_ z: Zaehler, periode: Abrechnungsperiode) -> Decimal {
        let staende = (z.staende ?? [])
            .filter { $0.ablesedatum >= periode.von && $0.ablesedatum <= periode.bis }
            .sorted { $0.ablesedatum < $1.ablesedatum }
        guard let first = staende.first, let last = staende.last, first.id != last.id else {
            return 0
        }
        return max(0, last.stand - first.stand)
    }

    private static func prozentAbweichung(gemessen: Decimal, erwartet: Decimal) -> String {
        guard erwartet > 0 else { return "—" }
        let faktor = (gemessen as NSDecimalNumber).doubleValue
            / (erwartet as NSDecimalNumber).doubleValue
        return String(format: "%.0f %%", faktor * 100)
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
