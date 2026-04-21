//
//  ObjektCarousel.swift
//  NebenkostenApp — UI/Home
//
//  Horizontales Paging-Carousel über alle Immobilien des Stores.
//  TabView mit `.page`-Style liefert natives Swipe-Verhalten und
//  klares 1-Objekt-Fokus-Gefühl. Die iOS-eigenen Indicator-Dots
//  sind ausgeblendet — wir rendern eigene Dots darunter, damit
//  Größe, Abstand und Farbe zur Designsprache passen.
//
//  Tap auf die aktive Card ruft `onOeffnen(immobilie)` — die
//  Parent-View entscheidet, was „das Objekt öffnen" konkret tut.
//

import SwiftUI

struct ObjektCarousel: View {
    let immobilien: [Immobilie]
    @Binding var aktuellerIndex: Int
    let onOeffnen: (Immobilie) -> Void

    var body: some View {
        VStack(spacing: 18) {
            TabView(selection: $aktuellerIndex) {
                ForEach(Array(immobilien.enumerated()), id: \.element.id) { idx, immobilie in
                    ObjektCard(immobilie: immobilie, onTap: { onOeffnen(immobilie) })
                        .padding(.vertical, 4)
                        .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 132)

            if immobilien.count > 1 {
                PaginationDots(
                    anzahl: immobilien.count,
                    aktiv: aktuellerIndex
                )
            }
        }
    }
}

// MARK: - Card pro Objekt

/// Einzelne, großzügig gesetzte Card pro Immobilie. Keine Mini-
/// Statistik, sondern eine klare Auswahlfläche: Adresse als
/// Hauptzeile (38 pt), Ort + Einheit-Info darunter, ein dezenter
/// Chevron unten rechts macht das Tap-Ziel klar.
struct ObjektCard: View {
    let immobilie: Immobilie
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(adresse)
                        .appFont(AppFont.Abrechnung.kopfName())
                        .foregroundStyle(DesignTokens.text)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                    if !ortZeile.isEmpty {
                        Text(ortZeile)
                            .appFont(AppFont.Rechnungen.subZeile())
                            .foregroundStyle(DesignTokens.textSecondary)
                            .lineLimit(1)
                    }
                    footerZeile
                        .padding(.top, 2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .padding(.top, 18)
            .padding(.bottom, 14)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(DesignTokens.bgSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(DesignTokens.separatorStrong, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.10), radius: 14, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var adresse: String {
        let a = immobilie.adresse.trimmingCharacters(in: .whitespaces)
        return a.isEmpty ? "Ohne Adresse" : a
    }

    private var ortZeile: String {
        immobilie.ort.trimmingCharacters(in: .whitespaces)
    }

    private var footerZeile: some View {
        HStack(spacing: 6) {
            Text(einheitenZeile)
                .appFont(AppFont.Basis.smallCaption())
                .foregroundStyle(DesignTokens.textTertiary)
            if immobilie.gesamtflaecheM2 > 0 {
                Text("·")
                    .foregroundStyle(DesignTokens.textQuaternary)
                Text(Formatting.m2(immobilie.gesamtflaecheM2))
                    .appFont(AppFont.Basis.monoSmall())
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            Spacer()
        }
    }

    private var einheitenZeile: String {
        let n = immobilie.wohneinheiten?.count ?? 0
        return n == 0 ? "Keine Einheiten" : "\(n) Einheit\(n == 1 ? "" : "en")"
    }
}

// MARK: - Pagination Dots

/// Reihe aus kleinen Kreisen, der aktive in accent-Farbe, Rest
/// dezent. Kein Padding links/rechts — wird vom Parent gesetzt.
struct PaginationDots: View {
    let anzahl: Int
    let aktiv: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0 ..< anzahl, id: \.self) { i in
                Circle()
                    .fill(farbe(fuer: i))
                    .frame(width: i == aktiv ? 9 : 7, height: i == aktiv ? 9 : 7)
                    .animation(.easeOut(duration: 0.15), value: aktiv)
            }
        }
        .padding(.top, 2)
    }

    private func farbe(fuer i: Int) -> Color {
        i == aktiv
            ? DesignTokens.accent
            : DesignTokens.textTertiary.opacity(0.35)
    }
}
