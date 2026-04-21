//
//  DokumentAnalyse.swift
//  NebenkostenApp — Services
//
//  Kontextuebergreifende Dokumenten-Analyse. Jeder Scan wird NICHT
//  isoliert betrachtet, sondern innerhalb einer `AnalyseSitzung`
//  mit bereits vorhandenen WE-Daten und frueheren Scans derselben
//  Sitzung zusammengefuehrt. Das Ergebnis ist ein `AnalyseBefund`
//  mit drei Bloecken:
//    1. Erkannte Felder (neu + evtl. aktualisiert aus altem Wert)
//    2. Fehlende Daten (wichtig / empfohlen / optional)
//    3. Widersprueche (gleiches Feld, unterschiedliche Werte ohne
//       klares Datums-Gefaelle)
//
//  Status M1.5: Stub. Der `DokumentAnalyseService` nutzt intern
//  `MietvertragsExtraktionService` (liefert deterministisch Demo-
//  Daten). Der erkannte Dokument-Typ alterniert pro Scan, damit
//  der Update-Fall sichtbar wird (Mietvertrag → Erhoehungsschreiben
//  → VZ wird als „aktualisiert" markiert). M2 ersetzt das durch
//  einen echten Claude-Call, dem die gesamte Sitzung + alle
//  bekannten Felder mitgegeben werden, sodass das LLM selbst
//  entscheidet: ergaenzt, aktualisiert, widerspricht.
//

import Foundation
import UIKit

// MARK: - Dokument-Typen

enum DokumentTyp: String, Sendable, Codable, CaseIterable, Hashable {
    case mietvertrag
    case mietvertragNachtrag
    case nkErhoehungsschreiben
    case uebergabeprotokollEinzug
    case uebergabeprotokollAuszug
    case sepaMandat
    case energieausweis
    case personalausweis
    case rechnung
    case bescheid
    /// Hausverwaltungs-Einzelabrechnung fuer WEG-Eigentuemer.
    case hvAbrechnung
    case unbekannt

    var anzeige: String {
        switch self {
        case .mietvertrag:              return "Mietvertrag"
        case .mietvertragNachtrag:      return "Mietvertrags-Nachtrag"
        case .nkErhoehungsschreiben:    return "NK-Erhöhungsschreiben"
        case .uebergabeprotokollEinzug: return "Übergabeprotokoll (Einzug)"
        case .uebergabeprotokollAuszug: return "Übergabeprotokoll (Auszug)"
        case .sepaMandat:               return "SEPA-Mandat / Bankverbindung"
        case .energieausweis:           return "Energieausweis"
        case .personalausweis:          return "Personalausweis"
        case .rechnung:                 return "Rechnung"
        case .bescheid:                 return "Bescheid"
        case .hvAbrechnung:             return "HV-Abrechnung"
        case .unbekannt:                return "Unbekannter Typ"
        }
    }

    var icon: String {
        switch self {
        case .mietvertrag, .mietvertragNachtrag: return "doc.text"
        case .nkErhoehungsschreiben:             return "envelope"
        case .uebergabeprotokollEinzug,
             .uebergabeprotokollAuszug:          return "key"
        case .sepaMandat:                        return "building.columns"
        case .energieausweis:                    return "bolt.badge.clock"
        case .personalausweis:                   return "person.text.rectangle"
        case .rechnung:                          return "eurosign.circle"
        case .bescheid:                          return "doc.badge.gearshape"
        case .hvAbrechnung:                      return "building.2.crop.circle"
        case .unbekannt:                         return "questionmark.folder"
        }
    }
}

// MARK: - Befund-Typen

struct ErkanntesFeld: Identifiable, Sendable, Equatable {
    let id: UUID
    let label: String
    let wert: String
    let quelle: String
    let konfidenz: Double
    /// Wenn dieses Feld durch den aktuellen Scan einen frueheren
    /// Wert ersetzt hat: alter Wert + Quelle.
    let altWert: String?
    let alteQuelle: String?
    /// Schwach-lesbare Stellen — der User soll pruefen.
    let warnung: String?

    init(
        id: UUID = UUID(),
        label: String,
        wert: String,
        quelle: String,
        konfidenz: Double,
        altWert: String? = nil,
        alteQuelle: String? = nil,
        warnung: String? = nil
    ) {
        self.id = id
        self.label = label
        self.wert = wert
        self.quelle = quelle
        self.konfidenz = konfidenz
        self.altWert = altWert
        self.alteQuelle = alteQuelle
        self.warnung = warnung
    }
}

