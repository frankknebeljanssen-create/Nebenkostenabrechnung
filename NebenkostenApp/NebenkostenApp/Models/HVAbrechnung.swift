//
//  HVAbrechnung.swift
//  NebenkostenApp — Models
//
//  Datenmodell fuer den neuen HV-Abrechnungs-Scan-Flow
//  (Stufe 2 · docs/hv-abrechnung-konzept.md).
//
//  Drei zusammenhaengende @Model-Klassen:
//
//  - `HVAbrechnung`  — Container. Stammdaten der Hausverwaltung +
//     Meta (MEA, Zeitraum, Abrechnungsspitze, Erhaltungsruecklage,
//     §35a). Enthaelt optional das PDF-Original als externalStorage-
//     Anhang. Cascade-Delete auf Positionen + Eigentuemerkosten.
//  - `HVPosition` — ein umlagefaehiger Posten der HV-Abrechnung.
//     Wird beim Uebernehmen automatisch als `Rechnung` an die
//     passende BetrKV-Kostenart gebucht; die HVPosition selbst
//     bleibt als Rohbeleg.
//  - `HVEigentuemerKosten` — ein nicht umlagefaehiger Posten.
//     Landet NIE in der Mieter-Abrechnung, sondern taucht in der
//     separaten Eigentuemer-Uebersicht auf.
//
//  CloudKit-Regeln beachtet: alle Properties haben Default-Werte,
//  alle Relationships optional, keine `.unique`-Constraints.
//

import Foundation
import SwiftData

@Model
final class HVAbrechnung {
    var id: UUID = UUID()
    var erfasstAm: Date = Date()

    // MARK: - Stammdaten der Hausverwaltung

    var hausverwaltungName: String = ""
    var hausverwaltungAdresse: String = ""
    var wegName: String = ""
    var gebaeudeAdresse: String = ""

    // MARK: - Eigentums-Anteil (MEA)

    /// Zaehler des Miteigentumsanteils. Beispiel 21297 (bei
    /// 21297/1000000). 0 = nicht gesetzt.
    var meaAnteil: Int = 0
    /// Gesamtnenner. Typisch 1000000 (WEG-Teilungserklaerungen
    /// rechnen meist in ppm). 1 als Default schuetzt Divisionen.
    var meaGesamt: Int = 1

    // MARK: - Abrechnungszeitraum

    var abrechnungszeitraumVon: Date = Date()
    var abrechnungszeitraumBis: Date = Date()

    // MARK: - Summen & Ergebnis

    /// Saldo der Abrechnungsspitze:
    ///  - negativ = Guthaben fuer den Eigentuemer
    ///  - positiv = Nachzahlung an die HV
    var abrechnungsspitzeEuro: Decimal = 0
    /// Geleistete Vorauszahlungen lt. Wirtschaftsplan der HV.
    var vorauszahlungenEuro: Decimal = 0
    /// Eigener Anteil an der Erhaltungsruecklage der WEG — bleibt
    /// ausdruecklich beim Eigentuemer, wird nie umgelegt.
    var erhaltungsruecklageAnteilEuro: Decimal = 0

    // MARK: - §35a EStG

    /// Handwerkerleistungen (ermaessigt bis 6000 €/Jahr, 20 %
    /// Steueranrechnung).
    var paragraph35aHandwerkerEuro: Decimal = 0
    /// Haushaltsnahe Dienstleistungen (ermaessigt bis 20000 €/Jahr,
    /// 20 % Steueranrechnung).
    var paragraph35aHaushaltsnahEuro: Decimal = 0

    // MARK: - Original-PDF

    /// PDF der HV-Abrechnung als externalStorage-Anhang. Optional.
    @Attribute(.externalStorage) var originalDokument: Data?

    // MARK: - Relationships

    var immobilie: Immobilie?

    @Relationship(deleteRule: .cascade, inverse: \HVPosition.hvAbrechnung)
    var umlagefaehigePositionen: [HVPosition]? = []

    @Relationship(deleteRule: .cascade, inverse: \HVEigentuemerKosten.hvAbrechnung)
    var eigentuemerKosten: [HVEigentuemerKosten]? = []

    init() {}
}

/// Eine einzelne umlagefaehige Position aus der HV-Abrechnung.
/// Bleibt als Rohbeleg erhalten, auch nachdem die passende
/// `Rechnung`-Entity angelegt wurde — zur Nachvollziehbarkeit
/// (User sieht im Analyse-Screen auch nach Uebernahme noch die
/// Quelldaten).
@Model
final class HVPosition {
    var id: UUID = UUID()

    /// Bezeichnung wie sie auf der HV-Abrechnung steht, z.B.
    /// „Wasserversorgung", „Muellabfuhr".
    var bezeichnung: String = ""

    /// Kontierungs-Nummer der Hausverwaltungs-Buchhaltung
    /// (z.B. „804000000"). Freitext.
    var kontierung: String = ""

    /// Gesamtkosten des Gebaeudes fuer diese Position (nicht der
    /// eigene Anteil). 0 = nicht erfasst.
    var gesamtkostenGebaeude: Decimal = 0

    /// Eigener Anteil in € (bereits nach MEA berechnet).
    var anteilEuro: Decimal = 0

    /// BetrKV-Bezeichnung bzw. Kostenart-Name, auf den diese
    /// Position gemappt werden soll. Claude liefert einen
    /// Vorschlag, der User kann im Analyse-Screen korrigieren.
    var betrkvKostenart: String = ""

    var hvAbrechnung: HVAbrechnung?

    /// Optional: die aus dieser Position beim Uebernahme-Flow
    /// erzeugte `Rechnung`. Wird beim Import gesetzt, damit die
    /// Abrechnungs-Detailansicht HV-Herkunft markieren kann.
    /// `deleteRule: .nullify` — wenn die HVAbrechnung geloescht
    /// wird (Cascade auf HVPosition), bleibt die Rechnung
    /// unveraendert, nur `Rechnung.hvPosition` fluegt zu nil.
    @Relationship(deleteRule: .nullify, inverse: \Rechnung.hvPosition)
    var rechnung: Rechnung?

    init() {}
}

/// Ein nicht umlagefaehiger Posten der HV-Abrechnung — Eigentuemer-
/// Kosten. Geht niemals an den Mieter weiter.
@Model
final class HVEigentuemerKosten {
    var id: UUID = UUID()

    var bezeichnung: String = ""
    var kontierung: String = ""
    var anteilEuro: Decimal = 0

    var hvAbrechnung: HVAbrechnung?

    init() {}
}
