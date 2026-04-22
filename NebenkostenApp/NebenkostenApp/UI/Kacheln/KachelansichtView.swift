//
//  KachelansichtView.swift
//  NebenkostenApp — UI/Kacheln
//
//  Sekundaer-Navigation vom Home-Screen. 2x2-Grid mit vier Kacheln
//  (Stammdaten, Zaehlerstaende, Dokumente & Rechnungen, Abrechnung).
//  Jede Kachel zeigt Completion-Prozent und Mini-Fortschrittsbalken
//  in `CompletionFarbe.fuer(prozent:)`.
//
//  Tap-Ziele sind im MVP Platzhalter — die eigentlichen Kategorie-
//  Dashboards folgen in einem separaten Task. Bis dahin zeigt das
//  Sheet einen kurzen Hinweis, damit der Interaktions-Weg
//  durchgaengig ist.
//

import SwiftUI
import SwiftData

struct KachelansichtView: View {
    @Environment(ScopeManager.self) private var scope
    @Query(sort: \Immobilie.erstelltAm) private var immobilien: [Immobilie]

    @State private var aktiveKachelNotiz: String?

    private var aktiveImmobilie: Immobilie? {
        if let id = scope.aktuelleImmobilieID,
           let treffer = immobilien.first(where: { $0.id == id }) {
            return treffer
        }
        return immobilien.first
    }

    private var aktivePeriode: Abrechnungsperiode? {
        let perioden = (aktiveImmobilie?.perioden ?? [])
            .sorted(by: { $0.bis > $1.bis })
        let heute = Date()
        return perioden.first(where: { $0.bis < heute }) ?? perioden.first
    }

    /// Anforderungen OHNE WMZ-Plausi — die ist eine Warnung, keine
    /// Abrechnungs-Pflicht und wuerde die Kategorie-Prozente sonst
    /// in einer nicht-nuetzlichen Weise beeinflussen.
    private var anforderungen: [AnforderungMitStatus] {
        guard let immobilie = aktiveImmobilie,
              let p = aktivePeriode else { return [] }
        return VollstaendigkeitsPruefung
            .pruefe(immobilie: immobilie, periode: p)
            .filter { $0.anforderung.id != "plausi-wmz" }
    }

    private var stammdatenProzent: Int {
        VollstaendigkeitsPruefung.completionProzent(
            anforderungen, kategorie: .stammdaten
        )
    }

    private var zaehlerProzent: Int {
        VollstaendigkeitsPruefung.completionProzent(
            anforderungen, kategorie: .zaehlerstand
        )
    }

    private var rechnungenProzent: Int {
        VollstaendigkeitsPruefung.completionProzent(
            anforderungen, kategorie: .rechnung
        )
    }

    /// Gesamt-Completion fuer die „Abrechnung"-Kachel. 100 %
    /// bedeutet: die aktive Periode ist bereits abgeschlossen
    /// (alle PDFs erzeugt, Periode markiert). Sonst gibt die
    /// Zusammenfassung maximal 99 % aus — 100 % ist reserviert
    /// fuer den abgeschlossenen Zustand.
    private var abrechnungProzent: Int {
        if aktivePeriode?.abgeschlossen == true {
            return 100
        }
        let roh = VollstaendigkeitsPruefung
            .zusammenfassung(fuer: anforderungen)
            .completionProzent
        return min(99, roh)
    }

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                NavigationLink {
                    StammdatenView()
                } label: {
                    KachelCardLabel(
                        titel: "Stammdaten",
                        icon: "person.text.rectangle",
                        prozent: stammdatenProzent
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    ZaehlerstaendeView()
                } label: {
                    KachelCardLabel(
                        titel: "Zählerstände",
                        icon: "gauge.medium",
                        prozent: zaehlerProzent
                    )
                }
                .buttonStyle(.plain)
                NavigationLink {
                    DokumenteRechnungenView()
                } label: {
                    KachelCardLabel(
                        titel: "Dokumente & Rechnungen",
                        icon: "doc.text.magnifyingglass",
                        prozent: rechnungenProzent
                    )
                }
                .buttonStyle(.plain)
                NavigationLink {
                    AbrechnungsKachelView()
                } label: {
                    KachelCardLabel(
                        titel: "Abrechnung",
                        icon: "doc.badge.checkmark",
                        prozent: abrechnungProzent
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .background(DesignTokens.bgAppCompact)
        .navigationTitle("Übersicht")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(
            get: { aktiveKachelNotiz != nil },
            set: { if !$0 { aktiveKachelNotiz = nil } }
        )) {
            if let text = aktiveKachelNotiz {
                KachelPlatzhalterSheet(text: text)
            }
        }
    }

    private func platzhalterText(_ bereich: String) -> String {
        "Das Dashboard für \u{201E}\(bereich)\u{201C} folgt im nächsten Task. Bis dahin erreichen Sie die Inhalte über die TabBar."
    }
}

// MARK: - KachelCard

fileprivate struct KachelCard: View {
    let titel: String
    let icon: String
    let prozent: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            KachelCardLabel(titel: titel, icon: icon, prozent: prozent)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(titel), \(prozent) Prozent")
    }
}

/// Reine Label-Darstellung einer Kachel — ohne Button-Wrapper.
/// Wird sowohl direkt (NavigationLink-Label) als auch innerhalb
/// von `KachelCard` (als Button-Label mit `onTap`) verwendet.
fileprivate struct KachelCardLabel: View {
    let titel: String
    let icon: String
    let prozent: Int

    private var farbe: Color { CompletionFarbe.fuer(prozent: prozent) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(farbe)

            Text(titel)
                .appFont(AppFont.Basis.bodySemi())
                .foregroundStyle(DesignTokens.text)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            fortschrittBlock
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .background(DesignTokens.bgSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DesignTokens.separator, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var fortschrittBlock: some View {
        VStack(alignment: .trailing, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(farbe.opacity(0.15))
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(farbe)
                        .frame(
                            width: max(4, geo.size.width * CGFloat(prozent) / 100)
                        )
                }
            }
            .frame(height: 4)

            Text("\(prozent) %")
                .appFont(AppFont.Basis.monoSmall())
                .foregroundStyle(DesignTokens.textSecondary)
        }
    }
}

// MARK: - Platzhalter-Sheet

fileprivate struct KachelPlatzhalterSheet: View {
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "hammer")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(DesignTokens.textSecondary)
                Text(text)
                    .appFont(AppFont.Basis.body())
                    .foregroundStyle(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignTokens.bgApp)
            .navigationTitle("Bald verfügbar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
