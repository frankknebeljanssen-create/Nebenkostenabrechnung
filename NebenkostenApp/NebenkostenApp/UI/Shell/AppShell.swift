//
//  AppShell.swift
//  NebenkostenApp — UI/Shell
//
//  Root-Shell mit fuenf Haupt-Tabs und eigener `NebenkostenTabBar`.
//  Der Umstieg von SwiftUI's `TabView` auf die Custom-Bar erfolgte,
//  weil iOS 26's neue Floating-TabBar eine ca. 145 pt hohe
//  Reserve-Zone belegt und `systemBackgroundColor` durchleuchten
//  laesst — fuer unsere Light-only-Warmton-Palette ein Problem,
//  das ohne Private-API nicht sauber zu loesen war.
//
//  Aufbau:
//    VStack {
//      KontextHeader()                               // persistent, global
//      NavigationStack { aktiver-Tab-Inhalt }
//      NebenkostenTabBar()
//    }
//
//  KontextHeader lebt direkt im AppShell — AUSSERHALB der
//  NavigationStacks. So bleibt er auf allen Push-Destinations
//  (StammdatenView, Detail-Sheets, Kachel-Screens) sichtbar.
//  Frueher sass er im `appShellChrome`-Modifier als
//  `safeAreaInset(.top)` auf Tab-Root-Ebene — das wurde beim Push
//  nicht vererbt, und tiefere Screens verloren den Header.
//
//  Tab-Wechsel laeuft ueber `AppShellRouter.aktiverTab` —
//  unveraendert gegenueber der frueheren TabView-Loesung.
//  Tab-Wechsel verwirft NavigationStack-State des vorher aktiven
//  Tabs (Switch erzeugt neue View-Instanz). Die Tab-Views lesen
//  ihre State aus SwiftData / ScopeManager ohnehin frisch, also
//  kein Daten-Verlust.
//

import SwiftUI
import SwiftData

struct AppShell: View {
    @Environment(ScopeManager.self) private var scope
    @Environment(AppShellRouter.self) private var router
    @Query(sort: \Immobilie.erstelltAm) private var immobilien: [Immobilie]

    @State private var zeigeScopePicker = false

    // Pro Tab ein eigener NavigationPath — wird vom `NavigationStack`
    // gehalten. Bei Re-Tap auf den aktiven Tab leeren wir den
    // zugehoerigen Pfad → Pop-to-Root (iOS-Standardverhalten). Ohne
    // diese Paths blieb der Tap auf den aktiven Tab wirkungslos
    // (z.B. Home → Kachelansicht gepusht → Home-Tab-Tap = nichts).
    @State private var pathUebersicht = NavigationPath()
    @State private var pathZaehler = NavigationPath()
    @State private var pathRechnungen = NavigationPath()
    @State private var pathBelege = NavigationPath()
    @State private var pathAbrechnungen = NavigationPath()

    private var aktiveTab: Binding<AppTab> {
        Binding(
            get: { router.aktiverTab },
            set: { router.aktiverTab = $0 }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Permanenter Kontext-Header: Objekt / Periode /
            // Wohneinheit-Pills. Sitzt AUSSERHALB der NavigationStacks,
            // damit er bei jedem Push (StammdatenView, Detail-Sheets,
            // Kachel-Screens) mitlaeuft. Der Header kapselt sein
            // eigenes `.ignoresSafeArea(.container, edges: .top)` auf
            // dem Hintergrund — das Braun zieht bis unter die Notch
            // durch.
            KontextHeader()
            aktiverTabInhalt
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            NebenkostenTabBar(
                aktiverTab: aktiveTab,
                tabs: AppTab.allCases,
                onReTap: { tab in leerePfad(fuer: tab) }
            )
        }
        .background(DesignTokens.bgApp.ignoresSafeArea())
        .tint(DesignTokens.accent)
        .dynamicTypeSize(.large ... .xLarge)
        .sheet(isPresented: $zeigeScopePicker) {
            ScopePickerSheet()
        }
        .sheet(isPresented: inspektorBinding) {
            InspektorSheet()
        }
        .sheet(isPresented: einstellungenBinding) {
            EinstellungenSheet()
        }
        .sheet(item: vorauszahlungBinding) { kontext in
            if let immo = aktuelleImmobilie {
                VorauszahlungEingabeSheet(
                    immobilie: immo,
                    fokusEinheitID: kontext.einheitID
                )
            }
        }
    }

    // MARK: - Bindings

    /// Bindings-Adapter auf `router.vorauszahlungSheet` — damit
    /// `.sheet(item:)` beim User-Dismiss den Router-State auf
    /// nil setzt (sonst feuert das Sheet beim naechsten Re-Render
    /// erneut).
    private var vorauszahlungBinding: Binding<VorauszahlungSheetKontext?> {
        Binding(
            get: { router.vorauszahlungSheet },
            set: { router.vorauszahlungSheet = $0 }
        )
    }

    /// Binding auf `router.zeigeInspektor` fuer `.sheet(isPresented:)`.
    /// Der „?"-Button im KontextHeader setzt `router.zeigeInspektor =
    /// true`, das Sheet hier reagiert.
    private var inspektorBinding: Binding<Bool> {
        Binding(
            get: { router.zeigeInspektor },
            set: { router.zeigeInspektor = $0 }
        )
    }

    /// Binding auf `router.zeigeEinstellungen` fuer `.sheet
    /// (isPresented:)`. Der Zahnrad-Button im KontextHeader setzt
    /// das Flag, das Sheet hier reagiert. Loest das frueher tab-
    /// lokale `@State zeigeEinstellungen` ab.
    private var einstellungenBinding: Binding<Bool> {
        Binding(
            get: { router.zeigeEinstellungen },
            set: { router.zeigeEinstellungen = $0 }
        )
    }

    private var aktuelleImmobilie: Immobilie? {
        if let id = scope.aktuelleImmobilieID,
           let treffer = immobilien.first(where: { $0.id == id }) {
            return treffer
        }
        return immobilien.first
    }

    // MARK: - Tab-Content

    /// Einen NavigationStack pro Tab. `@ViewBuilder` + `switch`
    /// sorgt dafuer, dass nur der aktive Tab gerendert wird — beim
    /// Wechsel wird der alte Tab-Stack verworfen.
    @ViewBuilder
    private var aktiverTabInhalt: some View {
        switch router.aktiverTab {
        case .uebersicht:
            NavigationStack(path: $pathUebersicht) { UebersichtView() }
        case .zaehler:
            NavigationStack(path: $pathZaehler) { ZaehlerView() }
        case .rechnungen:
            NavigationStack(path: $pathRechnungen) { RechnungenView() }
        case .belege:
            NavigationStack(path: $pathBelege) { BelegeView() }
        case .abrechnungen:
            NavigationStack(path: $pathAbrechnungen) { AbrechnungenView() }
        }
    }

    /// Pop-to-Root fuer den uebergebenen Tab. Wird vom Re-Tap-Callback
    /// der `NebenkostenTabBar` aufgerufen.
    private func leerePfad(fuer tab: AppTab) {
        switch tab {
        case .uebersicht:   pathUebersicht   = NavigationPath()
        case .zaehler:      pathZaehler      = NavigationPath()
        case .rechnungen:   pathRechnungen   = NavigationPath()
        case .belege:       pathBelege       = NavigationPath()
        case .abrechnungen: pathAbrechnungen = NavigationPath()
        }
    }
}