struct FehlendeDaten: Identifiable, Sendable, Equatable {
    enum Kategorie: Sendable {
        case wichtig    // rot
        case empfohlen  // gelb
        case optional   // grau
    }

    let id: UUID
    let kategorie: Kategorie
    let titel: String
    let hinweis: String?
    /// Wenn bekannt, welcher Dokument-Typ das Feld liefern wuerde.
    let empfohlenerTyp: DokumentTyp?

    init(
        id: UUID = UUID(),
        kategorie: Kategorie,
        titel: String,
        hinweis: String? = nil,
        empfohlenerTyp: DokumentTyp? = nil
    ) {
        self.id = id
        self.kategorie = kategorie
        self.titel = titel
        self.hinweis = hinweis
        self.empfohlenerTyp = empfohlenerTyp
    }
}

struct Widerspruch: Identifiable, Sendable, Equatable {
    struct Variante: Identifiable, Sendable, Equatable {
        let id: UUID
        let wert: String
        let quelle: String
        /// Datum, wenn im Dokument erkennbar. Nil → Datum unklar.
        let datum: Date?

        init(id: UUID = UUID(), wert: String, quelle: String, datum: Date?) {
            self.id = id
            self.wert = wert
            self.quelle = quelle
            self.datum = datum
        }
    }

    let id: UUID
    let feld: String
    let varianten: [Variante]

    init(id: UUID = UUID(), feld: String, varianten: [Variante]) {
        self.id = id
        self.feld = feld
        self.varianten = varianten
    }
}

struct AnalyseBefund: Sendable, Equatable {
    let erkannterTyp: DokumentTyp
    let erkannteFelder: [ErkanntesFeld]
    let fehlendeDaten: [FehlendeDaten]
    let widersprueche: [Widerspruch]
    /// Roh-Extraktion fuer das spaetere Uebernehmen in SwiftData.
    let rohExtraktion: MietvertragsExtraktion
}

// MARK: - Sitzung

/// Eine Sitzung bundelt alle Scans, die der User nach Druck auf
/// „Neue Daten hinzufuegen/ergaenzen" hintereinander macht. Die
/// Sitzung lebt in der aufrufenden View (`KontextDetailSheet`)
/// und wird verworfen, sobald der User mit „So uebernehmen" oder
/// „Abbrechen" fertig ist.
@Observable
@MainActor
final class AnalyseSitzung: Identifiable {
    let id: UUID = UUID()
    let einheitID: UUID
    let einheitBezeichnung: String

    /// Kumulative Liste der bereits gescannten Dokument-Typen —
    /// in Reihenfolge. Wird an den naechsten Analyse-Call
    /// uebergeben, damit der Stub / spaeter Claude weiss, was
    /// schon da ist.
    private(set) var dokumentTypen: [DokumentTyp] = []

    /// label → zuletzt gueltiger Feld-Befund. Basis fuer den
    /// Merge: kommt ein Feld erneut mit abweichendem Wert, wird
    /// der alte in altWert / alteQuelle wandern.
    private(set) var aktuelleFelder: [String: ErkanntesFeld] = [:]

    /// Gesammelte Widersprueche — wachsen mit jedem Scan, werden
    /// aber nur einmal dem User vorgelegt.
    private(set) var widersprueche: [Widerspruch] = []

    /// Letzter Analyse-Befund (fuer die UI-Anzeige).
    private(set) var letzterBefund: AnalyseBefund?

    init(einheit: Wohneinheit) {
        self.einheitID = einheit.id
        self.einheitBezeichnung = einheit.bezeichnung
    }

    /// Scan-Anzahl (1 = erster Scan der Sitzung).
    var scanAnzahl: Int { dokumentTypen.count }

