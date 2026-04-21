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
//      NavigationStack { aktiver-Tab-Inhalt }
//      NebenkostenTabBar()
//    }
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
    @State private var zeigeEinstellungen = false

    private var aktiveTab: Binding<AppTab> {
        Binding(
            get: { router.aktiverTab },
            set: { router.aktiverTab = $0 }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            aktiverTabInhalt
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            NebenkostenTabBar(
                aktiverTab: aktiveTab,
                tabs: AppTab.allCases
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
        .sheet(isPresented: $zeigeEinstellungen) {
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
    /// Der „?"-Button in AppShellChrome setzt `router.zeigeInspektor =
    /// true`, das Sheet hier reagiert.
    private var inspektorBinding: Binding<Bool> {
        Binding(
            get: { router.zeigeInspektor },
            set: { router.zeigeInspektor = $0 }
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
            NavigationStack { UebersichtView() }
        case .zaehler:
            NavigationStack { ZaehlerView() }
        case .rechnungen:
            NavigationStack { RechnungenView() }
        case .belege:
            NavigationStack { BelegeView() }
        case .abrechnungen:
            NavigationStack { AbrechnungenView() }
        }
    }
}
