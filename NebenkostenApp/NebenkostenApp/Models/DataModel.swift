//
//  DataModel.swift
//  NebenkostenApp
//
//  SwiftData-Modelle für die Nebenkostenabrechnung.
//
//  CloudKit-Kompatibilität: Alle Properties haben Default-Werte, alle
//  Relationships sind optional, keine @Attribute(.unique)-Constraints.
//  Für den privaten CloudKit-Container pro User.
//

import Foundation
import SwiftData

// MARK: - AppUser

enum UserRolle: String, Codable, CaseIterable, Sendable {
    case privat       = "Privat"
    case unternehmer  = "Unternehmer"
}

/// Stammdaten der App-Nutzerin. Ein privater CloudKit-Container pro
/// Apple-ID → in der Regel existiert genau ein AppUser-Objekt. Wird über
/// den Onboarding-Flow angelegt (DSGVO-Zustimmung + Basisdaten).
@Model
final class AppUser {
    var id: UUID = UUID()
    var erstelltAm: Date = Date()

    var name: String = ""
    var anschrift: String = ""
    var ort: String = ""
    var email: String = ""
    var telefon: String = ""

    /// Steuer-ID optional.
    var steuerID: String = ""

    /// String-Backing schützt vor Crashes, wenn bestehende Stores die
    /// Spalte noch nicht kennen.
    private var rolleRoh: String = UserRolle.privat.rawValue
    var rolle: UserRolle {
        get { UserRolle(rawValue: rolleRoh) ?? .privat }
        set { rolleRoh = newValue.rawValue }
    }

    var iban: String = ""

    var datenschutzZustimmungAm: Date?
    var avvZustimmungAm: Date?

    init() {}
}

// MARK: - Immobilie

enum Heizungsart: String, Codable, CaseIterable, Sendable {
    case gasZentral       = "Gas-Zentralheizung"
    case oelZentral       = "Öl-Zentralheizung"
    case fernwaerme       = "Fernwärme"
    case strom            = "Strom (Nachtspeicher)"
    case waermepumpe      = "Wärmepumpe"
    case etagenheizung    = "Etagenheizung"
    /// Dezentral / kein zentrales System. Bei dieser Wahl wird
    /// keine HeizkostenV-Logik angewandt und im Kostenart-Setup
    /// keine „Heizung und Warmwasser"-Kostenart angelegt.
    case keine            = "Keine Zentralheizung / Etagenheizung"
}

enum Warmwasserbereitung: String, Codable, CaseIterable, Sendable {
    case zentralMitHeizung = "Zentral mit Heizung"
    case zentralSeparat    = "Zentral separat"
    case elektroboiler     = "Elektro-Boiler"
    case durchlauferhitzer = "Durchlauferhitzer"
}

@Model
final class Immobilie {
    var id: UUID = UUID()
    var erstelltAm: Date = Date()

    /// Straße und Hausnummer, z.B. "Bahnhofstraße 37"
    var adresse: String = ""

    /// Postleitzahl und Ort, z.B. "12207 Berlin"
    var ort: String = ""

    /// Gesamtwohn-/Nutzfläche in m² (Summe aller Einheiten inkl. Gewerbe)
    var gesamtflaecheM2: Decimal = 0

    /// Monat (1-12), in dem das Abrechnungsjahr beginnt.
    /// Kalenderjahr → 1. Bei Bahnhofstr. 37 → 11 (01.11.-31.10.)
    var abrechnungsstartMonat: Int = 1

    /// Tag im Monat (1-31) des Abrechnungsstarts. Meist 1.
    var abrechnungsstartTag: Int = 1

    // String-Backing, damit bestehende Stores ohne diese Spalten nicht
    // beim Lesen crashen (SwiftData liefert dann nil — der String-Default
    // fängt das ab).
    private var heizungsartRoh: String = Heizungsart.gasZentral.rawValue
    private var warmwasserbereitungRoh: String = Warmwasserbereitung.zentralMitHeizung.rawValue

    var heizungsart: Heizungsart {
        get { Heizungsart(rawValue: heizungsartRoh) ?? .gasZentral }
        set { heizungsartRoh = newValue.rawValue }
    }
    var warmwasserbereitung: Warmwasserbereitung {
        get { Warmwasserbereitung(rawValue: warmwasserbereitungRoh) ?? .zentralMitHeizung }
        set { warmwasserbereitungRoh = newValue.rawValue }
    }

