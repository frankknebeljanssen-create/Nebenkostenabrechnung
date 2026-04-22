//
//  NebenkostenTabBar.swift
//  NebenkostenApp — UI/Shell
//
//  Custom Tab-Bar als Ersatz fuer SwiftUI's `TabView`. Hintergrund:
//  iOS 26's neuer Floating-TabBar reserviert vertikal ~145 pt
//  (83 pt Container + 62 pt Pill), faerbt die Reserve-Zone in
//  `systemBackgroundColor` und laesst Scroll-Content nicht sauber
//  bis an die Pill heranreichen. Fuer unsere Light-only-App mit
//  festem Warmton-Design gibt es damit entweder einen weissen
//  Streifen oder — vor dem Light-Mode-Fix — einen schwarzen.
//
//  Diese Bar ist eine simple Pill-HStack mit 5 Buttons.
//  Vollstaendig unter unserer Kontrolle, kein iOS-Reserve-Bereich,
//  kein systemBackgroundColor-Risiko. Hoehe inkl. Padding +
//  SafeArea-bottom: ca. 70–90 pt — rund halb so viel wie die
//  native iOS-26-TabBar.
//
//  State-Quelle: `AppShellRouter.aktiverTab` (schon vorhanden).
//

import SwiftUI

struct NebenkostenTabBar: View {
    @Binding var aktiverTab: AppTab
    let tabs: [AppTab]
    /// Wird ausgeloest, wenn der User auf den BEREITS aktiven Tab
    /// tippt. Konsumenten nutzen das fuer Pop-to-Root (iOS-Standard-
    /// Verhalten). Optional — wenn nicht gesetzt, passiert bei Re-Tap
    /// nichts, wie vor dem Fix.
    var onReTap: ((AppTab) -> Void)? = nil
    /// Ist der Home-NavigationPath leer? Nur dann gilt der Home-Tab
    /// auch visuell als „aktiv" (accent + weiss). Sobald der User
    /// tiefer gepusht hat (Kachelansicht, StammdatenView etc.), wird
    /// die Home-Pill grau — deutlicher Hinweis „Du bist nicht mehr
    /// auf Home, Tab-Tap bringt Dich zurueck". Default `true`, damit
    /// Aufrufer, die den Pfad nicht wissen, den alten Default haben.
    var pathUebersichtLeer: Bool = true

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs) { tab in
                // `aktiv` einmal pro Loop-Iteration explizit berechnen
                // und an die Sub-Funktionen durchreichen. Frueher sass
                // die Berechnung im `@ViewBuilder`-Body von `tabZelle`
                // und las `aktiverTab` aus dem enclosing Scope — das
                // fuehrte (nachweislich auf iOS 26) in seltenen
                // Re-Render-Faellen zu einem stale `aktiv`-Flag,
                // bei dem die Selected-Pill auf Home kleben blieb,
                // obwohl der Content-Tab wechselte.
                let aktiv = berechneAktiv(tab)
                tabButton(tab: tab, aktiv: aktiv)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background {
            Capsule(style: .continuous)
                .fill(DesignTokens.bgHeaderFooter)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(DesignTokens.separatorStrong, lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    /// Selected-State-Regel:
    /// - Home-Tab ist nur dann aktiv, wenn `aktiverTab == .uebersicht`
    ///   UND der NavigationPath leer ist. Push in Kachelansicht etc.
    ///   → Pill wird grau. Tap auf die graue Pill bringt zurueck.
    /// - Alle anderen Tabs: klassisch `aktiverTab == tab`.
    private func berechneAktiv(_ tab: AppTab) -> Bool {
        if tab == .uebersicht {
            return aktiverTab == .uebersicht && pathUebersichtLeer
        }
        return aktiverTab == tab
    }

    private func wechsle(zu tab: AppTab) {
        // Bei Home: auch wenn wir (logisch) bereits auf `.uebersicht`
        // sind, aber tief gepusht haben, wollen wir den Re-Tap-Pfad
        // — sonst muesste der User warten bis `aktiverTab` sich
        // selbst wieder gleich setzt, was es nicht tut. Die
        // Pop-to-Root-Logik sitzt im `onReTap`-Callback und leert den
        // Pfad. Der visuelle Unterschied (Pill wird von grau zu
        // accent) passiert automatisch, weil `pathUebersichtLeer`
        // danach wieder true wird.
        if aktiverTab == tab {
            onReTap?(tab)
            return
        }
        aktiverTab = tab
    }

    private func tabButton(tab: AppTab, aktiv: Bool) -> some View {
        Button {
            wechsle(zu: tab)
        } label: {
            tabZelleInhalt(tab: tab, aktiv: aktiv)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.titel)
        .accessibilityAddTraits(aktiv ? .isSelected : [])
    }

    private func tabZelleInhalt(tab: AppTab, aktiv: Bool) -> some View {
        VStack(spacing: 2) {
            Image(systemName: tab.sfSymbol)
                .font(.system(size: 18, weight: aktiv ? .semibold : .regular))
            Text(tab.titel)
                .font(.system(size: 10, weight: aktiv ? .semibold : .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(aktiv ? Color.white : DesignTokens.textSecondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(
            // Expliziter Fill statt leerem `@ViewBuilder`-Closure —
            // vermeidet Viewtype-Wechsel beim Aktiv/Inaktiv-Flip,
            // den SwiftUI gelegentlich nicht invalidiert.
            Capsule(style: .continuous)
                .fill(aktiv ? DesignTokens.accent : Color.clear)
        )
        // Capsule statt Rectangle als Hit-Shape — passt exakt zum
        // visuellen Pill-Umriss. `Rectangle()` machte den Tap-Bereich
        // kuenstlich rechteckig; beim eng gesetzten Tab-Abstand
        // landete ein Daumen-Tap zwischen zwei Pills ggf. auf dem
        // Nachbarn.
        .contentShape(Capsule())
    }
}
