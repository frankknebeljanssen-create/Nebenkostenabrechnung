//
//  SeedData.swift
//  NebenkostenApp — Services
//
//  Liest bei einer komplett leeren SwiftData-Datenbank die Basics der
//  Bahnhofstr. 37 aus dem gebundelten Testdaten-JSON und legt Immobilie,
//  Wohneinheiten und Mieterinnen an. Für MVP-Demo-Zwecke — nur einmalig
//  beim allerersten App-Start. Zähler und Rechnungen bleiben leer, damit
//  man die Kachel-Status-Logik im Dashboard sieht.
//

import Foundation
import SwiftData

@MainActor
enum SeedData {

    /// Idempotent: legt jeden Teil (Immobilie, Wohneinheiten, Mieter, Zähler,
    /// Perioden) nur an, wenn er in der DB fehlt. Damit werden neue Seed-
    /// Bestandteile (z.B. Perioden aus Task 0.11, Zähler aus Task 0.12) auch
    /// in schon bestehenden Simulator-Stores nachgetragen, ohne dass der
    /// User die App deinstallieren muss.
    static func seedeWennLeer(in context: ModelContext) {
        guard let url = Bundle.main.url(forResource: "Bahnhofstr37_2025", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        // Immobilie: vorhandene verwenden oder neue anlegen.
        let vorhandene = (try? context.fetch(FetchDescriptor<Immobilie>())) ?? []
        let immobilie: Immobilie
        if let ersteVorhanden = vorhandene.first {
            immobilie = ersteVorhanden
        } else {
            immobilie = bauImmobilie(ausJson: json)
            context.insert(immobilie)
        }

        // Wohneinheiten: Lookup aufbauen, fehlende anlegen.
        var einheitenNachID: [String: Wohneinheit] = [:]
        if (immobilie.wohneinheiten ?? []).isEmpty {
            einheitenNachID = bauWohneinheiten(ausJson: json, immobilie: immobilie, context: context)
        } else {
            for we in immobilie.wohneinheiten ?? [] {
                einheitenNachID[we.bezeichnung] = we
            }
        }

        // Mieter: nur wenn an noch keiner Einheit ein Mietverhältnis hängt.
        let hatMieter = (immobilie.wohneinheiten ?? [])
            .contains(where: { !($0.mietverhaeltnisse ?? []).isEmpty })
        if !hatMieter {
            bauMieter(ausJson: json, einheitenNachID: einheitenNachID, context: context)
        }

        // Zähler: Lookup aufbauen, fehlende anlegen.
        let alleZaehlerVorhanden = (immobilie.hauptzaehler ?? [])
            + (immobilie.wohneinheiten ?? []).flatMap { $0.zaehler ?? [] }
        let zaehlerNachID: [String: Zaehler]
        if alleZaehlerVorhanden.isEmpty {
            zaehlerNachID = bauZaehler(
                ausJson: json,
                einheitenNachID: einheitenNachID,
                immobilie: immobilie,
                context: context
            )
        } else {
            zaehlerNachID = Dictionary(
                uniqueKeysWithValues: alleZaehlerVorhanden.map { ($0.bezeichnung, $0) }
            )
        }

        // Zählerstände: nur wenn an den Zählern noch keine Stände hängen.
        let hatStaende = zaehlerNachID.values
            .contains(where: { !($0.staende ?? []).isEmpty })
        if !hatStaende {
            bauZaehlerstaende(ausJson: json, zaehlerNachID: zaehlerNachID, context: context)
        }

        // Kostenarten: Standard-Set (BetrKV §2) anlegen, wenn noch keine.
        if (immobilie.kostenarten ?? []).isEmpty {
            bauKostenarten(fuer: immobilie, context: context)
        }

        // Abrechnungsperioden: nur wenn noch keine vorhanden.
        if (immobilie.perioden ?? []).isEmpty {
            bauPeriode(ausJson: json, immobilie: immobilie, context: context)
        }

        try? context.save()
    }

    // MARK: - Immobilie

    private static func bauImmobilie(ausJson json: [String: Any]) -> Immobilie {
        let immobilie = Immobilie()
        if let objekt = json["objekt"] as? [String: Any] {
            if let adresse = objekt["adresse"] as? [String: Any] {
                immobilie.adresse = (adresse["strasse"] as? String) ?? ""
                let plz = (adresse["plz"] as? String) ?? ""
                let ort = (adresse["ort"] as? String) ?? ""
                immobilie.ort = [plz, ort]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
            }
            if let flaeche = objekt["gesamtflaeche_qm"] as? Double {
                immobilie.gesamtflaecheM2 = Decimal(flaeche)
            } else if let flaecheInt = objekt["gesamtflaeche_qm"] as? Int {
                immobilie.gesamtflaecheM2 = Decimal(flaecheInt)
            }
        }
        // Bahnhofstr. 37 rechnet 01.11.–31.10., passend zum Testdaten-JSON.
        immobilie.abrechnungsstartMonat = 11
        immobilie.abrechnungsstartTag = 1
        return immobilie
    }

    // MARK: - Wohneinheiten

    private static func bauWohneinheiten(
        ausJson json: [String: Any],
        immobilie: Immobilie,
        context: ModelContext
    ) -> [String: Wohneinheit] {
        guard let rohe = json["wohneinheiten"] as? [[String: Any]] else { return [:] }

        var proID: [String: Wohneinheit] = [:]
        for roh in rohe {
            let einheit = Wohneinheit()
            let id = (roh["id"] as? String) ?? ""
            einheit.bezeichnung = id
            if let flaeche = roh["flaeche_qm"] as? Double {
                einheit.flaecheM2 = Decimal(flaeche)
            } else if let flaecheInt = roh["flaeche_qm"] as? Int {
                einheit.flaecheM2 = Decimal(flaecheInt)
            }
            einheit.nutzungsart = nutzungsart(aus: (roh["nutzungsart"] as? String) ?? "")
            einheit.immobilie = immobilie
            context.insert(einheit)
            if !id.isEmpty { proID[id] = einheit }
        }
        return proID
    }

    private static func nutzungsart(aus roh: String) -> Nutzungsart {
        switch roh.lowercased() {
        case "gewerbe":           return .gewerbe
        case "einliegerwohnung":  return .einliegerwohnung
        case "leerstand":         return .leerstand
        default:                  return .wohnung
        }
    }

    // MARK: - Mieter

    private static func bauMieter(
        ausJson json: [String: Any],
        einheitenNachID: [String: Wohneinheit],
        context: ModelContext
    ) {
        guard let rohe = json["mieter"] as? [[String: Any]] else { return }

        for roh in rohe {
            let mv = Mietverhaeltnis()
            mv.mieterName = (roh["name"] as? String) ?? ""
            mv.mieterTyp = mieterTyp(aus: (roh["typ"] as? String) ?? "")
            mv.einzugAm = Date(timeIntervalSince1970: 0)   // Unbekannt — MVP
            if let einheitID = roh["einheit_id"] as? String,
               let wohneinheit = einheitenNachID[einheitID] {
                mv.wohneinheit = wohneinheit
            }
            context.insert(mv)
        }
    }

    private static func mieterTyp(aus roh: String) -> MieterTyp {
        switch roh {
        case "Gewerbemieter": return .gewerbemieter
        case "Selbstnutzer":  return .selbstnutzer
        default:              return .wohnungsmieter
        }
    }

    // MARK: - Zähler

    private static func bauZaehler(
        ausJson json: [String: Any],
        einheitenNachID: [String: Wohneinheit],
        immobilie: Immobilie,
        context: ModelContext
    ) -> [String: Zaehler] {
        guard let rohe = json["zaehler"] as? [[String: Any]] else { return [:] }

        var proID: [String: Zaehler] = [:]
        for roh in rohe {
            let z = Zaehler()
            z.bezeichnung = (roh["id"] as? String) ?? ""
            z.seriennummer = (roh["seriennummer"] as? String) ?? ""
            z.medium = medium(aus: (roh["typ"] as? String) ?? "")
            z.einheit = standardEinheit(fuer: z.medium)
            z.typ = zaehlerTyp(fuer: roh)

            let einheitID = roh["einheit_id"] as? String
            if let id = einheitID, let einheit = einheitenNachID[id] {
                z.wohneinheit = einheit
            } else if einheitID == nil {
                z.immobilie = immobilie
            }
            context.insert(z)
            if !z.bezeichnung.isEmpty { proID[z.bezeichnung] = z }
        }
        return proID
    }

    // MARK: - Zählerstände

    /// Liest zaehlerstaende.anfang_periode und .ende_periode aus der JSON
    /// und legt je Zähler einen Zählerstand zum jeweiligen Datum an.
    /// Werte `null` und unbekannte zaehler_id werden übersprungen.
    private static func bauZaehlerstaende(
        ausJson json: [String: Any],
        zaehlerNachID: [String: Zaehler],
        context: ModelContext
    ) {
        guard let bloecke = json["zaehlerstaende"] as? [String: Any] else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for schluessel in ["anfang_periode", "ende_periode"] {
            guard let block = bloecke[schluessel] as? [String: Any],
                  let datumRoh = block["datum"] as? String,
                  let datum = formatter.date(from: datumRoh),
                  let staende = block["staende"] as? [[String: Any]]
            else { continue }

            for roh in staende {
                guard let zaehlerID = roh["zaehler_id"] as? String,
                      let zaehler = zaehlerNachID[zaehlerID],
                      let wert = decimal(aus: roh["wert"])
                else { continue }

                let zs = Zaehlerstand()
                zs.ablesedatum = datum
                zs.stand = wert
                zs.quelle = .importiert
                zs.zaehler = zaehler
                context.insert(zs)
            }
        }
    }

    private static func decimal(aus raw: Any?) -> Decimal? {
        if let d = raw as? Double { return Decimal(string: "\(d)") }
        if let i = raw as? Int    { return Decimal(i) }
        if let s = raw as? String { return Decimal(string: s) }
        if let n = raw as? NSNumber { return Decimal(string: "\(n.doubleValue)") }
        return nil
    }

    // MARK: - Kostenarten (BetrKV §2)

    private struct KostenartEntwurf {
        let bezeichnung: String
        let betrKv: String
        let schluessel: Umlageschluessel
        let p35a: Bool
        let nurLohn: Bool
    }

    /// Legt die für die Bahnhofstr. 37 typischen Kostenarten an.
    /// Der User kann die Liste später per UI anpassen (aktivieren/deaktivieren,
    /// weitere hinzufügen, löschen).
    private static func bauKostenarten(
        fuer immobilie: Immobilie,
        context: ModelContext
    ) {
        let entwuerfe: [KostenartEntwurf] = [
            .init(bezeichnung: "Grundsteuer",                 betrKv: "1",      schluessel: .flaeche,         p35a: false, nurLohn: false),
            .init(bezeichnung: "Be- und Entwässerung",        betrKv: "2 + 3",  schluessel: .verbrauch,       p35a: false, nurLohn: false),
            .init(bezeichnung: "Heizung und Warmwasser",      betrKv: "4a + 4b",schluessel: .heizkosten3070,  p35a: false, nurLohn: false),
            .init(bezeichnung: "Müllabfuhr (BSR)",            betrKv: "8",      schluessel: .flaeche,         p35a: false, nurLohn: false),
            .init(bezeichnung: "Gebäudeversicherung",         betrKv: "13",     schluessel: .flaeche,         p35a: false, nurLohn: false),
            .init(bezeichnung: "Gartenpflege",                betrKv: "10",     schluessel: .flaeche,         p35a: true,  nurLohn: true),
            .init(bezeichnung: "Gebäudereinigung",            betrKv: "9",      schluessel: .flaeche,         p35a: true,  nurLohn: false),
            .init(bezeichnung: "Schnee- und Eisbeseitigung",  betrKv: "8",      schluessel: .flaeche,         p35a: true,  nurLohn: true),
            .init(bezeichnung: "Schornsteinfeger",            betrKv: "4a",     schluessel: .flaeche,         p35a: true,  nurLohn: false),
            .init(bezeichnung: "Allgemeinstrom",              betrKv: "11",     schluessel: .flaeche,         p35a: false, nurLohn: false)
        ]

        for (index, e) in entwuerfe.enumerated() {
            let ka = Kostenart()
            ka.bezeichnung = e.bezeichnung
            ka.betrKvKategorie = e.betrKv
            ka.umlageschluessel = e.schluessel
            ka.paragraph35a = e.p35a
            ka.paragraph35aNurLohnanteil = e.nurLohn
            ka.aktiv = true
            ka.sortierung = (index + 1) * 10
            ka.immobilie = immobilie
            context.insert(ka)
        }
    }

    private static func medium(aus typRoh: String) -> Medium {
        switch typRoh {
        case "Gas":                  return .gas
        case "Strom":                return .strom
        case "Warmwasser":           return .warmwasser
        case "Kaltwasser":           return .kaltwasser
        case "Wärmemengenzähler":    return .waermeenergie
        default:                     return .kaltwasser
        }
    }

    private static func standardEinheit(fuer medium: Medium) -> String {
        switch medium {
        case .kaltwasser, .warmwasser, .gas: return "m³"
        case .strom:          return "kWh"
        case .waermeenergie:  return "MWh"
        case .oel:            return "L"
        }
    }

    private static func zaehlerTyp(fuer roh: [String: Any]) -> Zaehlertyp {
        if (roh["einheit_id"] as? String) == nil { return .haupt }
        let anmerkung = (roh["anmerkung"] as? String ?? "").lowercased()
        if anmerkung.contains("zwischen") { return .zwischen }
        return .wohnung
    }

    // MARK: - Abrechnungsperioden

    /// Legt zwei Perioden an: die 2024/25 mit allen Testdaten (aus der
    /// Testdaten-JSON) und eine noch leere Folgeperiode 2025/26 — damit im
    /// Dashboard ein Periode-Dropdown mit zwei Einträgen sichtbar ist und
    /// der Umschaltmechanismus getestet werden kann.
    private static func bauPeriode(
        ausJson json: [String: Any],
        immobilie: Immobilie,
        context: ModelContext
    ) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // Periode 1: 2024/25 aus der JSON.
        if let rohe = json["abrechnungsperiode"] as? [String: Any],
           let startRoh = rohe["start"] as? String,
           let endeRoh = rohe["ende"] as? String,
           let start = formatter.date(from: startRoh),
           let ende = formatter.date(from: endeRoh) {
            let periode = Abrechnungsperiode()
            periode.von = start
            periode.bis = ende
            periode.immobilie = immobilie
            context.insert(periode)
        }

        // Periode 2: 2025/26 — noch komplett leer (keine Zähler/Rechnungen
        // erfasst). Dient als Demo für den Periode-Wechsel.
        if let start = formatter.date(from: "2025-11-01"),
           let ende = formatter.date(from: "2026-10-31") {
            let periode = Abrechnungsperiode()
            periode.von = start
            periode.bis = ende
            periode.immobilie = immobilie
            context.insert(periode)
        }
    }
}