    // MARK: Relationships

    @Relationship(deleteRule: .cascade, inverse: \Wohneinheit.immobilie)
    var wohneinheiten: [Wohneinheit]? = []

    @Relationship(deleteRule: .cascade, inverse: \Abrechnungsperiode.immobilie)
    var perioden: [Abrechnungsperiode]? = []

    /// Nur Hauptzähler der Liegenschaft (Hausanschluss Wasser, Gas, etc.).
    /// Wohnungszähler hängen an der jeweiligen Wohneinheit.
    @Relationship(deleteRule: .cascade, inverse: \Zaehler.immobilie)
    var hauptzaehler: [Zaehler]? = []

    @Relationship(deleteRule: .cascade, inverse: \Rechnung.immobilie)
    var rechnungen: [Rechnung]? = []

    @Relationship(deleteRule: .cascade, inverse: \Kostenart.immobilie)
    var kostenarten: [Kostenart]? = []

    /// HV-Abrechnungen (WEG-Einzelabrechnungen) die diesem Objekt
    /// zugeordnet sind. Cascade-Delete: wird das Objekt geloescht,
    /// gehen die HV-Abrechnungen inkl. ihrer Positionen und
    /// Eigentuemerkosten mit.
    @Relationship(deleteRule: .cascade, inverse: \HVAbrechnung.immobilie)
    var hvAbrechnungen: [HVAbrechnung]? = []

    init() {}
}

// MARK: - Wohneinheit

enum Nutzungsart: String, Codable, CaseIterable {
    case wohnung
    case einliegerwohnung
    case gewerbe
    case leerstand
}

@Model
final class Wohneinheit {
    var id: UUID = UUID()

    /// Menschlicher Name, z.B. "EG", "OG", "Kellergeschoss Tonstudio"
    var bezeichnung: String = ""

    /// Wohn-/Nutzfläche in m²
    var flaecheM2: Decimal = 0

    /// Nutzungsart (Wohnung, Gewerbe, …)
    var nutzungsart: Nutzungsart = Nutzungsart.wohnung

    /// Wohnt der Vermieter selbst in dieser Einheit? Relevant für §35a EStG.
    var selbstnutzung: Bool = false

    /// Farbkennung der Einheit als Hex-Code (z.B. "#FFAA00"). Wird für
    /// den ScopeIndicator verwendet, damit der User auf einen Blick
    /// sieht in welcher Einheit er gerade ist. Leer = Default-Farbe aus
    /// Geschoss-Rang (KG=lila, EG=blau, OG=grün, sonst orange).
    var farbkennungHex: String = ""

    // MARK: Relationships

    var immobilie: Immobilie?

    @Relationship(deleteRule: .cascade, inverse: \Zaehler.wohneinheit)
    var zaehler: [Zaehler]? = []

    @Relationship(deleteRule: .cascade, inverse: \Mietverhaeltnis.wohneinheit)
    var mietverhaeltnisse: [Mietverhaeltnis]? = []

    init() {}
}

// MARK: - Mietverhältnis

enum MieterTyp: String, Codable, CaseIterable, Sendable {
    case wohnungsmieter = "Wohnungsmieter"
    case gewerbemieter  = "Gewerbemieter"
    case selbstnutzer   = "Selbstnutzer"
}

@Model
final class Mietverhaeltnis {
    var id: UUID = UUID()

    var mieterName: String = ""
    var mieterAnschrift: String = ""
    var mieterEmail: String = ""

    /// Gespeicherter Roh-String. Wir halten das enum-Feld NICHT direkt als
    /// `@Model`-Property, damit bestehende SwiftData-Stores (aus älteren
    /// Schemata ohne diese Spalte) nicht beim Lesen crashen — SwiftData
    /// liefert in dem Fall nil, der String-Default hält den Typsicher.
    private var mieterTypRoh: String = MieterTyp.wohnungsmieter.rawValue

    var mieterTyp: MieterTyp {
        get { MieterTyp(rawValue: mieterTypRoh) ?? .wohnungsmieter }
        set { mieterTypRoh = newValue.rawValue }
    }

    /// Einzugsdatum
    var einzugAm: Date = Date()

    /// Auszugsdatum, nil bei aktivem Mietverhältnis
    var auszugAm: Date?

