//
//  UebersichtObjektView.swift
//  NebenkostenApp — UI/Uebersicht
//
//  Haus-Dashboard für den Objekt-Scope. Vier Sections nach
//  dashboard.jsx / 01-dashboard-objekt.jpg:
//    1. Periodenkarte (Umsatz, Vorauszahlungen, Validiert-Progress)
//    2. Offene Punkte (max. 3 Preview + "Alle prüfen")
//    3. Einheiten (Card je Wohneinheit, Tap schaltet Scope)
//    4. Schnellaktionen (2×2 Button-Grid)
//

import SwiftUI
import SwiftData

struct UebersichtObjektView: View {
    @Environment(ScopeManager.self) private var scope
    @Query(sort: \Immobilie.erstelltAm) private var immobilien: [Immobilie]
    @State private var zeigeScopePicker = false
    @State private var zeigeEinstellungen = false
    @State private var zeigeInspektor = false

    private var immobilie: Immobilie? { immobilien.first }

    private var einheiten: [Wohneinheit] {
        (immobilie?.wohneinheiten ?? []).sorted {
            Self.sortRang($0.bezeichnung) < Self.sortRang($1.bezeichnung)
        }
    }

    private var aktivePeriode: Abrechnungsperiode? {
        let perioden = (immobilie?.perioden ?? []).sorted(by: { $0.bis > $1.bis })
        let heute = Date()
        return perioden.first(where: { $0.bis < heute }) ?? perioden.first
    }

    private var anforderungen: [AnforderungMitStatus] {
        guard let immobilie, let periode = aktivePeriode else { return [] }
        return VollstaendigkeitsPruefung.pruefe(immobilie: immobilie, periode: periode)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                periodenkarte
                offenePunkteSektion
                einheitenSektion
                schnellaktionen
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(DesignTokens.bgApp)
        .appShellChrome(
            titel: "Haus-Übersicht",
            subtitel: periodenSubtitel,
            onAdresse: { zeigeScopePicker = true },
            onEinstellungen: { zeigeEinstellungen = true }
        )
        .sheet(isPresented: $zeigeScopePicker) { ScopePickerSheet() }
        .sheet(isPresented: $zeigeEinstellungen) { EinstellungenSheet() }
        .sheet(isPresented: $zeigeInspektor) { InspektorPlatzhalter() }
    }

    // MARK: - Perioden-Karte

