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
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Immobilie.erstelltAm) private var immobilien: [Immobilie]

    @State private var zeigeScopePicker = false

    /// Zeigt den globalen Scan-FAB-Flow: erst `ScanEntryView` (Kamera/
    /// Mediathek/Datei), danach `UniversellerAnalyseScreen` ueber das
    /// `analyseSheet`-Binding auf dem Router. Flag nur lokal — der
    /// Folge-Screen lebt im Router, damit er auch aus anderen Kontexten
    /// adressierbar bleibt.
    @State private var zeigeScanEinwurf = false
    /// Zwischen-State zwischen ScanEntryView-Dismiss und Analyse-Sheet-
    /// Praesentation. Ohne den Wert koennen die beiden Sheets nicht
    /// sauber aneinander geketted werden — SwiftUI erlaubt nur ein
    /// aktives Sheet pro Presenter, der `onDismiss`-Callback des
    /// ersten Sheets triggert dann das zweite.
    @State private var pendingAnalyseDokumentID: UUID?

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
        shellStack
            .overlay(alignment: .topTrailing) { scanFAB }
    }

    /// Globaler Scan-FAB — 56 pt Kreis, accent-farben. Sitzt rechts
    /// unter dem Header (`.topTrailing`) mit Padding, statt wie vorher
    /// unten rechts ueber der TabBar. So ist er besser erreichbar und
    /// kollidiert nicht mehr optisch mit Bottom-CTAs der Kachel-Screens.
    private var scanFAB: some View {
        Button { zeigeScanEinwurf = true } label: {
            Image(systemName: "doc.viewfinder.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(DesignTokens.accent))
                .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 16)
        .padding(.top, 140)  // unter KontextHeader (inkl. SafeArea)
        .accessibilityLabel("Dokument scannen")
    }

    private var shellStack: some View {
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
                onReTap: { tab in leerePfad(fuer: tab) },
                pathUebersichtLeer: pathUebersicht.isEmpty
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
        .sheet(item: zaehlerErfassenBinding) { kontext in
            if let z = findeZaehler(id: kontext.zaehlerID) {
                ZaehlerstandErfassenView(zaehler: z)
            }
        }
        .sheet(
            isPresented: $zeigeScanEinwurf,
            onDismiss: {
                // Wird gerufen, nachdem ScanEntryView komplett
                // dismisst ist. Jetzt — und erst jetzt — koennen
                // wir den Analyse-Screen sauber aufpoppen lassen.
                if let id = pendingAnalyseDokumentID {
                    router.oeffneAnalyseSheet(dokumentID: id)
                    pendingAnalyseDokumentID = nil
                }
            }
        ) {
            // direktUebergeben=true: ScanEntryView ueberspringt den
            // alten `DokumentErfassungView`-Picker und ruft sofort
            // unseren `onFertig`-Callback — der Universeller-Analyse-
            // Screen uebernimmt die Typ-Bestimmung.
            ScanEntryView(direktUebergeben: true) { dokument in
                pendingAnalyseDokumentID = dokument.id
            }
        }
        .sheet(item: analyseBinding) { kontext in
            if let dok = findeDokument(id: kontext.dokumentID) {
                UniversellerAnalyseScreen(dokument: dok)
            }
        }
    }

    /// Bindings-Adapter auf `router.analyseSheet`. Schliesst den
    /// Router-State beim User-Dismiss, damit das Sheet nicht bei
    /// jedem Re-Render erneut aufschwebt.
    private var analyseBinding: Binding<ScanAnalyseSheetKontext?> {
        Binding(
            get: { router.analyseSheet },
            set: { router.analyseSheet = $0 }
        )
    }

    /// Dokument via UUID im @Query finden. Haengt entweder an einer
    /// Immobilie (Stammdaten-Dokument) oder an einer Rechnung oder
    /// ist noch unverknuepft — je nach Scan-Quelle. Wir filtern
    /// daher NICHT nach aktiver Immobilie.
    @MainActor
    private func findeDokument(id: UUID) -> GespeichertesDokument? {
        for immobilie in immobilien {
            if let d = (immobilie.stammdatenDokumente ?? [])
                .first(where: { $0.id == id }) {
                return d
            }
        }
        // Fallback: ModelContext-FetchDescriptor ueber alle Dokumente.
        // Nicht-verknuepfte frische Scans liegen nur im Kontext.
        let desc = FetchDescriptor<GespeichertesDokument>(
            predicate: #Predicate { $0.id == id }
        )
        return (try? modelContext.fetch(desc))?.first
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

    /// Bindings-Adapter auf `router.zaehlerErfassenSheet`. Schliesst
    /// den Router-State beim User-Dismiss wieder — ohne das Binding
    /// wuerde das Sheet bei jedem Re-Render erneut auftauchen.
    private var zaehlerErfassenBinding: Binding<ZaehlerErfassenSheetKontext?> {
        Binding(
            get: { router.zaehlerErfassenSheet },
            set: { router.zaehlerErfassenSheet = $0 }
        )
    }

    /// Haupt- und Wohnungszaehler der aktiven Immobilie nach UUID
    /// suchen. Der Router haelt nur die UUID, damit er SwiftData-
    /// frei bleibt — die Aufloesung passiert hier in der View-Schicht.
    private func findeZaehler(id: UUID) -> Zaehler? {
        for immobilie in immobilien {
            if let z = (immobilie.hauptzaehler ?? []).first(where: { $0.id == id }) {
                return z
            }
            for einheit in immobilie.wohneinheiten ?? [] {
                if let z = (einheit.zaehler ?? []).first(where: { $0.id == id }) {
                    return z
                }
            }
        }
        return nil
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
            NavigationStack(path: $pathUebersicht) {
                UebersichtView()
                    .navigationDestination(for: HomeDestination.self) { dest in
                        homeDestinationView(dest)
                    }
            }
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

    /// Zentrale Destination-Fabrik fuer den Home-Tab. Alle typed
    /// `NavigationLink(value:)`-Pushes innerhalb von HomeView und
    /// KachelansichtView landen hier.
    @ViewBuilder
    private func homeDestinationView(_ dest: HomeDestination) -> some View {
        switch dest {
        case .kachelansicht:      KachelansichtView()
        case .stammdaten:         StammdatenView()
        case .zaehlerstaende:     ZaehlerstaendeView()
        case .dokumenteRechnungen: DokumenteRechnungenView()
        case .abrechnungsKachel:  AbrechnungsKachelView()
        }
    }

    /// Pop-to-Root fuer den uebergebenen Tab. Wird vom Re-Tap-Callback
    /// der `NebenkostenTabBar` aufgerufen. Diagnose-Print laesst den
    /// User im Dev-Build verifizieren, dass Pfade tatsaechlich geleert
    /// werden — der frueher benutzte value-less `NavigationLink` lief
    /// am Pfad vorbei, wodurch der Reset silent nichts tat.
    private func leerePfad(fuer tab: AppTab) {
        print("🔵 leerePfad fuer \(tab.rawValue)")
        switch tab {
        case .uebersicht:
            print("   ↳ pathUebersicht.count vorher=\(pathUebersicht.count)")
            pathUebersicht = NavigationPath()
        case .zaehler:      pathZaehler      = NavigationPath()
        case .rechnungen:   pathRechnungen   = NavigationPath()
        case .belege:       pathBelege       = NavigationPath()
        case .abrechnungen: pathAbrechnungen = NavigationPath()
        }
    }
}
