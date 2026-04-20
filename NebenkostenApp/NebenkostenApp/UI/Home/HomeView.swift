//
//  HomeView.swift
//  NebenkostenApp — UI/Home
//
//  Context-First-Einstieg des Übersicht-Tabs. Vertikale Abfolge:
//    1. HomeHeaderView   — Begrüßung + Perioden-Info
//    2. CurrentPropertyCard  — aktuelles Objekt, Wechseln-Action
//    3. CurrentUnitCard  — aktuelle Einheit, Wechseln-Action
//    4. HomeStatusCard   — kompakt (Zähler / Rechnungen / Docs) +
//                          „Nächster Schritt" mit Router-Sprung
//    5. EmptyStateCard   — nur, wenn keine Immobilie im Store
//
//  Komposition bewusst einfach: kein Dashboard, keine Grid-Layouts,
//  keine animierten Prozent-Ringe. Ruhige Typografie, viel Padding.
//
//  Persistenz: die Auswahl des Scope (Objekt vs. Einheit) lebt im
//  ScopeManager (UserDefaults „currentScope.v1"). Die aktive
//  Immobilie ergibt sich aus dem SwiftData-Store (MVP: genau eine).
//  Das zweite aktive Wahl-Feld wird automatisch beim nächsten App-
//  Start wiederhergestellt.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(ScopeManager.self) private var scope
    @Environment(AppShellRouter.self) private var router
    @Query(sort: \Immobilie.erstelltAm) private var immobilien: [Immobilie]

    @State private var zeigeScopePicker = false
    @State private var zeigeEinstellungen = false
    @State private var zeigeObjektWechsel = false

    private var immobilie: Immobilie? { immobilien.first }

    private var aktivePeriode: Abrechnungsperiode? {
        let perioden = (immobilie?.perioden ?? []).sorted(by: { $0.bis > $1.bis })
        let heute = Date()
        return perioden.first(where: { $0.bis < heute }) ?? perioden.first
    }

    private var anforderungen: [AnforderungMitStatus] {
        guard let immobilie, let p = aktivePeriode else { return [] }
        return VollstaendigkeitsPruefung.pruefe(immobilie: immobilie, periode: p)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HomeHeaderView(
                    immobilieBekannt: immobilie != nil,
                    periodenLabel: periodenLabel
                )
                if let immobilie {
                    CurrentPropertyCard(
                        immobilie: immobilie,
                        onWechsel: { zeigeObjektWechsel = true }
                    )
                    CurrentUnitCard(
                        scope: scope.current,
                        immobilie: immobilie,
                        onWechsel: { zeigeScopePicker = true }
                    )
                    HomeStatusCard(
                        anforderungen: anforderungen,
                        immobilie: immobilie,
                        periode: aktivePeriode,
                        onSprung: { ziel in
                            router.springe(zu: ziel)
                        }
                    )
                } else {
                    EmptyStateCard(onPrimaerAktion: {
                        zeigeEinstellungen = true
                    })
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .background(DesignTokens.bgApp)
        .appShellChrome(
            titel: "Start",
            subtitel: nil,
            onAdresse: { zeigeScopePicker = true },
            onEinstellungen: { zeigeEinstellungen = true }
        )
        .sheet(isPresented: $zeigeScopePicker) { ScopePickerSheet() }
        .sheet(isPresented: $zeigeEinstellungen) { EinstellungenSheet() }
        .sheet(isPresented: $zeigeObjektWechsel) {
            // Solange nur ein Objekt im MVP existiert, führt „Objekt
            // wechseln" zur Einstellungs-Section. Sobald mehrere
            // Objekte gleichzeitig unterstützt werden, übernimmt hier
            // ein dedizierter Picker.
            EinstellungenSheet()
        }
        .onChange(of: router.aktuellesSprungziel) { _, neu in
            reagiereAufSprungziel(neu)
        }
    }

    // MARK: - Header-Info

    private var periodenLabel: String? {
        guard let p = aktivePeriode else { return nil }
        let jahr = Calendar(identifier: .gregorian).component(.year, from: p.bis)
        return "Abrechnungsperiode \(jahr)"
    }

    // MARK: - Sprungziel-Reaktion

    /// Der HomeView ist der Ziel-Tab für Stammdaten-/VZ-Sprungziele.
    /// Bei Ankunft eines solchen Sprungziels öffnen wir das
    /// Einstellungen-Sheet — die konkrete Section wird später durch
    /// scroll-anchors markiert (aktuell alle Sections sichtbar).
    private func reagiereAufSprungziel(_ ziel: Sprungziel?) {
        switch ziel {
        case .einstellungenObjekt,
             .einstellungenPeriode,
             .mieterVorauszahlung:
            zeigeEinstellungen = true
            router.quittiere()
        default:
            break
        }
    }
}
