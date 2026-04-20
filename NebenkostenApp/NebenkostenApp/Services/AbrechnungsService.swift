//
//  AbrechnungsService.swift
//  NebenkostenApp — Services
//
//  Brücke zwischen @Model-SwiftData und Calc-Layer. Übersetzt Immobilie +
//  Periode in AbrechnungsInput, ruft AbrechnungsAggregator auf und baut pro
//  aktivem Mieter eine Mieterabrechnung.
//
//  Heizkosten-Pool (§7 HeizkostenV): Alle Rechnungen der Kostenart mit
//  Umlageschlüssel `.heizkosten3070` werden gesammelt. Die teuerste Rechnung
//  ohne Lohnanteil ist die Brennstoff-Hauptrechnung (GASAG); der Rest bildet
//  den Heiz-Nebenkosten-Pool und wird kWh-anteilig auf Heiz- und Warmwasser-
//  Topf gesplittet. Das entspricht der Bahnhofstr.-37-Struktur (Leske-
//  Wartung + Kirschnereit-Schornsteinfeger als Pool).
//
//  §35a: Pro Rechnung aus `lohnanteilBruttoEuro` abgeleitet, flächenanteilig
//  auf die Einheit verteilt. Rechnungen ohne Lohnanteil liefern 0 €.
//

import Foundation
import SwiftData

struct Mieterposition: Identifiable, Hashable, Sendable {
    let id: UUID
    let kostenart: String
    let gesamtkostenEuro: Decimal
    let mieteranteilEuro: Decimal
    let verteilerschluesselText: String
    let paragraph35aAnteilEuro: Decimal
}

/// Optionale Detaildaten der Heiz-/Warmwasser-Berechnung einer Einheit.
/// Wird im PDF als "Anlage 1 Heizkostenabrechnung" gerendert.
struct HeizungsAnlagenDetails: Hashable, Sendable {
    let heizkostenTopfEuro: Decimal
    let warmwasserkostenTopfEuro: Decimal
    let qHeizungKwh: Double
    let qWarmwasserKwh: Double
    let wmzAnteilKwh: Double
    let wwVerbrauchM3: Double
    let flaechenanteilHeizungEuro: Decimal
    let verbrauchsanteilHeizungEuro: Decimal
    let flaechenanteilWarmwasserEuro: Decimal
    let verbrauchsanteilWarmwasserEuro: Decimal
    let heizungVerteilerschluesselText: String
    let warmwasserVerteilerschluesselText: String
}

struct Mieterabrechnung: Identifiable, Hashable, Sendable {
    let id: UUID
    let mieterID: UUID
    let mieterName: String
    let mieterAnschrift: String
    let mieterEmail: String
    let einheitBezeichnung: String
    let einheitFlaecheM2: Decimal
    let positionen: [Mieterposition]
    let gesamtkostenEuro: Decimal
    let vorauszahlungenEuro: Decimal
    /// Positiv → Nachzahlung, negativ → Erstattung.
    let saldoEuro: Decimal
    let steuer35aBetragEuro: Decimal
    let heizungsAnlage: HeizungsAnlagenDetails?
}

@MainActor
enum AbrechnungsService {

    /// Aggregiert die Mieterabrechnungen für die Periode — mit striktem
    /// Pre-Flight-Check. Wirft `AbrechnungsBlocker.fehlendeDaten(…)`,
    /// sobald eine offene Anforderung existiert (keine Extrapolation,
    /// keine Schätzwerte). `.teilweise`-Status (z.B. Zählerwechsel mit
    /// kompensierender Hauptrechnung, §35a-Lohnanteil fehlt, ungeprüfte
    /// Rechnung) ist NICHT blockend — der Betrag steht, nur Meta-Info
    /// ist unvollständig. Solche Fälle tauchen im Inspektor als
    /// "in Arbeit" auf.
    static func aggregiere(
        periode: Abrechnungsperiode,
        immobilie: Immobilie
    ) throws -> [Mieterabrechnung] {
        let anforderungen = VollstaendigkeitsPruefung.pruefe(
            immobilie: immobilie, periode: periode
        )
        let offene = anforderungen.filter { $0.status == .offen }
        if !offene.isEmpty {
            throw AbrechnungsBlocker.fehlendeDaten(offeneAnforderungen: offene)
        }
        return aggregiereIntern(periode: periode, immobilie: immobilie)
    }