    private var periodenkarte: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Abrechnungsperiode")
                        .appFont(AppFont.uppercaseLabel())
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(DesignTokens.textTertiary)
                    Spacer()
                    Text(jahrText)
                        .appFont(AppFont.monoSmall())
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                PeriodStatsBlock(
                    links: StatBlock(
                        label: "Umlagefähige Kosten",
                        wert: Formatting.euro(umlageSumme),
                        detail: "\(rechnungenCount) Rechnungen"
                    ),
                    rechts: StatBlock(
                        label: "Vorauszahlungen",
                        wert: Formatting.euro(vorauszahlungSumme),
                        detail: "\(aktiveMieterCount) Einheiten"
                    )
                )
                DividerLine()
                    .padding(.top, 2)
                validiertZeile
                    .padding(.top, 6)
            }
        }
    }

    private var validiertZeile: some View {
        let z = VollstaendigkeitsPruefung.zusammenfassung(fuer: anforderungen)
        let total = max(1, z.total - z.nichtErwartet)
        let anteil = Double(z.erfuellt) / Double(total)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Validiert & bereit")
                        .appFont(AppFont.subtitle())
                        .foregroundStyle(DesignTokens.textSecondary)
                    Text("\(z.erfuellt) / \(total) Einträge")
                        .appFont(AppFont.monoCaption())
                        .foregroundStyle(DesignTokens.statusOk)
                }
                Spacer()
                Text(Formatting.prozent(anteil, dezimal: 0))
                    .appFont(AppFont.monoLarge())
                    .foregroundStyle(DesignTokens.statusOk)
            }
            ProgressRail(anteil: anteil, fillFarbe: DesignTokens.statusOk)
        }
    }

    // MARK: - Offene Punkte

    private var offenePunkteSektion: some View {
        let liste = anforderungen
            .filter { $0.status != .erfuellt && $0.status != .nichtErwartet }
            .prefix(3)
        if liste.isEmpty {
            return AnyView(EmptyView())
        }
        return AnyView(
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader("Offene Punkte") {
                    Button {
                        zeigeInspektor = true
                    } label: {
                        Text("Alle \(anforderungenOffenTotal) prüfen →")
                            .appFont(AppFont.caption())
                            .foregroundStyle(DesignTokens.accent)
                    }
                    .buttonStyle(.plain)
                }
                VStack(spacing: 0) {
                    ForEach(Array(liste.enumerated()), id: \.element.id) { idx, a in
                        Row(
                            label: a.anforderung.titel,
                            subtitel: a.anforderung.details,
                            chevron: true,
                            action: { zeigeInspektor = true }
                        ) {
                            StatusDot(status: statusDot(a.status))
                        } trailing: { EmptyView() }
                        if idx < liste.count - 1 {
                            DividerLine().padding(.leading, 14)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignTokens.bgSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DesignTokens.separator, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        )
    }

    private var anforderungenOffenTotal: Int {
        anforderungen.filter {
            $0.status != .erfuellt && $0.status != .nichtErwartet
        }.count
    }

    private func statusDot(_ s: AnforderungsStatus) -> StatusDot.Status {
        switch s {
        case .erfuellt:      return .ok
        case .teilweise:     return .warn
        case .offen:         return .error
        case .nichtErwartet: return .muted
        }
    }

    // MARK: - Einheiten

    private var einheitenSektion: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Einheiten")
            VStack(spacing: 10) {
                ForEach(einheiten) { e in
                    einheitenCard(e)
                }
            }
        }
    }

    private func einheitenCard(_ e: Wohneinheit) -> some View {
        let farbe = ScopeFarbe.farbe(fuer: e)
        return Button {
            scope.current = .einheit(id: e.bezeichnung)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                UnitBalken(farbe: farbe)
                    .frame(height: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(einheitTitel(e))
                        .appFont(AppFont.bodySemi())
                        .foregroundStyle(DesignTokens.text)
                    Text(Formatting.m2(e.flaecheM2))
                        .appFont(AppFont.monoSmall())
                        .foregroundStyle(DesignTokens.textTertiary)
                    if let mv = aktivesMietverhaeltnis(e) {
                        Text(ScopeTexte.abkuerzungName(mv.mieterName))
                            .appFont(AppFont.subtitle())
                            .foregroundStyle(DesignTokens.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(Formatting.euro(vorauszahlungMonat(e)))
                        .appFont(AppFont.monoBody())
                        .foregroundStyle(DesignTokens.text)
                    Text("Vorauszahlung / Monat")
                        .appFont(AppFont.micro())
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }
            .padding(14)
            .background(DesignTokens.bgSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(DesignTokens.separator, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func einheitTitel(_ e: Wohneinheit) -> String {
        switch e.nutzungsart {
        case .gewerbe: return "\(e.bezeichnung) Gewerbe"
        case .leerstand: return "\(e.bezeichnung) Leerstand"
        default: return "\(e.bezeichnung) Wohnung"
        }
    }

    private func aktivesMietverhaeltnis(_ e: Wohneinheit) -> Mietverhaeltnis? {
        (e.mietverhaeltnisse ?? []).first { $0.auszugAm == nil }
    }

    private func vorauszahlungMonat(_ e: Wohneinheit) -> Decimal {
        aktivesMietverhaeltnis(e)?.vorauszahlungMonatEuro ?? 0
    }

    // MARK: - Schnellaktionen

    private var schnellaktionen: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Schnellaktionen")
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                aktionButton(titel: "Beleg scannen",
                             symbol: "camera.fill",
                             primary: true) {
                    // Scan-Flow-Sheet kommt in UI-2.
                }
                aktionButton(titel: "Zählerstand erfassen",
                             symbol: "gauge.medium",
                             primary: false) {
                    // kommt in UI-2
                }
                aktionButton(titel: "Rechnung manuell",
                             symbol: "plus",
                             primary: false) {
                    // kommt in UI-2
                }
                aktionButton(titel: "Abrechnung rechnen",
                             symbol: "function",
                             primary: false) {
                    // kommt in UI-2
                }
            }
        }
    }

    private func aktionButton(titel: String, symbol: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(primary ? DesignTokens.accentText : DesignTokens.accent)
                Text(titel)
                    .appFont(AppFont.bodySemi())
                    .foregroundStyle(primary ? DesignTokens.accentText : DesignTokens.text)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(primary ? DesignTokens.accent : DesignTokens.bgSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(primary ? Color.clear : DesignTokens.separator, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Derived

    private var periodenSubtitel: String? {
        guard aktivePeriode != nil else { return nil }
        let adresse = immobilie?.adresse ?? ""
        return "\(adresse) · \(jahrText)"
    }

    private var jahrText: String {
        guard let p = aktivePeriode else { return "—" }
        let kal = Calendar(identifier: .gregorian)
        let von = kal.component(.year, from: p.von)
        let bis = kal.component(.year, from: p.bis)
        return von == bis ? "\(von)" : "\(von)/\(bis)"
    }

    private var rechnungenInPeriode: [Rechnung] {
        guard let immobilie, let p = aktivePeriode else { return [] }
        return (immobilie.rechnungen ?? []).filter {
            $0.rechnungsdatum >= p.von && $0.rechnungsdatum <= p.bis
        }
    }

    private var rechnungenCount: Int { rechnungenInPeriode.count }

    private var umlageSumme: Decimal {
        rechnungenInPeriode.reduce(Decimal(0)) { $0 + $1.betragBruttoEuro }
    }

    private var aktiveMieterCount: Int {
        einheiten.filter { aktivesMietverhaeltnis($0) != nil }.count
    }

    private var vorauszahlungSumme: Decimal {
        guard let p = aktivePeriode else { return 0 }
        let monate = Decimal(monateInPeriode(p))
        return einheiten
            .compactMap(aktivesMietverhaeltnis)
            .reduce(Decimal(0)) { $0 + ($1.vorauszahlungMonatEuro * monate) }
    }

    private func monateInPeriode(_ p: Abrechnungsperiode) -> Int {
        var kal = Calendar(identifier: .gregorian)
        kal.timeZone = TimeZone(identifier: "UTC")!
        let k = kal.dateComponents([.month], from: p.von, to: p.bis)
        return max((k.month ?? 0) + 1, 1)
    }

    private static func sortRang(_ b: String) -> Int {
        switch b.uppercased().trimmingCharacters(in: .whitespaces) {
        case "KG", "UG": return 0
        case "EG":       return 1
        case "OG":       return 2
        case "2. OG":    return 3
        case "DG":       return 4
        default:         return 99
        }
    }
}