    /// Mergt einen neuen Befund in die Sitzung. Fuer jedes Feld im
    /// Befund: ist es neu → eintragen. Hat der alte Wert denselben
    /// Inhalt → nur die Quelle bleibt aktuell. Ist der Wert
    /// anders → den bisherigen Wert als altWert markieren.
    func integriere(_ befund: AnalyseBefund) {
        dokumentTypen.append(befund.erkannterTyp)

        for neu in befund.erkannteFelder {
            if let bestehend = aktuelleFelder[neu.label] {
                if bestehend.wert == neu.wert {
                    // Gleich — nur Quelle refreshen
                    aktuelleFelder[neu.label] = ErkanntesFeld(
                        id: bestehend.id,
                        label: neu.label,
                        wert: neu.wert,
                        quelle: neu.quelle,
                        konfidenz: max(bestehend.konfidenz, neu.konfidenz),
                        altWert: bestehend.altWert,
                        alteQuelle: bestehend.alteQuelle,
                        warnung: neu.warnung
                    )
                } else {
                    // Update — bisheriger Wert wandert in altWert
                    aktuelleFelder[neu.label] = ErkanntesFeld(
                        id: bestehend.id,
                        label: neu.label,
                        wert: neu.wert,
                        quelle: neu.quelle,
                        konfidenz: neu.konfidenz,
                        altWert: bestehend.wert,
                        alteQuelle: bestehend.quelle,
                        warnung: neu.warnung
                    )
                }
            } else {
                aktuelleFelder[neu.label] = neu
            }
        }

        widersprueche.append(contentsOf: befund.widersprueche)
        letzterBefund = befund
    }

    /// UI-Reihenfolge: wichtig → empfohlen → optional, dabei
    /// alphabetisch. Aktueller Befund ist Single-Source.
    func erkannteFelderSortiert() -> [ErkanntesFeld] {
        aktuelleFelder
            .values
            .sorted { $0.label.localizedCompare($1.label) == .orderedAscending }
    }
}

// MARK: - Service

@MainActor
enum DokumentAnalyseService {

    /// Analysiert einen frisch gescannten Dokumenten-Stapel im
    /// Kontext einer Sitzung. Der Stub ruft intern den
    /// `MietvertragsExtraktionService` auf (echter Claude-Call,
    /// in DEBUG ggf. Demo-Fallback ohne API-Key). Der erkannte
    /// Dokument-Typ kommt DIREKT aus der Claude-Antwort, nicht
    /// aus einer lokalen Heuristik. Wer eine Sequenz-Abhaengigkeit
    /// braucht (z.B. „Erhoehungsschreiben ueberschreibt Vertrag"),
    /// bekommt sie durch den Sitzungs-Merge in `AnalyseSitzung.
    /// integriere`.
    static func analysiere(
        bilder: [UIImage],
        sitzung: AnalyseSitzung,
        einheit: Wohneinheit?
    ) async throws -> AnalyseBefund {
        let analyse = try await MietvertragsExtraktionService.extrahiere(ausBildern: bilder)
        let typ = analyse.erkannterTyp
        let extraktion = analyse.extraktion

        let felder = baueFelder(
            aus: extraktion,
            typ: typ,
            sitzung: sitzung
        )
        let fehlend = berechneFehlendeDaten(
            einheit: einheit,
            sitzung: sitzung,
            zusaetzlicherTyp: typ
        )

        return AnalyseBefund(
            erkannterTyp: typ,
            erkannteFelder: felder,
            fehlendeDaten: fehlend,
            widersprueche: [],
            rohExtraktion: extraktion
        )
    }

    // MARK: - Felder aus Extraktion bauen