    /// Monatliche Betriebskostenvorauszahlung in €.
    /// Strikte-Daten-Regel: nur als erfasst gewertet, wenn
    /// `vorauszahlungErfasst == true`. Ein Default-0 ohne Flag
    /// signalisiert „nicht erfasst", nicht „gezielt 0 €".
    var vorauszahlungMonatEuro: Decimal = 0

    /// Strikte-Daten-Marker: `true`, wenn der User die Vorauszahlung
    /// aktiv gesetzt hat (auch auf 0 €). Default `false` für
    /// Bestandsdaten — wird durch die StrikteDatenMigration auf
    /// `true` gesetzt, wenn bereits ein Betrag vorhanden ist. Bei
    /// `false` blockiert der PreFlight-Check die Berechnung.
    var vorauszahlungErfasst: Bool = false

    /// Datum, ab dem die aktuelle Vorauszahlung gilt. Optional —
    /// wenn nicht gesetzt, gilt die VZ als allgemeingueltig. Das
    /// Feld wird im VorauszahlungEingabeSheet als „Gueltig ab"
    /// erfasst (Default = Perioden-Startdatum) und erlaubt spaeter
    /// eine VZ-Historie pro Mietverhaeltnis ohne harten Schema-
    /// Bruch.
    var vorauszahlungGueltigAb: Date?

    /// Anzahl Personen im Haushalt (für personenbezogene Umlagen)
    var anzahlPersonen: Int = 1

    // MARK: Relationships

    var wohneinheit: Wohneinheit?

    @Relationship(deleteRule: .cascade, inverse: \Abrechnung.mietverhaeltnis)
    var abrechnungen: [Abrechnung]? = []

    init() {}
}

// MARK: - Zähler

enum Zaehlertyp: String, Codable, CaseIterable {
    /// Hauptzähler an der Liegenschaft (Hausanschluss)
    case haupt
    /// Zähler pro Wohneinheit
    case wohnung
    /// Zwischenzähler (z.B. Gartenwasser, zieht vom Hauptverbrauch ab)
    case zwischen
}

enum Medium: String, Codable, CaseIterable {
    case kaltwasser
    case warmwasser
    case gas
    case strom
    case waermeenergie    // Wärmemengenzähler (kWh)
    case oel
}

@Model
final class Zaehler {
    var id: UUID = UUID()

    /// Seriennummer auf dem Gerät, z.B. "8SEN0210876943"
    var seriennummer: String = ""

    /// Lesbarer Name, z.B. "Hauptzähler Wasser", "WMZ OG Bad"
    var bezeichnung: String = ""

    var typ: Zaehlertyp = Zaehlertyp.haupt
    var medium: Medium = Medium.kaltwasser

    /// Einheit der Anzeige, z.B. "m³", "kWh"
    var einheit: String = ""

    /// Gaszähler: Umrechnungsfaktor z-Zahl, default 1
    var umrechnungsfaktor: Decimal = 1

    /// Gaszähler: Brennwert in kWh/m³ (GASAG liefert das auf der Rechnung)
    var brennwertKwhProM3: Decimal?

    // MARK: Relationships
    //
    // Entweder immobilie (Hauptzähler) ODER wohneinheit (Wohnungszähler) ist
    // gesetzt — nie beides. Invariante wird in der Calc-Layer validiert.

    var immobilie: Immobilie?
    var wohneinheit: Wohneinheit?

    @Relationship(deleteRule: .cascade, inverse: \Zaehlerstand.zaehler)
    var staende: [Zaehlerstand]? = []

    init() {}
}

// MARK: - Zählerstand

enum Ablesequelle: String, Codable, CaseIterable {
    case manuell
    case kiExtrahiert
    case importiert
    case versorgerRechnung
    case geschaetzt

    var anzeigeName: String {
        switch self {
        case .manuell:           return "Manuell"
        case .kiExtrahiert:      return "Foto"
        case .importiert:        return "Importiert"
        case .versorgerRechnung: return "Versorger"
        case .geschaetzt:        return "Geschätzt"
        }
    }
}

@Model
final class Zaehlerstand {
    var id: UUID = UUID()

    var ablesedatum: Date = Date()
    var stand: Decimal = 0

