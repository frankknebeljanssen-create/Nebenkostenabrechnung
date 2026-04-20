//
//  AppFontSpecTests.swift
//  NebenkostenAppTests — CalcTests
//
//  Verifiziert, dass `AppFont.*`-Methoden zeilengenau die Werte aus
//  design_handoff/typografie-spec.html liefern. Jeder Test baut
//  einen Referenz-AppFontStyle mit den Spec-Werten und vergleicht
//  per `==` (AppFontStyle ist Equatable).
//

import Foundation
import Testing
import SwiftUI
@testable import NebenkostenApp

@MainActor
struct AppFontSpecTests {

    // MARK: - Helper

    /// Baut einen AppFontStyle mit Plex-Sans-Schnitt zum Vergleichen.
    private func sans(_ schnitt: AppFont.PlexSchnitt, _ size: CGFloat, tracking: CGFloat, uppercase: Bool) -> AppFontStyle {
        AppFontStyle(
            font: AppFont.plexSans(schnitt, size),
            tracking: tracking,
            uppercase: uppercase
        )
    }

    /// Baut einen AppFontStyle mit Plex-Mono-Schnitt zum Vergleichen.
    private func mono(_ schnitt: AppFont.PlexSchnitt, _ size: CGFloat, tracking: CGFloat, uppercase: Bool) -> AppFontStyle {
        AppFontStyle(
            font: AppFont.plexMono(schnitt, size),
            tracking: tracking,
            uppercase: uppercase
        )
    }

    // MARK: - Rechnungen-Screen

    @Test("Rechnungen.screenTitel = Plex Sans 30/600 tracking -0.6")
    func rechnungen_screenTitel() {
        #expect(AppFont.Rechnungen.screenTitel() == sans(.semibold, 30, tracking: -0.6, uppercase: false))
    }

    @Test("Rechnungen.subZeile = Plex Sans 13/400")
    func rechnungen_subZeile() {
        #expect(AppFont.Rechnungen.subZeile() == sans(.regular, 13, tracking: 0, uppercase: false))
    }

    @Test("Rechnungen.adresseBtn = Plex Sans 14/500")
    func rechnungen_adresseBtn() {
        #expect(AppFont.Rechnungen.adresseBtn() == sans(.medium, 14, tracking: 0, uppercase: false))
    }

    @Test("Rechnungen.scopeLabel = Plex Sans 12/500 tracking 0.2 UPPER")
    func rechnungen_scopeLabel() {
        #expect(AppFont.Rechnungen.scopeLabel() == sans(.medium, 12, tracking: 0.2, uppercase: true))
    }

    @Test("Rechnungen.scopeM2 = Plex Mono 11/400")
    func rechnungen_scopeM2() {
        #expect(AppFont.Rechnungen.scopeM2() == mono(.regular, 11, tracking: 0, uppercase: false))
    }

    @Test("Rechnungen.suchFeld = Plex Sans 14/400")
    func rechnungen_suchFeld() {
        #expect(AppFont.Rechnungen.suchFeld() == sans(.regular, 14, tracking: 0, uppercase: false))
    }

    @Test("Rechnungen.kostenartHeader = Plex Sans 12/600 tracking 0.5 UPPER")
    func rechnungen_kostenartHeader() {
        #expect(AppFont.Rechnungen.kostenartHeader() == sans(.semibold, 12, tracking: 0.5, uppercase: true))
    }

    @Test("Rechnungen.kostenartSumme = Plex Mono 12/600")
    func rechnungen_kostenartSumme() {
        #expect(AppFont.Rechnungen.kostenartSumme() == mono(.semibold, 12, tracking: 0, uppercase: false))
    }

    @Test("Rechnungen.issuer = Plex Sans 15/500")
    func rechnungen_issuer() {
        #expect(AppFont.Rechnungen.issuer() == sans(.medium, 15, tracking: 0, uppercase: false))
    }

    @Test("Rechnungen.betrag = Plex Mono 15/600")
    func rechnungen_betrag() {
        #expect(AppFont.Rechnungen.betrag() == mono(.semibold, 15, tracking: 0, uppercase: false))
    }

    @Test("Rechnungen.datumPeriode = Plex Mono 11/400")
    func rechnungen_datumPeriode() {
        #expect(AppFont.Rechnungen.datumPeriode() == mono(.regular, 11, tracking: 0, uppercase: false))
    }

    @Test("Rechnungen.statusPillText = Plex Sans 11/600 tracking 0.1")
    func rechnungen_statusPillText() {
        #expect(AppFont.Rechnungen.statusPillText() == sans(.semibold, 11, tracking: 0.1, uppercase: false))
    }

    @Test("Rechnungen.rechnungManuellHinzu = Plex Sans 14/500")
    func rechnungen_manuellHinzu() {
        #expect(AppFont.Rechnungen.rechnungManuellHinzu() == sans(.medium, 14, tracking: 0, uppercase: false))
    }

    // MARK: - Dashboard

    @Test("Dashboard.kpiWert = Plex Mono 19/600 tracking -0.3")
    func dashboard_kpiWert() {
        #expect(AppFont.Dashboard.kpiWert() == mono(.semibold, 19, tracking: -0.3, uppercase: false))
    }

    @Test("Dashboard.fortschrittProzent = Plex Mono 22/600")
    func dashboard_fortschritt() {
        #expect(AppFont.Dashboard.fortschrittProzent() == mono(.semibold, 22, tracking: 0, uppercase: false))
    }