    private static func baueFelder(
        aus e: MietvertragsExtraktion,
        typ: DokumentTyp,
        sitzung: AnalyseSitzung
    ) -> [ErkanntesFeld] {
        let quelle = typ.anzeige

        var out: [ErkanntesFeld] = []

        if let adr = e.adresse.wert, !adr.isEmpty {
            out.append(.init(
                label: "Adresse",
                wert: adr,
                quelle: quelle,
                konfidenz: e.adresse.konfidenz,
                warnung: lesbarkeitsHinweis(e.adresse.konfidenz)
            ))
        }
        if let flaeche = e.einheitFlaecheM2.wert, flaeche > 0 {
            out.append(.init(
                label: "Fläche",
                wert: NSDecimalNumber(decimal: flaeche).stringValue + " m²",
                quelle: quelle,
                konfidenz: e.einheitFlaecheM2.konfidenz,
                warnung: lesbarkeitsHinweis(e.einheitFlaecheM2.konfidenz)
            ))
        }
        if let name = e.mieterName.wert, !name.isEmpty {
            out.append(.init(
                label: "Mieter",
                wert: name,
                quelle: quelle,
                konfidenz: e.mieterName.konfidenz,
                warnung: lesbarkeitsHinweis(e.mieterName.konfidenz)
            ))
        }
        if let anschrift = e.mieterAnschrift.wert, !anschrift.isEmpty {
            out.append(.init(
                label: "Anschrift",
                wert: anschrift,
                quelle: quelle,
                konfidenz: e.mieterAnschrift.konfidenz,
                warnung: lesbarkeitsHinweis(e.mieterAnschrift.konfidenz)
            ))
        }
        if let einzug = e.einzugAm.wert {
            out.append(.init(
                label: "Einzug",
                wert: Self.datum(einzug),
                quelle: quelle,
                konfidenz: e.einzugAm.konfidenz,
                warnung: lesbarkeitsHinweis(e.einzugAm.konfidenz)
            ))
        }
        if let vz = e.vorauszahlungMonatEuro.wert, vz > 0 {
            // Bei Erhoehungsschreiben extrahiert Claude den alten
            // Wert mit — dann wird er direkt am Feld als
            // „aktualisiert durch … vorher: …" ausgewiesen.
            let altWert: String? = e.vorauszahlungVorherEuro.wert.map { Formatting.euro($0) }
            let quelleFuerNK: String = altWert != nil
                ? "\(quelle)\(gueltigSuffix(e.vorauszahlungGueltigAb.wert))"
                : quelle
            out.append(.init(
                label: "NK-Vorauszahlung",
                wert: Formatting.euro(vz),
                quelle: quelleFuerNK,
                konfidenz: e.vorauszahlungMonatEuro.konfidenz,
                altWert: altWert,
                alteQuelle: altWert != nil ? "früherer Stand laut Dokument" : nil,
                warnung: lesbarkeitsHinweis(e.vorauszahlungMonatEuro.konfidenz)
            ))
        }
        if let miete = e.kaltmieteEuro.wert, miete > 0 {
            let altWert: String? = e.kaltmieteVorherEuro.wert.map { Formatting.euro($0) }
            let quelleFuerMiete: String = altWert != nil
                ? "\(quelle)\(gueltigSuffix(e.kaltmieteGueltigAb.wert))"
                : quelle
            out.append(.init(
                label: "Kaltmiete",
                wert: Formatting.euro(miete),
                quelle: quelleFuerMiete,
                konfidenz: e.kaltmieteEuro.konfidenz,
                altWert: altWert,
                alteQuelle: altWert != nil ? "früherer Stand laut Dokument" : nil,
                warnung: lesbarkeitsHinweis(e.kaltmieteEuro.konfidenz)
            ))
        }
        if let kaution = e.kaution.wert, kaution > 0 {
            out.append(.init(
                label: "Kaution",
                wert: Formatting.euro(kaution),
                quelle: quelle,
                konfidenz: e.kaution.konfidenz,
                warnung: e.kaution.konfidenz < 0.5 ? "Bitte prüfen — schlecht lesbar" : lesbarkeitsHinweis(e.kaution.konfidenz)
            ))
        }

        return out
    }

    /// „ (gültig ab 01.09.2024)"-Suffix wenn Datum vorhanden.
    private static func gueltigSuffix(_ datum: Date?) -> String {
        guard let datum else { return "" }
        return " (gültig ab \(Self.datum(datum)))"
    }

    private static func lesbarkeitsHinweis(_ konfidenz: Double) -> String? {
        konfidenz < 0.5 ? "Bitte prüfen — schlecht lesbar" : nil
    }

    private static func datum(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "dd.MM.yyyy"
        return f.string(from: d)
    }

    // MARK: - Fehlende Daten