    /// Strikte-Daten-Marker: Zeitpunkt der aktiven Eingabe durch den
    /// User. Ein Stand gilt nur dann als „erfasst", wenn
    /// `erfasstAm != nil`. Default `nil` schützt vor stillen 0-Werten,
    /// die bei neuen Zählerstand-Einträgen ohne User-Input entstehen.
    /// Die StrikteDatenMigration setzt für Bestandsdaten
    /// `erfasstAm = ablesedatum`.
    var erfasstAm: Date?

    var quelle: Ablesequelle = Ablesequelle.manuell

    /// Foto des Zählers als Nachweis (CloudKit Asset via externalStorage)
    @Attribute(.externalStorage) var foto: Data?

    /// Freitext-Notizen, z.B. "Abgelesen vor Mieterwechsel"
    var notizen: String = ""

    var zaehler: Zaehler?

    init() {}
}

// MARK: - Kostenart

enum Umlageschluessel: String, Codable, CaseIterable {
    /// Nach m² Wohnfläche
    case flaeche
    /// Nach Anzahl Personen
    case personen
    /// Direkt nach Verbrauch (z.B. Wasser m³)
    case verbrauch
    /// Gleichmäßig pro Wohneinheit
    case einheiten
    /// HeizkostenV: 30% Fläche, 70% Verbrauch (Default)
    case heizkosten3070
    /// HeizkostenV: 50/50
    case heizkosten5050
    /// Warmwasser: 30% Fläche, 70% Warmwasserzähler
    case warmwasser3070
    /// Direkt einer Einheit zugeordnet, nicht umgelegt
    case direkt
    /// Manuelle Festlegung pro Einheit
    case individuell

    var anzeigeName: String {
        switch self {
        case .flaeche:        return "Nach m² Fläche"
        case .personen:       return "Nach Personen"
        case .verbrauch:      return "Nach Verbrauch"
        case .einheiten:      return "Gleich pro Einheit"
        case .heizkosten3070: return "HeizkostenV 30 / 70"
        case .heizkosten5050: return "HeizkostenV 50 / 50"
        case .warmwasser3070: return "Warmwasser 30 / 70"
        case .direkt:         return "Direkt zugeordnet"
        case .individuell:    return "Individuell"
        }
    }
}

@Model
final class Kostenart {
    var id: UUID = UUID()

    /// z.B. "Grundsteuer", "Be- und Entwässerung", "Heizung"
    var bezeichnung: String = ""

    /// BetrKV §2 Nummer, z.B. "1", "2", "4a"
    var betrKvKategorie: String = ""

    var umlageschluessel: Umlageschluessel = Umlageschluessel.flaeche

    /// §35a EStG haushaltsnahe Dienstleistung oder Handwerkerleistung?
    var paragraph35a: Bool = false

    /// Nur Lohnanteil absetzbar (Handwerker: ja, Reinigung: typ. gesamt)
    var paragraph35aNurLohnanteil: Bool = false

    /// In der Abrechnung aktiv?
    var aktiv: Bool = true

    /// Reihenfolge auf der Abrechnung
    var sortierung: Int = 0

    // MARK: Relationships

    var immobilie: Immobilie?

    @Relationship(deleteRule: .nullify, inverse: \Rechnung.kostenart)
    var rechnungen: [Rechnung]? = []

    @Relationship(deleteRule: .nullify, inverse: \Abrechnungsposition.kostenart)
    var positionen: [Abrechnungsposition]? = []

    init() {}
}

// MARK: - Rechnung

@Model
final class Rechnung {
    var id: UUID = UUID()

    /// Lieferant, z.B. "GASAG", "Berliner Wasserbetriebe", "Allianz"
    var lieferant: String = ""

    /// Rechnungsnummer, z.B. "211002198550"
    var rechnungsnummer: String = ""

    /// Rechnungsdatum (Ausstellung)
    var rechnungsdatum: Date = Date()

    /// Leistungszeitraum von (kann gebrochen zum Abrechnungsjahr liegen!)
    var leistungVon: Date = Date()
    /// Leistungszeitraum bis
    var leistungBis: Date = Date()

    /// Gesamtbetrag brutto in €
    var betragBruttoEuro: Decimal = 0

    /// Lohnanteil brutto für §35a, falls ausgewiesen
    var lohnanteilBruttoEuro: Decimal?

