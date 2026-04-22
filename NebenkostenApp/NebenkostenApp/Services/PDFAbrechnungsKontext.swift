//
//  PDFAbrechnungsKontext.swift
//  NebenkostenApp — Services
//
//  Reiner Mapper: Mieterabrechnung + Immobilie + AppUser + Periode
//  → Mustache-Dictionary fuer `Templates/abrechnung.html`.
//
//  Keine I/O, keine SwiftData-Mutation, keine UI — der Helper ist
//  isoliert testbar und wird sowohl vom neuen `PDFVorschauSheet`
//  (UI-2) als auch von der Phase-0-`MieterAbrechnungsDetailView`
//  aufgerufen. Eine Quelle der Wahrheit verhindert Drift zwischen
//  den beiden Generierungs-Pfaden.
//

import Foundation

@MainActor
enum PDFAbrechnungsKontext {

    /// Baut das Mustache-Dictionary. Betraege werden deutsch
    /// formatiert (1.234,56 ohne €-Symbol — das Template haengt
    /// " &euro;" an), Daten als `dd.MM.yyyy`.
    static func baue(
        abrechnung: Mieterabrechnung,
        immobilie: Immobilie,
        user: AppUser?,
        periode: Abrechnungsperiode
    ) -> [String: Any] {

        var ctx: [String: Any] = [:]
        ctx["vermieter"]          = vermieterDict(user)
        ctx["mieter"]             = mieterDict(abrechnung)
        ctx["datum"]              = formatiereDatum(Date())
        ctx["periode"]            = periodeDict(periode)
        ctx["einheit"]            = einheitDict(abrechnung)
        ctx["immobilie"]          = immobilieDict(immobilie)
        ctx["abrechnung"]         = abrechnungDict(abrechnung)
        ctx["positionen"]         = positionenDicts(abrechnung)
        ctx["steuer35aRelevant"]  = abrechnung.steuer35aBetragEuro > 0
        ctx["hatHeizungsAnlage"]  = abrechnung.heizungsAnlage != nil
        ctx["hatCo2Anlage"]       = false

        if let h = abrechnung.heizungsAnlage {
            ctx["heizung"] = heizungDict(heizung: h, abrechnung: abrechnung)
        }
        return ctx
    }

    // MARK: - Sub-Dictionaries
    // Jeder Block fuer sich — der Compiler mag kein riesiges Dict-
    // Literal in einem Rutsch (Type-Inference-Timeout).

    private static func vermieterDict(_ user: AppUser?) -> [String: Any] {
        [
            "name":    user?.name ?? "",
            "adresse": user?.anschrift ?? "",
            "ort":     user?.ort ?? ""
        ]
    }

    private static func mieterDict(_ abrechnung: Mieterabrechnung) -> [String: Any] {
        [
            "anrede":        "Sehr geehrte Mieterin, sehr geehrter Mieter,",
            "anredeFormell": "Sehr geehrte Damen und Herren",
            "name":          abrechnung.mieterName,
            "adresse":       abrechnung.mieterAnschrift,
            "ort":           ""
        ]
    }

    private static func periodeDict(_ p: Abrechnungsperiode) -> [String: Any] {
        [
            "bezeichnung": formatierePeriode(p),
            "von":         formatiereDatum(p.von),
            "bis":         formatiereDatum(p.bis)
        ]
    }

    private static func einheitDict(_ a: Mieterabrechnung) -> [String: Any] {
        [
            "bezeichnung": a.einheitBezeichnung,
            "flaecheM2":   formatiereZahl(a.einheitFlaecheM2)
        ]
    }

    private static func immobilieDict(_ i: Immobilie) -> [String: Any] {
        [
            "adresse":         i.adresse,
            "ort":             i.ort,
            "gesamtflaecheM2": formatiereZahl(i.gesamtflaecheM2)
        ]
    }

    private static func abrechnungDict(_ a: Mieterabrechnung) -> [String: Any] {
        let saldoLabel = a.saldoEuro >= 0 ? "Ihre Nachzahlung" : "Ihre Erstattung"
        let saldoFmt = formatiereZahl(a.saldoEuro.magnitude)
        let saldoText = a.saldoEuro >= 0 ? saldoFmt : "\u{2212} \(saldoFmt)"
        return [
            "gesamtkostenEuro":      formatiereZahl(a.gesamtkostenEuro),
            "vorauszahlungenEuro":   formatiereZahl(a.vorauszahlungenEuro),
            "saldoLabel":            saldoLabel,
            "saldoBetragFormatiert": saldoText,
            "steuer35aBetragEuro":   formatiereZahl(a.steuer35aBetragEuro)
        ]
    }