    /// Berechnet, was fuer eine vollstaendige WE-Akte noch fehlt.
    /// Basis ist:
    ///   1. Der aktuelle SwiftData-Zustand der Einheit + des
    ///      aktiven Mietverhaeltnisses, PLUS
    ///   2. Die Sitzungs-Felder (`sitzung.aktuelleFelder`) — was
    ///      Claude in einem der Scans schon erkannt hat, gilt als
    ///      „bekannt" und taucht nicht mehr unter „fehlt" auf, auch
    ///      wenn der User die Werte noch nicht in SwiftData
    ///      uebernommen hat.
    ///   3. Die Liste der bereits gescannten Dokument-Typen —
    ///      steuert die „empfohlenen" Eintraege (Uebergabe-
    ///      protokoll, SEPA, Energieausweis, Personalausweis).
    static func berechneFehlendeDaten(
        einheit: Wohneinheit?,
        sitzung: AnalyseSitzung,
        zusaetzlicherTyp: DokumentTyp?
    ) -> [FehlendeDaten] {
        var bereitsGescannt = Set(sitzung.dokumentTypen)
        if let t = zusaetzlicherTyp { bereitsGescannt.insert(t) }

        // Feld-Labels, die Claude in irgendeinem Scan der Sitzung
        // erkannt hat. Entscheidet, ob ein „fehlt"-Eintrag noch
        // angezeigt werden soll.
        let erkannt = Set(sitzung.aktuelleFelder.keys)
        func hatErkannt(_ label: String) -> Bool { erkannt.contains(label) }

        var out: [FehlendeDaten] = []
        let mv = einheit.flatMap { e in (e.mietverhaeltnisse ?? []).first { $0.auszugAm == nil } }

        // Wichtig — pro Feld: nur „fehlt" wenn WEDER in der
        // Sitzung erkannt NOCH im SwiftData-Stand vorhanden.
        if !hatErkannt("Fläche") && (einheit?.flaecheM2 ?? 0) == 0 {
            out.append(.init(
                kategorie: .wichtig,
                titel: "Fläche nicht bekannt",
                hinweis: "Seite 1 des Mietvertrags scannen oder manuell eintragen.",
                empfohlenerTyp: .mietvertrag
            ))
        }
        if !hatErkannt("Mieter") && ((mv?.mieterName.isEmpty) ?? true) {
            out.append(.init(
                kategorie: .wichtig,
                titel: "Mietername fehlt",
                hinweis: "Mietvertrag scannen oder unten manuell eintragen.",
                empfohlenerTyp: .mietvertrag
            ))
        }
        if !hatErkannt("NK-Vorauszahlung") && mv?.vorauszahlungErfasst != true {
            out.append(.init(
                kategorie: .wichtig,
                titel: "Aktuelle NK-Vorauszahlung nicht erfasst",
                hinweis: "Mietvertrag oder Erhöhungsschreiben scannen.",
                empfohlenerTyp: .nkErhoehungsschreiben
            ))
        }
        // Einzugsdatum: erkannt in Sitzung oder vorhandenes MV.
        if !hatErkannt("Einzug") && mv == nil {
            out.append(.init(
                kategorie: .wichtig,
                titel: "Einzugsdatum nicht bekannt",
                hinweis: "Mietvertrag erfassen.",
                empfohlenerTyp: .mietvertrag
            ))
        }
        // Adresse: nur als „fehlt" melden wenn die Immobilie noch
        // keine und Claude sie nicht erkannt hat.
        let immoAdresseLeer = (einheit?.immobilie?.adresse.isEmpty) ?? true
        if !hatErkannt("Adresse") && immoAdresseLeer {
            out.append(.init(
                kategorie: .wichtig,
                titel: "Objekt-Adresse fehlt",
                hinweis: "Mietvertrag oder Übergabeprotokoll scannen.",
                empfohlenerTyp: .mietvertrag
            ))
        }

        // Empfohlen
        if !hatErkannt("Anschrift")
            && ((mv?.mieterAnschrift.isEmpty) ?? true)
            && mv != nil
        {
            out.append(.init(
                kategorie: .empfohlen,
                titel: "Anschrift Mieter fehlt",
                hinweis: "Für den Postversand der Abrechnung benötigt.",
                empfohlenerTyp: .mietvertrag
            ))
        }
        if !bereitsGescannt.contains(.uebergabeprotokollEinzug) {
            out.append(.init(
                kategorie: .empfohlen,
                titel: "Übergabeprotokoll (Einzug) noch nicht vorhanden",
                hinweis: "Wichtig bei späterem Auszug und Kautionsrückgabe.",
                empfohlenerTyp: .uebergabeprotokollEinzug
            ))
        }
        if !bereitsGescannt.contains(.sepaMandat) {
            out.append(.init(
                kategorie: .empfohlen,
                titel: "SEPA-Mandat / aktuelle Bankverbindung fehlt",
                hinweis: "Für Mietzahlungen und Kautionsrückzahlung.",
                empfohlenerTyp: .sepaMandat
            ))
        }

        // Optional
        if !bereitsGescannt.contains(.energieausweis) {
            out.append(.init(
                kategorie: .optional,
                titel: "Energieausweis",
                hinweis: "Gesetzlich beim Mieterwechsel vorzulegen, für Abrechnung nicht nötig.",
                empfohlenerTyp: .energieausweis
            ))
        }
        if !bereitsGescannt.contains(.personalausweis) {
            out.append(.init(
                kategorie: .optional,
                titel: "Personalausweis-Kopie",
                hinweis: "Nicht erforderlich — wird nicht in der App gespeichert.",
                empfohlenerTyp: .personalausweis
            ))
        }

        return out
    }
}