    /// Interne aggregiere-Logik ohne Pre-Flight. Wird vom throwing
    /// `aggregiere(…)` aufgerufen, nachdem die Datenvollständigkeit
    /// bestätigt wurde.
    private static func aggregiereIntern(
        periode: Abrechnungsperiode,
        immobilie: Immobilie
    ) -> [Mieterabrechnung] {
        let einheiten = immobilie.wohneinheiten ?? []
        guard !einheiten.isEmpty, immobilie.gesamtflaecheM2 > 0 else { return [] }

        let periodenRechnungen = (immobilie.rechnungen ?? []).filter { r in
            r.rechnungsdatum >= periode.von && r.rechnungsdatum <= periode.bis
        }
        let monate = monateInPeriode(periode)
        let kostenarten = immobilie.kostenarten ?? []

        // --- 1. Heizkosten-Berechnung (HeizkostenRechner) ---
        let heizResult = berechneHeizkosten(
            einheiten: einheiten,
            immobilie: immobilie,
            periode: periode,
            kostenarten: kostenarten,
            periodenRechnungen: periodenRechnungen
        )

        // --- 2. Wasser-Berechnung (WasserkostenRechner) ---
        let wasserErgebnis = berechneWasser(
            einheiten: einheiten,
            periode: periode,
            kostenarten: kostenarten,
            periodenRechnungen: periodenRechnungen
        )

        // --- 3. Flächen-Kostenarten (alle anderen) ---
        // Behandelt wird: .flaeche, .einheiten, .personen (alle drei als
        // Flächen-Umlage für MVP — Personen-Umlage kommt in Phase 1).
        let flaechenErgebnisse = berechneFlaechen(
            einheiten: einheiten,
            immobilie: immobilie,
            kostenarten: kostenarten,
            periodenRechnungen: periodenRechnungen
        )

        // --- 4. Pro Einheit Positionen zusammenstellen ---
        var positionenProEinheit: [UUID: [Mieterposition]] = [:]
        var heizAnlageProEinheit: [UUID: HeizungsAnlagenDetails] = [:]
        for e in einheiten { positionenProEinheit[e.id] = [] }

        if let heizResult {
            for einheitErg in heizResult.ergebnis.proEinheit {
                guard let id = UUID(uuidString: einheitErg.einheitID) else { continue }
                positionenProEinheit[id, default: []].append(Mieterposition(
                    id: UUID(),
                    kostenart: "Heizung",
                    gesamtkostenEuro: heizResult.ergebnis.heizkostenTopfEuro,
                    mieteranteilEuro: einheitErg.heizung.gesamtEuro,
                    verteilerschluesselText: einheitErg.heizung.verteilerschluesselText,
                    paragraph35aAnteilEuro: heizResult.p35aHeizungProEinheit[id] ?? 0
                ))
                positionenProEinheit[id, default: []].append(Mieterposition(
                    id: UUID(),
                    kostenart: "Warmwasser",
                    gesamtkostenEuro: heizResult.ergebnis.warmwasserkostenTopfEuro,
                    mieteranteilEuro: einheitErg.warmwasser.gesamtEuro,
                    verteilerschluesselText: einheitErg.warmwasser.verteilerschluesselText,
                    paragraph35aAnteilEuro: heizResult.p35aWarmwasserProEinheit[id] ?? 0
                ))

                heizAnlageProEinheit[id] = HeizungsAnlagenDetails(
                    heizkostenTopfEuro: heizResult.ergebnis.heizkostenTopfEuro,
                    warmwasserkostenTopfEuro: heizResult.ergebnis.warmwasserkostenTopfEuro,
                    qHeizungKwh: heizResult.ergebnis.qHeizungKwh,
                    qWarmwasserKwh: heizResult.ergebnis.qWarmwasserGesamtKwh,
                    wmzAnteilKwh: heizResult.wmzProEinheit[einheitErg.einheitID] ?? 0,
                    wwVerbrauchM3: heizResult.wwProEinheit[einheitErg.einheitID] ?? 0,
                    flaechenanteilHeizungEuro: einheitErg.heizung.flaechenanteilEuro,
                    verbrauchsanteilHeizungEuro: einheitErg.heizung.verbrauchsanteilEuro,
                    flaechenanteilWarmwasserEuro: einheitErg.warmwasser.flaechenanteilEuro,
                    verbrauchsanteilWarmwasserEuro: einheitErg.warmwasser.verbrauchsanteilEuro,
                    heizungVerteilerschluesselText: einheitErg.heizung.verteilerschluesselText,
                    warmwasserVerteilerschluesselText: einheitErg.warmwasser.verteilerschluesselText
                )
            }
        }

        if let wasserErgebnis {
            for e in wasserErgebnis.ergebnis.proEinheit {
                guard let id = UUID(uuidString: e.einheitID) else { continue }
                let preisText = wasserErgebnis.ergebnis.kombiPreisEuroProM3
                    .gerundet(auf: 4, modus: .bankers)
                positionenProEinheit[id, default: []].append(Mieterposition(
                    id: UUID(),
                    kostenart: "Be- und Entwässerung",
                    gesamtkostenEuro: wasserErgebnis.ergebnis.bwbGesamtkostenEuro,
                    mieteranteilEuro: e.anteilEuro,
                    verteilerschluesselText: "\(formatiere(e.verbrauchM3)) m³ × "
                        + "\(formatiere(preisText)) €/m³",
                    paragraph35aAnteilEuro: 0
                ))
            }
        }

        for eintrag in flaechenErgebnisse {
            for einheitErg in eintrag.ergebnis.proEinheit {
                guard let id = UUID(uuidString: einheitErg.einheitID) else { continue }
                positionenProEinheit[id, default: []].append(Mieterposition(
                    id: UUID(),
                    kostenart: eintrag.kostenart,
                    gesamtkostenEuro: eintrag.ergebnis.basisBetragEuro,
                    mieteranteilEuro: einheitErg.anteilEuro,
                    verteilerschluesselText: einheitErg.verteilerschluesselText,
                    paragraph35aAnteilEuro: eintrag.p35aProEinheit[id] ?? 0
                ))
            }
        }

        // --- 5. Aktive Mieter → Mieterabrechnung ---
        let alleMietverhaeltnisse: [Mietverhaeltnis] = einheiten
            .flatMap { $0.mietverhaeltnisse ?? [] }
        let aktiveMieter: [Mietverhaeltnis] = alleMietverhaeltnisse
            .filter { $0.auszugAm == nil && $0.wohneinheit != nil }
            .sorted { lhs, rhs in
                let l = sortierrang(lhs.wohneinheit?.bezeichnung ?? "")
                let r = sortierrang(rhs.wohneinheit?.bezeichnung ?? "")
                return l < r
            }

        return aktiveMieter.map { mv in
            guard let einheit = mv.wohneinheit else {
                return leereMieterabrechnung(mieter: mv)
            }
            let positionen = positionenProEinheit[einheit.id] ?? []
            let gesamt = positionen.reduce(Decimal(0)) { $0 + $1.mieteranteilEuro }
            let vorauszahlungen = mv.vorauszahlungMonatEuro * Decimal(monate)
            let saldo = gesamt - vorauszahlungen
            let p35a = positionen.reduce(Decimal(0)) { $0 + $1.paragraph35aAnteilEuro }
            return Mieterabrechnung(
                id: UUID(),
                mieterID: mv.id,
                mieterName: mv.mieterName,
                mieterAnschrift: mv.mieterAnschrift,
                mieterEmail: mv.mieterEmail,
                einheitBezeichnung: einheit.bezeichnung,
                einheitFlaecheM2: einheit.flaecheM2,
                positionen: positionen,
                gesamtkostenEuro: gesamt,
                vorauszahlungenEuro: vorauszahlungen,
                saldoEuro: saldo,
                steuer35aBetragEuro: p35a,
                heizungsAnlage: heizAnlageProEinheit[einheit.id]
            )
        }
    }

