//
//  ZaehlerstandErfassenViewModel.swift
//  NebenkostenApp — UI/Zaehler/ViewModels
//

import Foundation

@MainActor
@Observable
final class ZaehlerstandErfassenViewModel {

    /// Im Sheet auswählbare Quellen (im MVP ohne .importiert, das ist
    /// dem Seed/Import-Flow vorbehalten).
    static let verfuegbareQuellen: [Ablesequelle] = [
        .manuell, .kiExtrahiert, .versorgerRechnung, .geschaetzt
    ]

    let zaehler: Zaehler

    // Form-State
    var datum: Date = Date()
    var quelle: Ablesequelle = .manuell
    var wertText: String = ""
    var notiz: String = ""
    var zeigeRuecklaufAlert: Bool = false

    init(zaehler: Zaehler) {
        self.zaehler = zaehler
    }

    // MARK: - Validierung

    /// Deutsches Zahlenformat (Komma als Dezimaltrenner) zu Decimal.
    var wertDecimal: Decimal? {
        let normalisiert = wertText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard !normalisiert.isEmpty else { return nil }
        return Decimal(string: normalisiert)
    }

    var istGueltig: Bool {
        guard let wert = wertDecimal else { return false }
        return wert >= 0
    }

    // MARK: - Plausibilität

    /// Stand, der vor dem eingegebenen Datum liegt und der „aktuellste"
    /// vor dem neuen Eintrag ist. Nur für Rücklauf-Check.
    var vorherigerStand: Zaehlerstand? {
        (zaehler.staende ?? [])
            .filter { $0.ablesedatum <= datum }
            .sorted { $0.ablesedatum > $1.ablesedatum }
            .first
    }

    var hatRuecklauf: Bool {
        guard let wert = wertDecimal, let vorheriger = vorherigerStand else { return false }
        return wert < vorheriger.stand
    }

    var istZukunftsdatum: Bool { datum > Date() }

    var istAusserhalbAktuellerPeriode: Bool {
        guard let periode = aktuellePeriode else { return false }
        return datum < periode.von || datum > periode.bis
    }

    /// Dezent angezeigte Info unter dem Formular (kein Block beim Speichern).
    var plausiHinweis: String? {
        if hatRuecklauf { return "Neuer Stand ist kleiner als der letzte vor diesem Datum." }
        if istZukunftsdatum { return "Datum liegt in der Zukunft." }
        if istAusserhalbAktuellerPeriode { return "Datum liegt außerhalb der laufenden Abrechnungsperiode." }
        return nil
    }

    // MARK: - Helfer

    private var aktuellePeriode: Abrechnungsperiode? {
        let perioden = zaehler.wohneinheit?.immobilie?.perioden
            ?? zaehler.immobilie?.perioden
            ?? []
        let heute = Date()
        return perioden.first(where: { $0.von <= heute && heute <= $0.bis })
            ?? perioden.sorted(by: { $0.bis > $1.bis }).first
    }
}