    private static func positionenDicts(_ a: Mieterabrechnung) -> [[String: Any]] {
        a.positionen.map { p -> [String: Any] in
            [
                "bezeichnung":         p.kostenart,
                "gesamtkostenEuro":    formatiereZahl(p.gesamtkostenEuro),
                "verteilerschluessel": p.verteilerschluesselText,
                "mieteranteilEuro":    formatiereZahl(p.mieteranteilEuro)
            ]
        }
    }

    private static func heizungDict(
        heizung h: HeizungsAnlagenDetails,
        abrechnung a: Mieterabrechnung
    ) -> [String: Any] {
        let anteilHeiz: Decimal = a.positionen
            .first(where: { $0.kostenart == "Heizung" })?
            .mieteranteilEuro ?? 0
        let anteilWw: Decimal = a.positionen
            .first(where: { $0.kostenart == "Warmwasser" })?
            .mieteranteilEuro ?? 0
        let topfSumme = h.heizkostenTopfEuro + h.warmwasserkostenTopfEuro
        let flaechenAnt = h.flaechenanteilHeizungEuro
            + h.flaechenanteilWarmwasserEuro
        let verbrauchAnt = h.verbrauchsanteilHeizungEuro
            + h.verbrauchsanteilWarmwasserEuro
        return [
            "gesamtkostenEuro":       formatiereZahl(topfSumme),
            "heizkostenTopfEuro":     formatiereZahl(h.heizkostenTopfEuro),
            "warmwasserTopfEuro":     formatiereZahl(h.warmwasserkostenTopfEuro),
            "qHeizungKwh":            formatiereGanz(h.qHeizungKwh),
            "qWarmwasserKwh":         formatiereGanz(h.qWarmwasserKwh),
            "wmzGesamt":              formatiereGanz(h.qHeizungKwh),
            "wmzAnteil":              formatiereGanz(h.wmzAnteilKwh),
            "wwVerbrauchM3":          formatiereZahl(Decimal(h.wwVerbrauchM3)),
            "flaechenanteilEuro":     formatiereZahl(flaechenAnt),
            "verbrauchsanteilEuro":   formatiereZahl(verbrauchAnt),
            "verbrauchAnteilProzent": "70",
            "gesamtAnteilEuro":       formatiereZahl(anteilHeiz + anteilWw)
        ]
    }

    // MARK: - Formatter

    /// Vorschlagbarer Dateiname fuer den PDF-Export. Bereinigt
    /// Umlaute und Sonderzeichen, enthaelt Mieter + Periode.
    static func vorschlagDateiname(
        abrechnung: Mieterabrechnung,
        periode: Abrechnungsperiode
    ) -> String {
        let mieter = sanitisiert(abrechnung.mieterName.isEmpty
                                 ? abrechnung.einheitBezeichnung
                                 : abrechnung.mieterName)
        let kal = Calendar(identifier: .gregorian)
        let y1 = kal.component(.year, from: periode.von)
        let y2 = kal.component(.year, from: periode.bis)
        let zeitraum = y1 == y2 ? "\(y1)" : "\(y1)-\(y2)"
        return "Abrechnung_\(mieter)_\(zeitraum).pdf"
    }

    private static func sanitisiert(_ s: String) -> String {
        let ersetzt = s
            .replacingOccurrences(of: "ä", with: "ae")
            .replacingOccurrences(of: "ö", with: "oe")
            .replacingOccurrences(of: "ü", with: "ue")
            .replacingOccurrences(of: "Ä", with: "Ae")
            .replacingOccurrences(of: "Ö", with: "Oe")
            .replacingOccurrences(of: "Ü", with: "Ue")
            .replacingOccurrences(of: "ß", with: "ss")
        let erlaubt = CharacterSet.alphanumerics.union(.init(charactersIn: "-_"))
        let gefiltert = ersetzt.unicodeScalars
            .map { erlaubt.contains($0) ? Character($0) : "_" }
        return String(gefiltert).trimmingCharacters(in: .init(charactersIn: "_"))
    }

    private static func formatiereZahl(_ value: Decimal) -> String {
        zahlFormatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }

    private static func formatiereGanz(_ value: Double) -> String {
        ganzFormatter.string(from: NSNumber(value: value))
            ?? "\(Int(value.rounded()))"
    }

    private static func formatiereDatum(_ date: Date) -> String {
        datumFormatter.string(from: date)
    }

    private static func formatierePeriode(_ p: Abrechnungsperiode) -> String {
        "\(formatiereDatum(p.von)) – \(formatiereDatum(p.bis))"
    }

    private static let zahlFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.groupingSeparator = "."
        f.decimalSeparator = ","
        return f
    }()

    private static let ganzFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.groupingSeparator = "."
        return f
    }()

    private static let datumFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "dd.MM.yyyy"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
}
