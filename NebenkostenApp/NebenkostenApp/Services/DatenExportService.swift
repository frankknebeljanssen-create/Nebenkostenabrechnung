//
//  DatenExportService.swift
//  NebenkostenApp — Services
//
//  DSGVO Art. 15-konformer Export aller in der App gespeicherten
//  Daten als einzelne JSON-Datei. Relationships werden als UUID-
//  Referenzen aufgelöst, damit der Export wieder einlesbar bleibt.
//
//  Hinweis: In Phase 0 gibt es noch keine Asset-Anhänge (Rechnungs-PDFs
//  und Zählerfotos sind leer). Sobald in Phase 1 der Scan-Flow echte
//  Dokumente anlegt, wird hier auf Ordner-Export + ZIP umgestellt.
//

import Foundation
import SwiftData

enum DatenExportFehler: LocalizedError {
    case serialisierung(underlying: Error)
    case dateischreiben(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .serialisierung(let e): return "JSON konnte nicht erzeugt werden: \(e.localizedDescription)"
        case .dateischreiben(let e): return "Datei konnte nicht geschrieben werden: \(e.localizedDescription)"
        }
    }
}

@MainActor
enum DatenExportService {

    /// Liest alle Entitäten aus dem Context, serialisiert sie nach JSON
    /// und schreibt das Ergebnis ins tmp-Verzeichnis. Gibt die URL zurück.
    static func erstelleExportDatei(in context: ModelContext) throws -> URL {
        let root = bauExport(context: context)

        let data: Data
        do {
            data = try JSONSerialization.data(
                withJSONObject: root,
                options: [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]
            )
        } catch {
            throw DatenExportFehler.serialisierung(underlying: error)
        }

        let dateiname = standardDateiname(fuerDatum: Date())
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(dateiname)

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw DatenExportFehler.dateischreiben(underlying: error)
        }

