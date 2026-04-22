//
//  ZaehlerDetailView.swift
//  NebenkostenApp — UI/Zaehler
//
//  Detail-Sheet eines einzelnen Zaehlers. Geoeffnet aus
//  `ZaehlerView` beim Row-Tap; zeigt Stammdaten (Seriennummer,
//  Kennzeichen, Einheit, Standort) und die vollstaendige
//  Stand-Historie in absteigender Reihenfolge. „Neuer Stand"
//  oeffnet `ZaehlerstandErfassenView` als zweites Sheet.
//
//  UI-2-Polish: komplett auf DesignTokens + AppFont.Zaehler/
//  Basis-Rollen umgestellt — keine System-Systemtoene oder
//  `Color(.secondarySystemBackground)` mehr.
//

import SwiftUI
import SwiftData

struct ZaehlerDetailView: View {
    @Bindable var zaehler: Zaehler
    @State private var zeigeErfassen = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerCard
                staendeBlock
                if !sortierteStaende.isEmpty {
                    primaerButton("Neuer Stand", symbol: "plus.circle.fill") {
                        zeigeErfassen = true
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 40)
        }
        .background(DesignTokens.bgApp)
        .navigationTitle(kurzerTitel)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $zeigeErfassen) {
            NavigationStack {
                ZaehlerstandErfassenView(zaehler: zaehler)
            }
        }
    }

    // MARK: - Abgeleitete Werte

    private var sortierteStaende: [Zaehlerstand] {
        (zaehler.staende ?? []).sorted { $0.ablesedatum > $1.ablesedatum }
    }

    private var kurzerTitel: String {
        if !zaehler.bezeichnung.isEmpty { return zaehler.bezeichnung }
        return mediumName(zaehler.medium)
    }

    private var standortLabel: String {
        zaehler.wohneinheit?.bezeichnung ?? "Hauptzähler"
    }

    private var iconFarbe: Color {
        if let einheit = zaehler.wohneinheit {
            return ScopeFarbe.farbe(fuer: einheit)
        }
        return DesignTokens.unitObjekt
    }

    // MARK: - Header-Card

    private var headerCard: some View {
        Card(tiefe: .erhoben) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(iconFarbe.opacity(0.12))
                            .frame(width: 48, height: 48)
                        Image(systemName: icon(fuer: zaehler.medium))
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(iconFarbe)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mediumName(zaehler.medium))
                            .appFont(AppFont.Zaehler.bezeichnung())
                            .foregroundStyle(DesignTokens.text)
                        Text(typBezeichnung(zaehler.typ))
                            .appFont(AppFont.Zaehler.typ())
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                    Spacer()
                }

                DividerLine()

                VStack(alignment: .leading, spacing: 6) {
                    metaZeile(label: "Standort", wert: standortLabel)
                    if !zaehler.bezeichnung.isEmpty {
                        metaZeile(label: "Kennzeichen", wert: zaehler.bezeichnung)
                    }
                    if !zaehler.seriennummer.isEmpty {
                        metaZeile(
                            label: "Seriennummer",
                            wert: zaehler.seriennummer,
                            mono: true
                        )
                    }
                    metaZeile(
                        label: "Einheit",
                        wert: zaehler.einheit.isEmpty ? "—" : zaehler.einheit,
                        mono: true
                    )
                }
                .padding(.bottom, 6)
            }
        }
    }

    private func metaZeile(
        label: String,
        wert: String,
        mono: Bool = false
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .appFont(AppFont.Basis.caption())
                .foregroundStyle(DesignTokens.textTertiary)
                .frame(width: 110, alignment: .leading)
            Text(wert)
                .appFont(mono
                         ? AppFont.Basis.monoBody()
                         : AppFont.Basis.bodyMedium())
                .foregroundStyle(DesignTokens.text)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Staende-Sektion

    private var staendeBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Zählerstände") {
                if !sortierteStaende.isEmpty {
                    Text("\(sortierteStaende.count)")
                        .appFont(AppFont.Basis.monoCaption())
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            }
            if sortierteStaende.isEmpty {
                leerzustand
            } else {
                standListe
            }
        }
    }

    private var standListe: some View {
        Card {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(sortierteStaende.enumerated()),
                        id: \.element.id) { idx, stand in
                    standZeile(stand)
                        .padding(.vertical, 10)
                    if idx < sortierteStaende.count - 1 {
                        DividerLine()
                    }
                }
            }
        }
    }

    private func standZeile(_ stand: Zaehlerstand) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(Formatting.datum(stand.ablesedatum))
                    .appFont(AppFont.Basis.bodyMedium())
                    .foregroundStyle(DesignTokens.text)
                Text(stand.quelle.anzeigeName)
                    .appFont(AppFont.Basis.caption())
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 3) {
                Text(Formatting.zaehlerstand(stand.stand, einheit: zaehler.einheit))
                    .appFont(AppFont.Zaehler.standZahl())
                    .foregroundStyle(DesignTokens.text)
                if !zaehler.einheit.isEmpty {
                    Text(zaehler.einheit)
                        .appFont(AppFont.Zaehler.verbrauchEinheit())
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }
        }
    }

    private var leerzustand: some View {
        Card {
            VStack(spacing: 14) {
                Image(systemName: "gauge.with.dots.needle.0percent")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(DesignTokens.textSecondary)
                Text("Noch kein Stand erfasst")
                    .appFont(AppFont.Basis.bodyMedium())
                    .foregroundStyle(DesignTokens.textSecondary)
                primaerButton("Ersten Stand erfassen", symbol: "plus.circle.fill") {
                    zeigeErfassen = true
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
        }
    }

    // MARK: - Primär-Button

    /// Lokaler Primär-Button im Design-Handoff-Stil: Accent-
    /// Hintergrund, weisse Schrift, volle Breite. Wird nur von
    /// diesem Screen konsumiert — falls ein zweiter Screen denselben
    /// Stil braucht, in `UI/Components/` hochheben.
    private func primaerButton(
        _ titel: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                Text(titel)
                    .appFont(AppFont.Basis.bodySemi())
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(DesignTokens.accent)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Medium-/Typ-Helpers

    private func icon(fuer medium: Medium) -> String {
        switch medium {
        case .strom:         return "bolt"
        case .warmwasser:    return "drop.halffull"
        case .kaltwasser:    return "drop"
        case .waermeenergie: return "flame"
        case .gas:           return "fuelpump"
        case .oel:           return "drop.triangle"
        }
    }

    private func mediumName(_ medium: Medium) -> String {
        switch medium {
        case .strom:         return "Strom"
        case .warmwasser:    return "Warmwasser"
        case .kaltwasser:    return "Kaltwasser"
        case .waermeenergie: return "Wärmemengenzähler"
        case .gas:           return "Gas"
        case .oel:           return "Öl"
        }
    }

    private func typBezeichnung(_ typ: Zaehlertyp) -> String {
        switch typ {
        case .haupt:    return "Hauptzähler"
        case .wohnung:  return "Wohnungszähler"
        case .zwischen: return "Zwischenzähler"
        }
    }
}