    // MARK: - Heizkosten

    private struct HeizResult {
        let ergebnis: HeizkostenErgebnis
        /// WMZ-Kwh je einheitID-String (identisch mit HeizkostenInput).
        let wmzProEinheit: [String: Double]
        let wwProEinheit: [String: Double]
        let p35aHeizungProEinheit: [UUID: Decimal]
        let p35aWarmwasserProEinheit: [UUID: Decimal]
    }

    private static func berechneHeizkosten(
        einheiten: [Wohneinheit],
        immobilie: Immobilie,
        periode: Abrechnungsperiode,
        kostenarten: [Kostenart],
        periodenRechnungen: [Rechnung]
    ) -> HeizResult? {
        let heizkostenarten = kostenarten.filter {
            $0.umlageschluessel == .heizkosten3070
                || $0.umlageschluessel == .warmwasser3070
                || $0.umlageschluessel == .heizkosten5050
        }
        let heizRechnungen = periodenRechnungen.filter { r in
            guard let ka = r.kostenart else { return false }
            return heizkostenarten.contains { $0.id == ka.id }
        }
        guard !heizRechnungen.isEmpty else { return nil }

        // Hauptrechnung = grösster Betrag ohne Lohnanteil (Brennstoff).
        // Pool = alle anderen Rechnungen der Heiz-Kostenart (Wartung,
        // Schornsteinfeger, …) — mit oder ohne Lohnanteil.
        let sortiert = heizRechnungen.sorted { $0.betragBruttoEuro > $1.betragBruttoEuro }
        guard let haupt = sortiert.first(where: { $0.lohnanteilBruttoEuro == nil })
                ?? sortiert.first
        else { return nil }
        let pool = heizRechnungen.filter { $0.id != haupt.id }

        // Verbräuche aus Zählern (oder Hauptrechnung bei Zählerwechsel).
        guard let gasKwh = ermittleGasVerbrauchKwh(
            immobilie: immobilie, periode: periode, hauptRechnung: haupt
        ), gasKwh > 0 else { return nil }

        var wmzProEinheit: [String: Double] = [:]
        var wwProEinheit: [String: Double] = [:]
        var flaechenProEinheit: [String: Double] = [:]
        for e in einheiten {
            let id = e.id.uuidString
            flaechenProEinheit[id] = NSDecimalNumber(decimal: e.flaecheM2).doubleValue
            if let wmz = (e.zaehler ?? []).first(where: { $0.medium == .waermeenergie }),
               let diff = stanDiffInPeriode(zaehler: wmz, periode: periode) {
                let faktor = wmz.einheit == "MWh" ? 1_000.0 : 1.0
                wmzProEinheit[id] = diff * faktor
            }
            if let ww = (e.zaehler ?? []).first(where: { $0.medium == .warmwasser }),
               let diff = stanDiffInPeriode(zaehler: ww, periode: periode) {
                wwProEinheit[id] = diff
            }
        }

        // Pool-Split nach kWh-Verhältnis Heizung:WW.
        let parameter = heizParameter(hauptRechnung: haupt)
        let vWwGesamt = wwProEinheit.values.reduce(0.0, +)
        let qWwKwh = vWwGesamt * parameter.wwGasFaktor * parameter.brennwertKwhProM3
        let anteilWw = gasKwh > 0 ? min(max(qWwKwh / gasKwh, 0), 1) : 0
        let anteilHeiz = 1.0 - anteilWw

        let poolSumme = pool.reduce(Decimal(0)) { $0 + $1.betragBruttoEuro }
        let heizNebenkosten = poolSumme * Decimal(anteilHeiz)
        let wwNebenkosten   = poolSumme * Decimal(anteilWw)

        // Pool-Lohnanteil für §35a ebenfalls aufteilen.
        let poolLohn = pool.reduce(Decimal(0)) { $0 + ($1.lohnanteilBruttoEuro ?? 0) }
        let lohnHeiz = poolLohn * Decimal(anteilHeiz)
        let lohnWw   = poolLohn * Decimal(anteilWw)

        let input = HeizkostenInput(
            gesamtGasVerbrauchKwh: gasKwh,
            gesamtGasKostenBrutto: haupt.betragBruttoEuro,
            heizNebenkosten: heizNebenkosten,
            wwNebenkosten: wwNebenkosten,
            wmzProEinheit: wmzProEinheit,
            wwM3ProEinheit: wwProEinheit,
            flaechenProEinheit: flaechenProEinheit,
            parameter: parameter
        )
        let ergebnis = HeizkostenRechner.berechne(input)

        // §35a: Lohn-Pool pro Topf flächenanteilig pro Einheit.
        var p35aHeiz: [UUID: Decimal] = [:]
        var p35aWw:   [UUID: Decimal] = [:]
        let gesamt = immobilie.gesamtflaecheM2
        for e in einheiten where gesamt > 0 {
            p35aHeiz[e.id] = lohnHeiz * e.flaecheM2 / gesamt
            p35aWw[e.id]   = lohnWw   * e.flaecheM2 / gesamt
        }

        return HeizResult(
            ergebnis: ergebnis,
            wmzProEinheit: wmzProEinheit,
            wwProEinheit: wwProEinheit,
            p35aHeizungProEinheit: p35aHeiz,
            p35aWarmwasserProEinheit: p35aWw
        )
    }