    @Test("Dashboard.einheitVorauszahlung = Plex Mono 14/600")
    func dashboard_vorauszahlung() {
        #expect(AppFont.Dashboard.einheitVorauszahlung() == mono(.semibold, 14, tracking: 0, uppercase: false))
    }

    // MARK: - Zaehler

    @Test("Zaehler.standZahl = Plex Mono 14/600")
    func zaehler_standZahl() {
        #expect(AppFont.Zaehler.standZahl() == mono(.semibold, 14, tracking: 0, uppercase: false))
    }

    @Test("Zaehler.bezeichnung = Plex Sans 14/500")
    func zaehler_bezeichnung() {
        #expect(AppFont.Zaehler.bezeichnung() == sans(.medium, 14, tracking: 0, uppercase: false))
    }

    @Test("Zaehler.typ = Plex Sans 11/400")
    func zaehler_typ() {
        #expect(AppFont.Zaehler.typ() == sans(.regular, 11, tracking: 0, uppercase: false))
    }

    @Test("Zaehler.messwertLabel = Plex Sans 10/400 tracking 0.3 UPPER")
    func zaehler_messwertLabel() {
        #expect(AppFont.Zaehler.messwertLabel() == sans(.regular, 10, tracking: 0.3, uppercase: true))
    }

    @Test("Zaehler.einheitChip = Plex Sans 10/600 tracking 0.3 UPPER")
    func zaehler_einheitChip() {
        #expect(AppFont.Zaehler.einheitChip() == sans(.semibold, 10, tracking: 0.3, uppercase: true))
    }

    // MARK: - Abrechnung

    @Test("Abrechnung.kopfName = Plex Sans 17/600")
    func abrechnung_kopfName() {
        #expect(AppFont.Abrechnung.kopfName() == sans(.semibold, 17, tracking: 0, uppercase: false))
    }

    @Test("Abrechnung.ergebnisBetrag = Plex Mono 24/600")
    func abrechnung_ergebnisBetrag() {
        #expect(AppFont.Abrechnung.ergebnisBetrag() == mono(.semibold, 24, tracking: 0, uppercase: false))
    }

    @Test("Abrechnung.positionBetrag = Plex Mono 13/600")
    func abrechnung_positionBetrag() {
        #expect(AppFont.Abrechnung.positionBetrag() == mono(.semibold, 13, tracking: 0, uppercase: false))
    }

    // MARK: - Dokumente

    @Test("Dokumente.ocrVolltext = Plex Mono 10.5/400 (fractional)")
    func dokumente_ocrVolltext() {
        #expect(AppFont.Dokumente.ocrVolltext() == mono(.regular, 10.5, tracking: 0, uppercase: false))
    }

    @Test("Dokumente.ebeneLabel = Plex Sans 12/600 tracking 0.4 UPPER")
    func dokumente_ebeneLabel() {
        #expect(AppFont.Dokumente.ebeneLabel() == sans(.semibold, 12, tracking: 0.4, uppercase: true))
    }

    // MARK: - Chrome

    @Test("Chrome.tabBarLabel = Plex Sans 9.5/500 (fractional)")
    func chrome_tabBarLabel() {
        #expect(AppFont.Chrome.tabBarLabel() == sans(.medium, 9.5, tracking: 0, uppercase: false))
    }

    @Test("Chrome.scopeStreifen = Plex Sans 12/500 tracking 0.2 UPPER")
    func chrome_scopeStreifen() {
        #expect(AppFont.Chrome.scopeStreifen() == sans(.medium, 12, tracking: 0.2, uppercase: true))
    }

    @Test("Chrome.statusPill = Plex Sans 11/600 tracking 0.1")
    func chrome_statusPill() {
        #expect(AppFont.Chrome.statusPill() == sans(.semibold, 11, tracking: 0.1, uppercase: false))
    }

    // MARK: - Plex-Mono-Bold-Verbot (Teil 3a)

    @Test("PlexSchnitt hat keinen Bold-Case (weight 700 verboten auf Mono)")
    func plexSchnitt_kein_bold() {
        let rawWerte = [AppFont.PlexSchnitt.regular.rawValue,
                        AppFont.PlexSchnitt.medium.rawValue,
                        AppFont.PlexSchnitt.semibold.rawValue]
        #expect(rawWerte == ["Regular", "Medium", "SemiBold"])
        #expect(!rawWerte.contains("Bold"))
    }

    // MARK: - Legacy-Aliases zeigen Spec-Werte

    @Test("Legacy navAddress zeigt jetzt 14/500 (nicht mehr 17/500)")
    func legacy_navAddress_spec_konform() {
        #expect(AppFont.navAddress() == sans(.medium, 14, tracking: 0, uppercase: false))
    }

    @Test("Legacy monoBetrag17 zeigt jetzt Mono 15/600 (nicht mehr 17/600)")
    func legacy_monoBetrag17_spec_konform() {
        #expect(AppFont.monoBetrag17() == mono(.semibold, 15, tracking: 0, uppercase: false))
    }

    @Test("Legacy monoMesswert zeigt jetzt Mono 14/600 (nicht mehr 18/600)")
    func legacy_monoMesswert_spec_konform() {
        #expect(AppFont.monoMesswert() == mono(.semibold, 14, tracking: 0, uppercase: false))
    }

    @Test("Legacy captionSemi zeigt jetzt 11/600 tracking 0.1 (StatusPill)")
    func legacy_captionSemi_spec_konform() {
        #expect(AppFont.captionSemi() == sans(.semibold, 11, tracking: 0.1, uppercase: false))
    }
}