    /// Abgerechnete Verbrauchsmenge, falls die Rechnung einen Hauptverbrauch
    /// ausweist (z.B. GASAG Jahresrechnung in kWh, BWB-Trinkwasser in m³).
    /// Wird vom HeizkostenRechner bevorzugt gegenüber einer Zählerstand-
    /// Differenz verwendet, wenn ein Zählerwechsel innerhalb der Periode
    /// den Hauptzähler-Lauf unterbricht.
    var verbrauchMenge: Decimal?

    /// Interner Arbeitspreis €/kWh für den Warmwasser/Heizung-Kostensplit.
    /// Nur bei Gas-Hauptrechnungen gesetzt (z.B. GASAG 0,104255 €/kWh für
    /// Bahnhofstr. 37). Wenn vorhanden, splittet HeizkostenRechner die
    /// Brennstoffkosten nach ww_gas_kwh × internerArbeitspreis statt
    /// pro-rata. Siehe HeizkostenParameter.internerArbeitspreisEuroProKwh.
    var internerArbeitspreisEuroProKwh: Decimal?

    /// PDF oder Foto der Rechnung
    @Attribute(.externalStorage) var anhang: Data?
    var anhangTyp: String = "pdf"    // "pdf", "jpg", "heic"

    /// KI-Extraktion: Rohdaten oder Notizen
    var extraktionsNotizen: String = ""

    /// Wurde die Rechnung bereits geprüft/freigegeben?
    var geprueft: Bool = false

    /// Validierungs-Status — bestimmt, ob diese Rechnung für eine
    /// Abrechnung verwendet werden darf. Nach Task "Strikte Daten"
    /// sind nur `manuell`, `validiert` und `importiert` berechnungs-
    /// tauglich. Ein `aiVorschlag` blockiert die Berechnung.
    ///
    /// Gespeichert als Roh-String, damit bestehende Stores (ohne
    /// diese Spalte) nicht crashen — Default ist `importiert`, weil
    /// Phase-0-Bestandsdaten durch die JSON-Seeds als validiert
    /// gelten.
    private var validierungsStatusRoh: String = ValidierungsStatus.importiert.rawValue

    var validierungsStatus: ValidierungsStatus {
        get { ValidierungsStatus(rawValue: validierungsStatusRoh) ?? .importiert }
        set { validierungsStatusRoh = newValue.rawValue }
    }

    // MARK: Relationships

    var immobilie: Immobilie?
    var kostenart: Kostenart?

    init() {}
}

/// Validierungs-Status einer Rechnung.
enum ValidierungsStatus: String, Codable, CaseIterable, Sendable {
    /// Vom User händisch erfasst — gilt als validiert.
    case manuell
    /// AI-Vorschlag, vom User explizit bestätigt — gilt als validiert.
    case validiert
    /// AI-Vorschlag, noch unvalidiert — BLOCKIERT Berechnungen.
    case aiVorschlag
    /// Aus JSON-Import (Phase-0-Seed oder Benutzer-Export) — gilt
    /// als validiert (Einmalzustand).
    case importiert

    /// `true`, wenn diese Rechnung für eine Berechnung verwendet
    /// werden darf. Der Pre-Flight-Check nutzt diese Semantik
    /// (siehe PreFlightService.rechnungsAnforderungen).
    var istBerechnungstauglich: Bool {
        switch self {
        case .manuell, .validiert, .importiert: return true
        case .aiVorschlag: return false
        }
    }

    var anzeigeName: String {
        switch self {
        case .manuell:     return "Manuell"
        case .validiert:   return "Validiert"
        case .aiVorschlag: return "KI-Vorschlag"
        case .importiert:  return "Importiert"
        }
    }
}

// MARK: - Abrechnungsperiode

@Model
final class Abrechnungsperiode {
    var id: UUID = UUID()

    var von: Date = Date()
    var bis: Date = Date()

    /// Abrechnungsstatus — abgeschlossen heißt: keine Änderungen mehr
    var abgeschlossen: Bool = false

    /// Wann versendet (nil = noch nicht)
    var versandtAm: Date?

    // MARK: Relationships

    var immobilie: Immobilie?

    @Relationship(deleteRule: .cascade, inverse: \Abrechnung.periode)
    var abrechnungen: [Abrechnung]? = []

    init() {}
}

// MARK: - Abrechnung (pro Mietverhältnis)

@Model
final class Abrechnung {
    var id: UUID = UUID()