    private static func heizParameter(hauptRechnung: Rechnung) -> HeizkostenParameter {
        // Phase 0: Defaults des HeizkostenParameter-Initializers passen zu
        // Bahnhofstr. 37 (wwGasFaktor 12.9, Brennwert 11.14, 3 % Strom,
        // 30/70). Interner Arbeitspreis aus der Hauptrechnung überschreibt
        // den Pro-Rata-Split (WW-Kostenanteil = qWwKwh · internerPreis).
        let preis = hauptRechnung.internerArbeitspreisEuroProKwh.map {
            NSDecimalNumber(decimal: $0).doubleValue
        }
        return HeizkostenParameter(internerArbeitspreisEuroProKwh: preis)
    }

    private static func ermittleGasVerbrauchKwh(
        immobilie: Immobilie,
        periode: Abrechnungsperiode,
        hauptRechnung: Rechnung
    ) -> Double? {
        // Variante A: Gas-Hauptzähler-Stand-Differenz × Brennwert.
        if let gas = (immobilie.hauptzaehler ?? [])
            .first(where: { $0.medium == .gas }),
           let diff = stanDiffInPeriode(zaehler: gas, periode: periode) {
            let brennwert = NSDecimalNumber(
                decimal: gas.brennwertKwhProM3 ?? Decimal(string: "11.14")!
            ).doubleValue
            return diff * brennwert
        }
        // Variante B: Hauptrechnung trägt verbrauchMenge (kWh) — robust
        // gegen Zählerwechsel innerhalb der Periode.
        if let kwh = hauptRechnung.verbrauchMenge {
            return NSDecimalNumber(decimal: kwh).doubleValue
        }
        return nil
    }

