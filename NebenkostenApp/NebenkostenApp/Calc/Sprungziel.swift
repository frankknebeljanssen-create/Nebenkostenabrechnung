//
//  Sprungziel.swift
//  NebenkostenApp — Calc-Layer
//
//  Typisierter Navigations-Hint für offene Datenanforderungen.
//  Wenn die VollstaendigkeitsPruefung feststellt, dass etwas
//  fehlt (z.B. Endstand eines Zählers, Vorauszahlung eines
//  Mieters, eine §35a-Kostenart ohne Lohnanteil), trägt sie das
//  passende Sprungziel an der Anforderung — und die UI kann per
//  Tap direkt zum Erfassungsort springen.
//
//  Einziger erlaubter Import: Foundation. Der Calc-Layer bleibt
//  SwiftUI-frei — `AppShellRouter` (SwiftUI-Seite) liest das
//  Sprungziel aus und löst daraus die Navigation aus.
//

import Foundation

/// Ein konkretes Navigations-Ziel, das zu einer Datenanforderung
/// gehört. Sechs Cases decken alle heute blockierenden oder
/// warnenden Fundstellen ab.
enum Sprungziel: Equatable, Hashable, Sendable {
    /// Objekt-Stammdaten (Adresse, Gesamtfläche, Heizungsart,
    /// Abrechnungsstart). Öffnet EinstellungenSheet → Objekt-Section.
    case einstellungenObjekt

    /// Mieter-Vorauszahlung einer spezifischen Einheit.
    /// Der Empfänger scrollt im EinstellungenSheet zur Mieter-
    /// Section und markiert die Einheit, deren VZ fehlt.
    case mieterVorauszahlung(einheitId: String)

    /// Konkreter Zählerstand, der noch nicht erfasst ist. Der
    /// Zähler-Tab öffnet das ZaehlerstandErfassenView-Sheet.
    case zaehlerstandErfassen(zaehlerId: UUID)

    /// Alle Rechnungen einer Kostenart (z.B. wenn eine Rechnung
    /// im Status `aiVorschlag` die Kategorie blockiert). Der
    /// Rechnungen-Tab klappt die passende Kostenart-Section auf.
    case rechnungKostenart(kostenartId: UUID)

    /// Scan-Flow direkt mit vorausgewaehlter Kostenart oeffnen.
    /// Wird von der Home-"Naechste Schritte"-Liste genutzt, wenn
    /// fuer eine Kostenart in der Periode noch keine Rechnung
    /// erfasst ist. Der User kommt sofort in den Scan, die
    /// Kostenart ist im UebernahmeSheet vorausgewaehlt — kein
    /// Umweg ueber die Rechnungen-Liste + manueller "+"-Button.
    case scanMitKostenart(kostenartId: UUID)

    /// Abrechnungsperiode-Grenzen (von < bis, Plausibilität).
    /// Öffnet EinstellungenSheet → Objekt-Section → Periode.
    case einstellungenPeriode

    /// Warm-Wasser-/WMZ-Plausibilität. Bleibt ein Hinweis, der
    /// auf den Zähler-Tab springt und dort die Wärme-Medium-Gruppe
    /// prominent markiert.
    case wmzPlausi
}

// MARK: - UIRoute

extension Sprungziel {
    /// Liefert die UI-Route zum Sprungziel: welcher Tab + welche
    /// optionale Aktion (Sheet öffnen, Section aufklappen).
    var uiRoute: UIRoute {
        switch self {
        case .einstellungenObjekt:
            return UIRoute(tab: .uebersicht, kontext: .oeffneEinstellungen(section: .objekt))
        case .mieterVorauszahlung(let id):
            return UIRoute(tab: .uebersicht, kontext: .oeffneEinstellungen(section: .mieter(einheitId: id)))
        case .zaehlerstandErfassen(let id):
            return UIRoute(tab: .zaehler, kontext: .erfasseZaehler(id: id))
        case .rechnungKostenart(let id):
            return UIRoute(tab: .rechnungen, kontext: .oeffneKostenart(id: id))
        case .scanMitKostenart(let id):
            return UIRoute(tab: .uebersicht, kontext: .oeffneScanMitKostenart(id: id))
        case .einstellungenPeriode:
            return UIRoute(tab: .uebersicht, kontext: .oeffneEinstellungen(section: .periode))
        case .wmzPlausi:
            return UIRoute(tab: .zaehler, kontext: .fokussiereMedium(roh: "waermeenergie"))
        }
    }
}

/// Zusammensetzung aus Ziel-Tab + optionalem Kontext. Der Kontext
/// beschreibt, was die Ziel-View tun soll, sobald der Tab aktiv
/// ist (Sheet öffnen, Section aufklappen, Item markieren).
struct UIRoute: Equatable, Hashable, Sendable {
    let tab: AppTabKey
    let kontext: Kontext?

    enum Kontext: Equatable, Hashable, Sendable {
        case oeffneEinstellungen(section: EinstellungenSection)
        case erfasseZaehler(id: UUID)
        case oeffneKostenart(id: UUID)
        case oeffneScanMitKostenart(id: UUID)
        case fokussiereMedium(roh: String)
    }

    enum EinstellungenSection: Equatable, Hashable, Sendable {
        case objekt
        case mieter(einheitId: String)
        case periode
    }
}

/// Tab-Kennung im Calc-Layer — verzichtet auf Import des UI-
/// `AppTab`-Enums, damit der Calc-Layer SwiftUI-frei bleibt.
/// Der Mapper in der UI (`AppShellRouter`) übersetzt zwischen
/// den beiden Enums.
enum AppTabKey: String, Equatable, Hashable, Sendable, CaseIterable {
    case uebersicht
    case zaehler
    case rechnungen
    case belege
    case abrechnungen
}
