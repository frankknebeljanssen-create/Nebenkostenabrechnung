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

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs) { tab in
                Button {
                    wechsle(zu: tab)
                } label: {
                    tabZelle(tab)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.titel)
                .accessibilityAddTraits(aktiverTab == tab ? .isSelected : [])
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background {
            Capsule(style: .continuous)
                .fill(DesignTokens.bgAppCompact)
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

    private func wechsle(zu tab: AppTab) {
        guard aktiverTab != tab else { return }
        aktiverTab = tab
    }

    @ViewBuilder
    private func tabZelle(_ tab: AppTab) -> some View {
        let aktiv = aktiverTab == tab
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
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background {
            if aktiv {
                Capsule(style: .continuous)
                    .fill(DesignTokens.accent)
            }
        }
        .contentShape(Rectangle())
    }
}
