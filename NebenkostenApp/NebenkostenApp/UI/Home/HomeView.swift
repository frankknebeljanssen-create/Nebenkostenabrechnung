//
//  HomeView.swift
//  NebenkostenApp — UI/Home
//
//  Context-First-Einstieg, v2 nach Geräte-Review. Änderungen
//  gegenüber v1:
//    - „Willkommen zurück." und „Start" entfallen.
//    - AppShellChrome-Titel = nil (kein 30pt-Block oberhalb).
//    - PeriodenHeader (40 pt) ist die neue Hauptorientierung.
//    - ObjektCarousel ersetzt die statische CurrentPropertyCard:
//      horizontal swipebar, eigene Paging-Dots, Tap öffnet Objekt.
//    - Cards nutzen Card.Tiefe.erhoben — klarer Kontrast zum bgApp.
//
//  Die CurrentUnitCard und die HomeStatusCard bleiben aus v1
//  erhalten, bekommen aber die neue Tiefe-Option.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(ScopeManager.self) private var scope
    @Environment(AppShellRouter.self) private var router
    @Query(sort: \Immobilie.erstelltAm) private var immobilien: [Immobilie]

    @State private var zeigeScopePicker = false
    @State private var zeigeEinstellungen = false
    @State private var carouselIndex: Int = 0

    /// Die im Carousel aktuell sichtbare Immobilie. Fallback auf
    /// die erste, wenn der Index außerhalb des Bereichs liegt
    /// (z.B. nach Löschung einer Immobilie).
    private var aktiveImmobilie: Immobilie? {
        guard !immobilien.isEmpty else { return nil }
        let idx = max(0, min(carouselIndex, immobilien.count - 1))
        return immobilien[idx]
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
            VStack(alignment: .leading, spacing: 24) {
                if immobilien.isEmpty {
                    kopfLeer
                    EmptyStateCard(onPrimaerAktion: {
                        zeigeEinstellungen = true
                    })
                } else {
                    kopfMitPeriode
                    ObjektCarousel(
                        immobilien: immobilien,
                        aktuellerIndex: $carouselIndex,
                        onOeffnen: oeffneObjekt
                    )
                    if let immobilie = aktiveImmobilie {
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
                            periode: aktivePeriode,
                            onSprung: { ziel in
                                router.springe(zu: ziel)
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(DesignTokens.bgApp)
        .appShellChrome(
            titel: nil,                       // kein "Start"
            subtitel: nil,
            onAdresse: { zeigeScopePicker = true },
            onEinstellungen: { zeigeEinstellungen = true }
        )
        .sheet(isPresented: $zeigeScopePicker) { ScopePickerSheet() }
        .sheet(isPresented: $zeigeEinstellungen) { EinstellungenSheet() }
        .onChange(of: router.aktuellesSprungziel) { _, neu in
            reagiereAufSprungziel(neu)
        }
    }

    // MARK: - Kopfzonen

    /// Kopfzone mit voll ausgebauter Perioden-Überschrift
    /// (40 pt/600). Nur sichtbar, wenn mindestens eine Immobilie
    /// existiert — sonst macht der Perioden-Header keinen Sinn.
    private var kopfMitPeriode: some View {
        PeriodenHeader(periode: aktivePeriode)
            .padding(.horizontal, 4)
    }

    /// Fallback-Kopf, wenn der Store noch leer ist. Minimal, damit
    /// die EmptyStateCard selbst die Hauptbühne bleibt.
    private var kopfLeer: some View {
        Text("Willkommen")
            .appFont(AppFont.Basis.periodenHeader())
            .foregroundStyle(DesignTokens.text)
            .padding(.horizontal, 4)
    }

    // MARK: - Tap auf eine Carousel-Card

    /// Aktive Objekt-Card angetippt → in das Objekt hinein. Im
    /// MVP: Scope auf Objekt setzen + EinstellungenSheet (dort
    /// sind aktuell die Objekt-Details). Sobald ein dediziertes
    /// Objekt-Detail existiert, landet der User dort.
    private func oeffneObjekt(_ immobilie: Immobilie) {
        scope.current = .objekt
        zeigeEinstellungen = true
    }

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
