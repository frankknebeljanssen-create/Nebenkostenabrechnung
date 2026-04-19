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

    static func seedeWennLeer(in context: ModelContext) {
        // Nur seeden, wenn noch KEINE Immobilie existiert.
        let descriptor = FetchDescriptor<Immobilie>()
        let vorhandene = (try? context.fetchCount(descriptor)) ?? 0
        guard vorhandene == 0 else { return }

        guard let url = Bundle.main.url(forResource: "Bahnhofstr37_2025", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        let immobilie = bauImmobilie(ausJson: json)
        context.insert(immobilie)

        let einheitenNachID = bauWohneinheiten(ausJson: json, immobilie: immobilie, context: context)
        bauMieter(ausJson: json, einheitenNachID: einheitenNachID, context: context)
        bauPeriode(ausJson: json, immobilie: immobilie, context: context)

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
            mv.einzugAm = Date(timeIntervalSince1970: 0)   // Unbekannt — MVP
            if let einheitID = roh["einheit_id"] as? String,
               let wohneinheit = einheitenNachID[einheitID] {
                mv.wohneinheit = wohneinheit
            }
            context.insert(mv)
        }
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