    var erstelltAm: Date = Date()

    /// Gesamtbetrag aller auf diese Einheit umgelegten Kosten
    var gesamtkostenEuro: Decimal = 0

    /// Vorauszahlungen des Mieters in der Periode
    var vorauszahlungenEuro: Decimal = 0

    /// Saldo = gesamtkosten - vorauszahlungen
    /// Positiv → Nachzahlung des Mieters; Negativ → Erstattung
    var saldoEuro: Decimal = 0

    /// §35a EStG ausweisbarer Betrag (haushaltsnah + Handwerker)
    var steuer35aBetragEuro: Decimal = 0

    /// PDF der fertigen Abrechnung
    @Attribute(.externalStorage) var pdfDatei: Data?

    // MARK: Relationships

    var periode: Abrechnungsperiode?
    var mietverhaeltnis: Mietverhaeltnis?

    @Relationship(deleteRule: .cascade, inverse: \Abrechnungsposition.abrechnung)
    var positionen: [Abrechnungsposition]? = []

    init() {}
}

// MARK: - GespeichertesDokument

enum Dokumenttyp: String, Codable, CaseIterable, Sendable {
    case rechnung
    case bescheid
    case handwerkerbeleg
    case winterdienstbeleg
    case zaehlerfoto
    case mietvertrag
    case sonstiges

    var anzeigeName: String {
        switch self {
        case .rechnung:          return "Rechnung"
        case .bescheid:          return "Bescheid"
        case .handwerkerbeleg:   return "Handwerkerbeleg"
        case .winterdienstbeleg: return "Winterdienstbeleg"
        case .zaehlerfoto:       return "Zählerfoto"
        case .mietvertrag:       return "Mietvertrag"
        case .sonstiges:         return "Sonstiges"
        }
    }
}

enum DokumentQuelle: String, Codable, CaseIterable, Sendable {
    case kamera
    case mediathek
    case datei
}

/// Gescanntes oder importiertes Dokument. Alle Dokumente werden in
/// diesem MVP als PDF persistiert (Task 1.1-Grundsatz). Liegt in
/// `Documents/Scans/<YYYY>/<dateiname>`.
///
/// CloudKit-Hinweis: Kein `@Attribute(.unique)` auf der ID — CloudKit
/// erlaubt keine Unique-Constraints. UUIDs aus `UUID()` sind praktisch
/// kollisionsfrei.
@Model
final class GespeichertesDokument {
    var id: UUID = UUID()
    var erstelltAm: Date = Date()

    /// Reiner Dateiname (z.B. "2026-04-20_Rechnung_GASAG_Jahr-2025.pdf").
    var dateiname: String = ""
    /// Relativer Pfad unter App-Documents, inkl. Jahres-Unterordner,
    /// z.B. "Scans/2026/2026-04-20_Rechnung_GASAG_Jahr-2025.pdf".
    var dateipfadRelativ: String = ""
    /// 300×300-JPG-Thumbnail (erste Seite) für die Liste.
    var thumbnailPfad: String = ""

    var dateigroesseBytes: Int = 0
    var seitenanzahl: Int = 1

    /// String-Backing für CloudKit-Robustheit + Enum-Evolution.
    private var dokumenttypRoh: String = Dokumenttyp.sonstiges.rawValue
    var dokumenttyp: Dokumenttyp {
        get { Dokumenttyp(rawValue: dokumenttypRoh) ?? .sonstiges }
        set { dokumenttypRoh = newValue.rawValue }
    }

    private var quelleRoh: String = DokumentQuelle.datei.rawValue
    var quelle: DokumentQuelle {
        get {
            // Migration vom alten "galerie" auf "mediathek"
            if quelleRoh == "galerie" { return .mediathek }
            return DokumentQuelle(rawValue: quelleRoh) ?? .datei
        }
        set { quelleRoh = newValue.rawValue }
    }

    /// Versorger / Aussteller, freitext (z.B. "GASAG", "BWB"). Optional.
    var versorger: String?
    /// Kontext-Zusatz für den Dateinamen (z.B. "Kalenderjahr-2025").
    var kontext: String?
    /// Betrag brutto falls vom User erfasst.
    var betragBrutto: Decimal?
    /// Dokument-Datum (auf Rechnung ausgewiesenes Datum), optional.
    var dokumentdatum: Date?
    /// Einheit-Zuordnung: nil = objektweit, sonst "KG"/"EG"/"OG".
    var einheitId: String?
    /// Freier Notiztext.
    var notiz: String?

