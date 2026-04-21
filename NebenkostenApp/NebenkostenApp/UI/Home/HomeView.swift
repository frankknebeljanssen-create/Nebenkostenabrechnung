//
//  HomeView.swift
//  NebenkostenApp — UI/Home
//
//  Context-First-Einstieg. Nach Home-Refactor (Layout-Pass) eine
//  schlanke Kartenleiste:
//    1. WohneinheitCarousel — horizontales Paging zwischen
//       Gesamt-Objekt und einzelner Einheit.
//    2. HomeStatusCard     — Kennzahlen + Periodenzustand-Pill.
//    3. NaechsterSchrittCard — Liste offener Punkte oder
//       Final-CTA „Abrechnungsdokumente erstellen".
//
//  Das ObjektCarousel ist entfallen, weil die Objekt-Selektion
//  jetzt im permanenten KontextHeader lebt. Kein Redundanz-
//  Zustand mehr zwischen Header und Home.
//
//  Alle Cards haben identische Breite (ScrollView-Padding 16 pt
//  links/rechts, keine zusaetzlichen horizontalen Paddings in den
//  Cards selbst). Vertikales Spacing: einheitlich 12 pt.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(ScopeManager.self) private var scope
    @Environment(AppShellRouter.self) private var router
    @Query(sort: \Immobilie.erstelltAm) private var immobilien: [Immobilie]

    @State private var zeigeScopePicker = false
    @State private var zeigeEinstellungen = false

    /// Aktuell angezeigte Immobilie — aus dem persistierten
    /// ScopeManager-Kontext, Fallback auf die erste verfuegbare.
    private var aktiveImmobilie: Immobilie? {
        guard !immobilien.isEmpty else { return nil }
        if let id = scope.aktuelleImmobilieID,
           let treffer = immobilien.first(where: { $0.id == id }) {
            return treffer
        }
        return immobilien.first
    }

    private var aktivePeriode: Abrechnungsperiode? {
        let perioden = (aktiveImmobilie?.perioden ?? []).sorted(by: { $0.bis > $1.bis })
        let heute = Date()
        return perioden.first(where: { $0.bis < heute }) ?? perioden.first
    }

    private var anforderungen: [AnforderungMitStatus] {
        guard let immobilie = aktiveImmobilie, let p = aktivePeriode else { return [] }
        return VollstaendigkeitsPruefung.pruefe(immobilie: immobilie, periode: p)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if immobilien.isEmpty {
                    kopfLeer
                    EmptyStateCard(onPrimaerAktion: {
                        zeigeEinstellungen = true
                    })
                } else if let immobilie = aktiveImmobilie {
                    WohneinheitCarousel(
                        immobilie: immobilie,
                        scope: Binding(
                            get: { scope.current },
                            set: { scope.current = $0 }
                        ),
                        onOeffnen: oeffneEinheit
                    )
                    HomeStatusCard(
                        anforderungen: anforderungen,
                        immobilie: immobilie,
                        periode: aktivePeriode
                    )
                    NaechsterSchrittCard(
                        anforderungen: anforderungen,
                        onSprung: { ziel in
                            router.springe(zu: ziel)
                        },
                        onFinalAktion: {
                            router.aktiverTab = .abrechnungen
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(DesignTokens.bgApp)
        .appShellChrome(
            titel: nil,                       // kein "Start"
            subtitel: nil,
            onAdresse: { zeigeScopePicker = true },
            onEinstellungen: { zeigeEinstellungen = true },
            zeigeAdresseOben: false,          // Adresse lebt in der Carousel-Card
            zeigeScopeStrip: false            // Scope lebt im WohneinheitCarousel
        )
        .sheet(isPresented: $zeigeScopePicker) { ScopePickerSheet() }
        .sheet(isPresented: $zeigeEinstellungen) { EinstellungenSheet() }
        .onChange(of: router.aktuellesSprungziel) { _, neu in
            reagiereAufSprungziel(neu)
        }
    }

    // MARK: - Kopfzone (Leer-State)

    /// Kopf fuer den leeren Store. Die Perioden-Ueberschrift lebt
    /// jetzt komplett im KontextHeader oben — hier reicht ein
    /// schlichtes "Willkommen".
    private var kopfLeer: some View {
        Text("Willkommen")
            .appFont(AppFont.Basis.periodenHeader())
            .foregroundStyle(DesignTokens.text)
            .padding(.horizontal, 4)
    }

    // MARK: - Tap auf eine Wohneinheit-Card

    /// Aktive Wohneinheit-Card angetippt → Scope wurde durch
    /// Swipen schon aktualisiert, Tap öffnet die
    /// Einstellungen-Section (als aktuelles Einheit-Detail-Ziel).
    private func oeffneEinheit(_ scopeAuswahl: AppScope) {
        scope.current = scopeAuswahl
        zeigeEinstellungen = true
    }

    // MARK: - Sprungziel-Reaktion

    private func reagiereAufSprungziel(_ ziel: Sprungziel?) {
        switch ziel {
        case .mieterVorauszahlung(let einheitId):
            // Direkt ins VorauszahlungEingabeSheet — nicht mehr
            // ueber das EinstellungenSheet, wo die VZ-Zeilen
            // ohnehin nicht editierbar sind.
            router.oeffneVorauszahlungSheet(einheitID: einheitId)
            router.quittiere()
        case .einstellungenObjekt,
             .einstellungenPeriode:
            zeigeEinstellungen = true
            router.quittiere()
        default:
            break
        }
    }
}
