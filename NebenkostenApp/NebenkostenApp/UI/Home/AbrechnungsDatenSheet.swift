//
//  AbrechnungsDatenSheet.swift
//  NebenkostenApp — UI/Home
//
//  Zweit-Card auf der Home-View: „Abrechnungsdaten". Zaehlt die
//  periodisch zu erfassenden Positionen auf und bietet je eine
//  Sprungadresse (Belege, Zaehler, Vorauszahlungen). Bewusst
//  getrennt von der Stammdaten-Card — der User soll beim
//  Einstieg sofort erkennen, ob er gerade Stamm- oder laufende
//  NK-Daten bearbeitet.
//
//  Zusaetzlich in dieser Datei: `AbrechnungsdatenCard` — die
//  kompakte Home-Nav-Card, die das Sheet oeffnet. Einheitlicher
//  Look zu den Stammdaten-Cards in `WohneinheitCarousel`.
//

import SwiftUI

// MARK: - Navigations-Card auf dem Home-Screen

struct AbrechnungsdatenCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Card(tiefe: .erhoben, balkenFarbe: DesignTokens.accent) {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(DesignTokens.accent)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(DesignTokens.textTertiary)
                            Text("ABRECHNUNGSDATEN")
                                .appFont(AppFontStyle(
                                    font: AppFont.plexSans(.semibold, 12),
                                    tracking: 0.6,
                                    uppercase: true
                                ))
                                .foregroundStyle(DesignTokens.textTertiary)
                        }
                        Text("Belege · Zähler · Vorauszahlungen")
                            .appFont(AppFont.bodySemi())
                            .foregroundStyle(DesignTokens.text)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sheet mit den drei Sprungzielen

struct AbrechnungsDatenSheet: View {
    @Environment(AppShellRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    /// Callback zum Oeffnen des Vorauszahlungs-Sheets. Die Home-View
    /// handhabt die Praesentation, damit dieses Sheet selbst kein
    /// verschachteltes Sheet oeffnen muss (funktioniert zwar in
    /// iOS 16+, ist aber in Kombination mit Fullscreen-Scanner-Cover
    /// in der darueberliegenden KontextDetail-Ebene fragiler).
    let onVorauszahlungen: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    kopfCard
                    zielCard(
                        symbol: "doc.text",
                        titel: "Belege",
                        untertitel: "Rechnungen, Bescheide, Handwerker-Belege scannen und ansehen",
                        zielTab: .belege
                    )
                    zielCard(
                        symbol: "gauge.with.dots.needle.bottom.50percent",
                        titel: "Zählerstände",
                        untertitel: "Anfangs- und Endstände pro Medium erfassen",
                        zielTab: .zaehler
                    )
                    zielCard(
                        symbol: "eurosign.arrow.circlepath",
                        titel: "Vorauszahlungen",
                        untertitel: "Aktuellen Betrag je Mieter setzen oder anpassen",
                        zielTab: nil
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(DesignTokens.bgApp)
            .navigationTitle("Abrechnungsdaten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetToolbar.abbrechen(titel: "Fertig") { dismiss() }
                }
            }
        }
        .tint(DesignTokens.accent)
    }

    // MARK: - Header

    @ViewBuilder
    private var kopfCard: some View {
        Card(tiefe: .flach) {
            VStack(alignment: .leading, spacing: 6) {
                Text("LAUFENDE PERIODE")
                    .appFont(AppFont.Dashboard.kartenKicker())
                    .foregroundStyle(DesignTokens.textTertiary)
                Text("Was du während der Abrechnungsperiode regelmäßig erfasst")
                    .appFont(AppFont.bodyMedium())
                    .foregroundStyle(DesignTokens.text)
                Text("Stammdaten (Objekt, Mieter, Vermieter) kannst du oben in der Stammdaten-Card pflegen.")
                    .appFont(AppFont.caption())
                    .foregroundStyle(DesignTokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Ziel-Card

    @ViewBuilder
    private func zielCard(
        symbol: String,
        titel: String,
        untertitel: String,
        zielTab: AppTab?
    ) -> some View {
        Button {
            if let tab = zielTab {
                router.aktiverTab = tab
                dismiss()
            } else {
                // Vorauszahlungen werden nicht per Tab erreicht — die
                // Home-View oeffnet das VorauszahlungEingabeSheet.
                onVorauszahlungen()
                dismiss()
            }
        } label: {
            Card(tiefe: .flach) {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: symbol)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(DesignTokens.accent)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(titel)
                            .appFont(AppFont.bodySemi())
                            .foregroundStyle(DesignTokens.text)
                        Text(untertitel)
                            .appFont(AppFont.caption())
                            .foregroundStyle(DesignTokens.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
    }
}