    // MARK: - 3-Ebenen-Datenmodell (Task 1.2)

    /// Ebene 1 Rohdaten — OCR-Volltext, unverändert.
    var ocrVolltext: String?
    /// Mittelwert-Confidence über alle Zeilen (0.0 … 1.0).
    var ocrConfidence: Double?
    /// Zeitpunkt des letzten OCR-Laufs.
    var ocrDurchgefuehrtAm: Date?

    // Ebene 2 Strukturiert — AIVorschlag-Relationship
    /// Zeitpunkt der letzten AI-Extraktion.
    var aiDurchgefuehrtAm: Date?

    @Relationship(deleteRule: .cascade, inverse: \AIVorschlag.dokument)
    var aiVorschlag: AIVorschlag?

    /// Ebene 3 Validiert — verknüpft das Dokument mit einer Rechnung,
    /// wenn der User die AI-Vorschläge übernommen hat. nil = noch
    /// nicht übernommen (oder nie übernommen, z.B. Zählerstand-Foto).
    var rechnungId: UUID?

    init() {}
}

// MARK: - AIVorschlag (Ebene 2)

/// Strukturierter AI-Vorschlag für die Felder eines Dokuments.
/// IMMER UNVALIDIERT — nur Ebene 3 (validiert, vom User bestätigt)
/// fließt in die Abrechnung ein. Siehe CLAUDE.md Abschnitt
/// "3-Ebenen-Datenmodell".
@Model
final class AIVorschlag {
    var id: UUID = UUID()

    var dokumentDatum: Date?
    var versorger: String?
    var betragBrutto: Decimal?
    var mwstSatz: Decimal?
    var rechnungsNr: String?
    var leistungszeitraumStart: Date?
    var leistungszeitraumEnde: Date?
    var kostenartVorschlag: String?

    /// Typ-spezifische Positionen als JSON-Array-String (z.B. bei
    /// BWB: Trink- und Schmutzwasser mit menge_m3 und gesamt).
    /// Struktur wird je nach Dokumenttyp vom Prompt diktiert.
    var positionenJSON: String?

    /// Konfidenz pro Feld als JSON-Data mit Dict `[Feldname: Double]`.
    /// Felder mit Konfidenz <0,6 werden im Validierungs-UI rot
    /// markiert.
    var konfidenzJeFeld: Data?

    // Rückverweis zum Dokument
    var dokument: GespeichertesDokument?

    init() {}
}

// MARK: - WarnungsAudit

/// Protokoll über vom User ignorierte Validierungs-Warnungen vor der
/// Abrechnungs-Erstellung. Datum + User + welche Warnungs-Kategorien
/// bewusst akzeptiert wurden. Wird im DSGVO-Export mitgeführt.
@Model
final class WarnungsAudit {
    var id: UUID = UUID()
    var erstelltAm: Date = Date()

    var userName: String = ""
    var periodeID: UUID?
    var mieterID: UUID?
    var mieterName: String = ""

    /// Kurzfassung, z.B. "3 Warnungen akzeptiert".
    var zusammenfassung: String = ""

    /// Alle akzeptierten Warnungen als JSON-Array-String: jedes Element
    /// mit stufe / kategorie / nachricht. Kein separates @Model, damit
    /// bei Schema-Änderungen der Warnungs-Struktur keine SwiftData-
    /// Migration nötig wird.
    var warnungenJSON: String = ""

    init() {}
}

// MARK: - Abrechnungsposition (Einzelposten)

@Model
final class Abrechnungsposition {
    var id: UUID = UUID()

    /// Gesamtkosten dieser Kostenart für die ganze Immobilie in der Periode
    var gesamtkostenEuro: Decimal = 0

    /// Anteil der Einheit an diesen Kosten
    var mieteranteilEuro: Decimal = 0

    /// Beschreibung des Verteilerschlüssels, z.B. "181/528 m²" oder "45 von 434 m³"
    var verteilerschluesselText: String = ""

    /// Sortierung auf der Abrechnung
    var sortierung: Int = 0

    // MARK: Relationships

    var abrechnung: Abrechnung?
    var kostenart: Kostenart?

    init() {}
}