    /// Monotone Stand-Differenz innerhalb der Periode. Bei Zählerwechsel
    /// (Differenz negativ) → nil.
    private static func stanDiffInPeriode(
        zaehler: Zaehler,
        periode: Abrechnungsperiode
    ) -> Double? {
        let staende = (zaehler.staende ?? [])
            .filter { $0.ablesedatum >= periode.von && $0.ablesedatum <= periode.bis }
            .sorted { $0.ablesedatum < $1.ablesedatum }
        guard staende.count >= 2,
              let first = staende.first,
              let last = staende.last
        else { return nil }
        let diff = last.stand - first.stand
        return diff > 0 ? NSDecimalNumber(decimal: diff).doubleValue : nil
    }

    // MARK: - Wasser

    private struct WasserResult {
        let ergebnis: WasserkostenErgebnis
    }

    private static func berechneWasser(
        einheiten: [Wohneinheit],
        periode: Abrechnungsperiode,
        kostenarten: [Kostenart],
        periodenRechnungen: [Rechnung]
    ) -> WasserResult? {
        let wasserkostenarten = kostenarten.filter { $0.umlageschluessel == .verbrauch }
        let wasserRechnungen = periodenRechnungen.filter { r in
            guard let ka = r.kostenart else { return false }
            return wasserkostenarten.contains { $0.id == ka.id }
        }
        let summe = wasserRechnungen.reduce(Decimal(0)) { $0 + $1.betragBruttoEuro }
        guard summe > 0 else { return nil }

        // Verbrauch je Einheit = Σ(KW-Hauptzähler) + Σ(WW-Zähler). Garten-
        // Zwischenzähler (typ == .zwischen) wird bewusst NICHT addiert —
        // BWB-Rechnung hat den Abwasser-Abzug für das Garten-Wasser bereits
        // eingerechnet, also wäre er sonst doppelt berücksichtigt.
        var verbrauchProEinheit: [String: Verbrauch] = [:]
        for e in einheiten {
            var m3: Decimal = 0
            let relevant = (e.zaehler ?? []).filter {
                ($0.medium == .kaltwasser || $0.medium == .warmwasser)
                    && $0.typ != .zwischen
            }
            for z in relevant {
                if let diff = stanDiffInPeriode(zaehler: z, periode: periode) {
                    m3 += Decimal(diff)
                }
            }
            verbrauchProEinheit[e.id.uuidString] = m3
        }

        let ergebnis = WasserkostenRechner.berechne(WasserkostenInput(
            bwbGesamtkostenEuro: summe,
            verbrauchProEinheitM3: verbrauchProEinheit
        ))
        return WasserResult(ergebnis: ergebnis)
    }