        return url
    }

    /// Nur die Struktur-Build-Methode — für Tests exponiert.
    static func bauExport(context: ModelContext) -> [String: Any] {
        let users         = (try? context.fetch(FetchDescriptor<AppUser>())) ?? []
        let immobilien    = (try? context.fetch(FetchDescriptor<Immobilie>())) ?? []
        let wohneinheiten = (try? context.fetch(FetchDescriptor<Wohneinheit>())) ?? []
        let mvs           = (try? context.fetch(FetchDescriptor<Mietverhaeltnis>())) ?? []
        let zaehler       = (try? context.fetch(FetchDescriptor<Zaehler>())) ?? []
        let staende       = (try? context.fetch(FetchDescriptor<Zaehlerstand>())) ?? []
        let kostenarten   = (try? context.fetch(FetchDescriptor<Kostenart>())) ?? []
        let rechnungen    = (try? context.fetch(FetchDescriptor<Rechnung>())) ?? []
        let perioden      = (try? context.fetch(FetchDescriptor<Abrechnungsperiode>())) ?? []
        let abrechnungen  = (try? context.fetch(FetchDescriptor<Abrechnung>())) ?? []
        let positionen    = (try? context.fetch(FetchDescriptor<Abrechnungsposition>())) ?? []
        let audits        = (try? context.fetch(FetchDescriptor<WarnungsAudit>())) ?? []

        return [
            "schemaVersion":        "1.1",
            "exportZeitpunkt":      iso8601(Date()),
            "hinweis":              "DSGVO Art. 15-konformer Export aller in der NebenkostenApp gespeicherten Daten.",
            "appUser":              users.map(dictAppUser),
            "immobilien":           immobilien.map(dictImmobilie),
            "wohneinheiten":        wohneinheiten.map(dictWohneinheit),
            "mietverhaeltnisse":    mvs.map(dictMietverhaeltnis),
            "zaehler":              zaehler.map(dictZaehler),
            "zaehlerstaende":       staende.map(dictZaehlerstand),
            "kostenarten":          kostenarten.map(dictKostenart),
            "rechnungen":           rechnungen.map(dictRechnung),
            "abrechnungsperioden":  perioden.map(dictPeriode),
            "abrechnungen":         abrechnungen.map(dictAbrechnung),
            "abrechnungspositionen": positionen.map(dictAbrechnungsposition),
            "warnungsAudit":        audits.map(dictWarnungsAudit)
        ]
    }

    // MARK: - Entity-Mapper

    private static func dictAppUser(_ u: AppUser) -> [String: Any] {
        [
            "id":                      u.id.uuidString,
            "erstelltAm":              iso8601(u.erstelltAm),
            "name":                    u.name,
            "anschrift":               u.anschrift,
            "ort":                     u.ort,
            "email":                   u.email,
            "telefon":                 u.telefon,
            "steuerID":                u.steuerID,
            "rolle":                   u.rolle.rawValue,
            "iban":                    u.iban,
            "datenschutzZustimmungAm": optionalIso(u.datenschutzZustimmungAm),
            "avvZustimmungAm":         optionalIso(u.avvZustimmungAm)
        ]
    }

    private static func dictImmobilie(_ i: Immobilie) -> [String: Any] {
        [
            "id":                  i.id.uuidString,
            "erstelltAm":          iso8601(i.erstelltAm),
            "adresse":             i.adresse,
            "ort":                 i.ort,
            "gesamtflaecheM2":     NSDecimalNumber(decimal: i.gesamtflaecheM2),
            "abrechnungsstartMonat": i.abrechnungsstartMonat,
            "abrechnungsstartTag":   i.abrechnungsstartTag,
            "heizungsart":         i.heizungsart.rawValue,
            "warmwasserbereitung": i.warmwasserbereitung.rawValue
        ]
    }

    private static func dictWohneinheit(_ w: Wohneinheit) -> [String: Any] {
        [
            "id":              w.id.uuidString,
            "bezeichnung":     w.bezeichnung,
            "flaecheM2":       NSDecimalNumber(decimal: w.flaecheM2),
            "nutzungsart":     w.nutzungsart.rawValue,
            "selbstnutzung":   w.selbstnutzung,
            "immobilieID":     optionalUUID(w.immobilie?.id)
        ]
    }

    private static func dictMietverhaeltnis(_ mv: Mietverhaeltnis) -> [String: Any] {
        [
            "id":                     mv.id.uuidString,
            "mieterName":             mv.mieterName,
            "mieterAnschrift":        mv.mieterAnschrift,
            "mieterEmail":            mv.mieterEmail,
            "mieterTyp":              mv.mieterTyp.rawValue,
            "einzugAm":               iso8601(mv.einzugAm),
            "auszugAm":               optionalIso(mv.auszugAm),
            "vorauszahlungMonatEuro": NSDecimalNumber(decimal: mv.vorauszahlungMonatEuro),
            "anzahlPersonen":         mv.anzahlPersonen,
            "wohneinheitID":          optionalUUID(mv.wohneinheit?.id)
        ]
    }

    private static func dictZaehler(_ z: Zaehler) -> [String: Any] {
        [
            "id":                 z.id.uuidString,
            "seriennummer":       z.seriennummer,
            "bezeichnung":        z.bezeichnung,
            "typ":                z.typ.rawValue,
            "medium":             z.medium.rawValue,
            "einheit":            z.einheit,
            "umrechnungsfaktor":  NSDecimalNumber(decimal: z.umrechnungsfaktor),
            "brennwertKwhProM3":  z.brennwertKwhProM3.map { NSDecimalNumber(decimal: $0) as Any } ?? NSNull(),
            "immobilieID":        optionalUUID(z.immobilie?.id),
            "wohneinheitID":      optionalUUID(z.wohneinheit?.id)
        ]
    }

    private static func dictZaehlerstand(_ s: Zaehlerstand) -> [String: Any] {
        [
            "id":           s.id.uuidString,
            "ablesedatum":  iso8601(s.ablesedatum),
            "stand":        NSDecimalNumber(decimal: s.stand),
            "quelle":       s.quelle.rawValue,
            "notizen":      s.notizen,
            "hatFoto":      s.foto != nil,
            "zaehlerID":    optionalUUID(s.zaehler?.id)
        ]
    }

    private static func dictKostenart(_ k: Kostenart) -> [String: Any] {
        [
            "id":                       k.id.uuidString,
            "bezeichnung":              k.bezeichnung,
            "betrKvKategorie":          k.betrKvKategorie,
            "umlageschluessel":         k.umlageschluessel.rawValue,
            "paragraph35a":             k.paragraph35a,
            "paragraph35aNurLohnanteil": k.paragraph35aNurLohnanteil,
            "aktiv":                    k.aktiv,
            "sortierung":               k.sortierung,
            "immobilieID":              optionalUUID(k.immobilie?.id)
        ]
    }

    private static func dictRechnung(_ r: Rechnung) -> [String: Any] {
        [
            "id":                    r.id.uuidString,
            "lieferant":             r.lieferant,
            "rechnungsnummer":       r.rechnungsnummer,
            "rechnungsdatum":        iso8601(r.rechnungsdatum),
            "leistungVon":           iso8601(r.leistungVon),
            "leistungBis":           iso8601(r.leistungBis),
            "betragBruttoEuro":      NSDecimalNumber(decimal: r.betragBruttoEuro),
            "lohnanteilBruttoEuro":  r.lohnanteilBruttoEuro.map { NSDecimalNumber(decimal: $0) as Any } ?? NSNull(),
            "anhangTyp":             r.anhangTyp,
            "hatAnhang":             r.anhang != nil,
            "extraktionsNotizen":    r.extraktionsNotizen,
            "geprueft":              r.geprueft,
            "immobilieID":           optionalUUID(r.immobilie?.id),
            "kostenartID":           optionalUUID(r.kostenart?.id)
        ]
    }

    private static func dictPeriode(_ p: Abrechnungsperiode) -> [String: Any] {
        [
            "id":             p.id.uuidString,
            "von":            iso8601(p.von),
            "bis":            iso8601(p.bis),
            "abgeschlossen":  p.abgeschlossen,
            "versandtAm":     optionalIso(p.versandtAm),
            "immobilieID":    optionalUUID(p.immobilie?.id)
        ]
    }

    private static func dictAbrechnung(_ a: Abrechnung) -> [String: Any] {
        [
            "id":                    a.id.uuidString,
            "erstelltAm":            iso8601(a.erstelltAm),
            "gesamtkostenEuro":      NSDecimalNumber(decimal: a.gesamtkostenEuro),
            "vorauszahlungenEuro":   NSDecimalNumber(decimal: a.vorauszahlungenEuro),
            "saldoEuro":             NSDecimalNumber(decimal: a.saldoEuro),
            "steuer35aBetragEuro":   NSDecimalNumber(decimal: a.steuer35aBetragEuro),
            "hatPdf":                a.pdfDatei != nil,
            "periodeID":             optionalUUID(a.periode?.id),
            "mietverhaeltnisID":     optionalUUID(a.mietverhaeltnis?.id)
        ]
    }

    private static func dictAbrechnungsposition(_ p: Abrechnungsposition) -> [String: Any] {
        [
            "id":                      p.id.uuidString,
            "gesamtkostenEuro":        NSDecimalNumber(decimal: p.gesamtkostenEuro),
            "mieteranteilEuro":        NSDecimalNumber(decimal: p.mieteranteilEuro),
            "verteilerschluesselText": p.verteilerschluesselText,
            "sortierung":              p.sortierung,
            "abrechnungID":            optionalUUID(p.abrechnung?.id),
            "kostenartID":             optionalUUID(p.kostenart?.id)
        ]
    }

    private static func dictWarnungsAudit(_ a: WarnungsAudit) -> [String: Any] {
        var dict: [String: Any] = [
            "id":              a.id.uuidString,
            "erstelltAm":      iso8601(a.erstelltAm),
            "userName":        a.userName,
            "periodeID":       optionalUUID(a.periodeID),
            "mieterID":        optionalUUID(a.mieterID),
            "mieterName":      a.mieterName,
            "zusammenfassung": a.zusammenfassung
        ]
        // warnungenJSON ist bereits JSON-Array-String → als eingebettetes
        // Array exportieren, damit der Gesamt-Export lesbar bleibt.
        if let data = a.warnungenJSON.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] {
            dict["warnungen"] = parsed
        } else {
            dict["warnungen"] = [] as [Any]
        }
        return dict
    }

    // MARK: - Helper

    private static func iso8601(_ d: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: d)
    }

    private static func optionalIso(_ d: Date?) -> Any {
        d.map { iso8601($0) as Any } ?? NSNull()
    }

    private static func optionalUUID(_ id: UUID?) -> Any {
        id.map { $0.uuidString as Any } ?? NSNull()
    }

    private static func standardDateiname(fuerDatum datum: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return "NebenkostenApp-Export-\(f.string(from: datum)).json"
    }
}