    // MARK: - Flächen-Umlage

    private struct FlaechenPositionsErgebnis {
        let kostenart: String
        let ergebnis: FlaechenErgebnis
        let p35aProEinheit: [UUID: Decimal]
    }

    private static func berechneFlaechen(
        einheiten: [Wohneinheit],
        immobilie: Immobilie,
        kostenarten: [Kostenart],
        periodenRechnungen: [Rechnung]
    ) -> [FlaechenPositionsErgebnis] {
        let flaechenKA = kostenarten.filter {
            $0.umlageschluessel == .flaeche
                || $0.umlageschluessel == .einheiten
                || $0.umlageschluessel == .personen
        }
        let flaechenDict: [String: Flaeche] = Dictionary(uniqueKeysWithValues: einheiten.map {
            ($0.id.uuidString, $0.flaecheM2)
        })

        var ergebnisse: [FlaechenPositionsErgebnis] = []
        for ka in flaechenKA.sorted(by: { $0.sortierung < $1.sortierung }) {
            let rechnungen = periodenRechnungen.filter { $0.kostenart?.id == ka.id }
            let summe = rechnungen.reduce(Decimal(0)) { $0 + $1.betragBruttoEuro }
            guard summe > 0 else { continue }

            let lohn = rechnungen.reduce(Decimal(0)) {
                $0 + ($1.lohnanteilBruttoEuro ?? 0)
            }

            let fr = FlaechenRechner.berechne(FlaechenInput(
                basisBetragEuro: summe,
                gesamtflaecheM2: immobilie.gesamtflaecheM2,
                flaechenProEinheit: flaechenDict
            ))

            var p35a: [UUID: Decimal] = [:]
            for e in einheiten where immobilie.gesamtflaecheM2 > 0 {
                p35a[e.id] = lohn * e.flaecheM2 / immobilie.gesamtflaecheM2
            }
            ergebnisse.append(FlaechenPositionsErgebnis(
                kostenart: ka.bezeichnung,
                ergebnis: fr,
                p35aProEinheit: p35a
            ))
        }
        return ergebnisse
    }

    // MARK: - Helfer

    private static func leereMieterabrechnung(mieter: Mietverhaeltnis) -> Mieterabrechnung {
        Mieterabrechnung(
            id: UUID(),
            mieterID: mieter.id,
            mieterName: mieter.mieterName,
            mieterAnschrift: mieter.mieterAnschrift,
            mieterEmail: mieter.mieterEmail,
            einheitBezeichnung: "—",
            einheitFlaecheM2: 0,
            positionen: [],
            gesamtkostenEuro: 0,
            vorauszahlungenEuro: 0,
            saldoEuro: 0,
            steuer35aBetragEuro: 0,
            heizungsAnlage: nil
        )
    }

    private static func monateInPeriode(_ p: Abrechnungsperiode) -> Int {
        var kal = Calendar(identifier: .gregorian)
        kal.timeZone = TimeZone(identifier: "UTC")!
        let k = kal.dateComponents([.month], from: p.von, to: p.bis)
        return max((k.month ?? 0) + 1, 1)
    }

    private static func sortierrang(_ bez: String) -> Int {
        let key = bez.uppercased().trimmingCharacters(in: .whitespaces)
        switch key {
        case "KG", "UG":       return 0
        case "EG":             return 1
        case "OG", "1. OG":    return 2
        case "2. OG":          return 3
        case "DG":             return 4
        default:               return 99
        }
    }

    private static func formatiere(_ d: Decimal) -> String {
        let ganzzahlig = d.gerundet(auf: 0, modus: .abrunden)
        if d == ganzzahlig {
            return NSDecimalNumber(decimal: ganzzahlig).stringValue
        }
        return NSDecimalNumber(decimal: d.gerundet(auf: 2, modus: .bankers)).stringValue
    }
}
