//
//  AbrechnungenView.swift
//  NebenkostenApp — UI/Abrechnungen
//
//  Abrechnungen-Tab nach Design-Handoff. Berechnet die Mieter-
//  abrechnungen jeder Periode on-the-fly über AbrechnungsService
//  und listet sie gruppiert.
//
//  Drei Zustände je Periode:
//    1. berechenbar     — Card zeigt Einheit-Rows mit Saldo.
//    2. blockiert       — Card zeigt offene Anforderungen mit Link
//                         zum Vollständigkeits-Inspektor.
//    3. keine Mieter    — Hinweis-Card, nichts zu berechnen.
//
//  Tap auf einen Einheit-Row öffnet `AbrechnungDetailView` mit dem
//  Value-Typ `Mieterabrechnung` (re-berechnet im Sheet — kein
//  Persistenz-Kopplung).
//

import SwiftUI
import SwiftData

struct AbrechnungenView: View {
    @Environment(ScopeManager.self) private var scope
    @Query(sort: \Immobilie.erstelltAm) private var immobilien: [Immobilie]

    @State private var zeigeScopePicker = false
    @State private var zeigeEinstellungen = false
    @State private var zeigeInspektor = false
    @State private var detail: AbrechnungenDetailAuswahl?

    private var immobilie: Immobilie? { immobilien.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                kennzahlenCard
                periodenListe
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(DesignTokens.bgApp)
        .appShellChrome(
            titel: "Abrechnungen",
            subtitel: nil,
            onAdresse: { zeigeScopePicker = true },
            onEinstellungen: { zeigeEinstellungen = true }
        )
        .sheet(isPresented: $zeigeScopePicker) { ScopePickerSheet() }
        .sheet(isPresented: $zeigeEinstellungen) { EinstellungenSheet() }
        .sheet(isPresented: $zeigeInspektor) { InspektorPlatzhalter() }
        .sheet(item: $detail) { aus in
            NavigationStack {
                AbrechnungDetailView(abrechnung: aus.abrechnung, periode: aus.periodeText)
            }
        }
    }

    // MARK: - Kennzahlen

    private var kennzahlenCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Übersicht")
                        .appFont(AppFont.uppercaseLabel())
                        .foregroundStyle(DesignTokens.textTertiary)
                    Spacer()
                    Text("\(perioden.count) Periode\(perioden.count == 1 ? "" : "n")")
                        .appFont(AppFont.monoCaption())
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                PeriodStatsBlock(
                    links: StatBlock(
                        label: "Berechenbar",
                        wert: "\(berechenbarCount)",
                        detail: berechenbarDetail
                    ),
                    rechts: StatBlock(
                        label: "Offen",
                        wert: "\(blockiertCount)",
                        detail: "Pflicht-Daten fehlen"
                    )
                )
                if blockiertCount > 0 {
                    DividerLine()
                    Button {
                        zeigeInspektor = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checklist")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Vollständigkeit prüfen")
                                .appFont(AppFont.bodySemi())
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .foregroundStyle(DesignTokens.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Perioden-Liste

    @ViewBuilder
    private var periodenListe: some View {
        if perioden.isEmpty {
            Card {
                VStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 24))
                        .foregroundStyle(DesignTokens.textTertiary)
                    Text("Noch keine Abrechnungsperiode angelegt")
                        .appFont(AppFont.caption())
                        .foregroundStyle(DesignTokens.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        } else {
            VStack(spacing: 10) {
                ForEach(perioden) { p in
                    periodenCard(p)
                }
            }
        }
    }

    private func periodenCard(_ p: Abrechnungsperiode) -> some View {
        let res = ergebnisse(fuer: p)
        return VStack(alignment: .leading, spacing: 0) {
            sektionHeader(p: p, ergebnisse: res)

            switch res {
            case .berechenbar(let liste) where !liste.isEmpty:
                DividerLine()
                VStack(spacing: 0) {
                    ForEach(Array(liste.enumerated()), id: \.element.id) { idx, m in
                        Row(
                            label: titelFuer(m),
                            subtitel: subtitelFuer(m),
                            chevron: true,
                            action: { detail = .init(abrechnung: m, periodeText: periodenText(p)) },
                            leading: {
                                UnitBalken(farbe: einheitFarbe(m.einheitBezeichnung))
                                    .frame(height: 36)
                            },
                            trailing: {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(Formatting.euro(m.saldoEuro, showSign: m.saldoEuro > 0))
                                        .appFont(AppFont.monoBody())
                                        .foregroundStyle(saldoFarbe(m.saldoEuro))
                                    Text(saldoLabel(m.saldoEuro))
                                        .appFont(AppFont.micro())
                                        .foregroundStyle(DesignTokens.textTertiary)
                                }
                            }
                        )
                        if idx < liste.count - 1 {
                            DividerLine().padding(.leading, 14)
                        }
                    }
                }
            case .berechenbar:
                DividerLine()
                HStack {
                    StatusDot(status: .muted)
                    Text("Keine aktiven Mietverhältnisse in dieser Periode.")
                        .appFont(AppFont.caption())
                        .foregroundStyle(DesignTokens.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            case .blockiert(let anforderungen):
                DividerLine()
                blockerBody(anforderungen)
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

    private func sektionHeader(p: Abrechnungsperiode, ergebnisse res: PeriodenErgebnis) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DesignTokens.accent)
                .frame(width: 24, height: 24, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(periodenText(p))
                    .appFont(AppFont.bodySemi())
                    .foregroundStyle(DesignTokens.text)
                Text(Formatting.periode(p.von, p.bis))
                    .appFont(AppFont.monoCaption())
                    .foregroundStyle(DesignTokens.textSecondary)
            }
            Spacer(minLength: 8)
            StatusPill(text: res.pillText, style: res.pillStyle)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func blockerBody(_ anforderungen: [AnforderungMitStatus]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DesignTokens.statusWarn)
                Text("Pflichtdaten fehlen — Abrechnung ist blockiert.")
                    .appFont(AppFont.caption())
                    .foregroundStyle(DesignTokens.text)
                Spacer()
            }
            ForEach(anforderungen.prefix(3)) { a in
                HStack(spacing: 8) {
                    StatusDot(status: .error)
                    Text(a.anforderung.titel)
                        .appFont(AppFont.caption())
                        .foregroundStyle(DesignTokens.text)
                    Spacer()
                }
            }
            Button {
                zeigeInspektor = true
            } label: {
                HStack(spacing: 8) {
                    Text("Vollständigkeits-Inspektor öffnen")
                        .appFont(AppFont.caption())
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .foregroundStyle(DesignTokens.accent)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Ergebnisse

    private enum PeriodenErgebnis {
        case berechenbar([Mieterabrechnung])
        case blockiert([AnforderungMitStatus])

        var pillText: String {
            switch self {
            case .berechenbar(let liste):
                if liste.isEmpty { return "Keine Mieter" }
                return "Berechenbar"
            case .blockiert:
                return "Daten fehlen"
            }
        }

        var pillStyle: StatusPill.Style {
            switch self {
            case .berechenbar(let liste): return liste.isEmpty ? .muted : .ok
            case .blockiert:              return .warn
            }
        }
    }

    private func ergebnisse(fuer p: Abrechnungsperiode) -> PeriodenErgebnis {
        guard let immobilie else { return .berechenbar([]) }
        do {
            let liste = try AbrechnungsService.aggregiere(periode: p, immobilie: immobilie)
            return .berechenbar(filterNachScope(liste))
        } catch AbrechnungsBlocker.fehlendeDaten(let offen) {
            return .blockiert(offen)
        } catch {
            return .blockiert([])
        }
    }

    private func filterNachScope(_ liste: [Mieterabrechnung]) -> [Mieterabrechnung] {
        ScopeFilter.sichtbareAbrechnungen(alle: liste, scope: scope.current)
    }

    // MARK: - Kennzahlen-Daten

    private var perioden: [Abrechnungsperiode] {
        (immobilie?.perioden ?? []).sorted { $0.bis > $1.bis }
    }

    private var berechenbarCount: Int {
        perioden.filter {
            if case .berechenbar(let liste) = ergebnisse(fuer: $0), !liste.isEmpty {
                return true
            }
            return false
        }.count
    }

    private var blockiertCount: Int {
        perioden.filter {
            if case .blockiert = ergebnisse(fuer: $0) { return true }
            return false
        }.count
    }

    private var berechenbarDetail: String {
        guard perioden.count > 0 else { return "—" }
        let p = Double(berechenbarCount) / Double(perioden.count)
        return Formatting.prozent(p, dezimal: 0)
    }

    // MARK: - Format-Helper

    private func periodenText(_ p: Abrechnungsperiode) -> String {
        let kal = Calendar(identifier: .gregorian)
        let v = kal.component(.year, from: p.von)
        let b = kal.component(.year, from: p.bis)
        if v == b { return "Abrechnung \(v)" }
        return "Abrechnung \(v)/\(b)"
    }

    private func titelFuer(_ m: Mieterabrechnung) -> String {
        let name = ScopeTexte.abkuerzungName(m.mieterName)
        let ein = m.einheitBezeichnung
        return name.isEmpty ? ein : "\(ein) · \(name)"
    }

    private func subtitelFuer(_ m: Mieterabrechnung) -> String {
        "\(Formatting.euro(m.gesamtkostenEuro)) Kosten · \(Formatting.euro(m.vorauszahlungenEuro)) VZ"
    }

    private func saldoFarbe(_ s: Decimal) -> Color {
        if s > 0 { return DesignTokens.statusError }  // Nachzahlung
        if s < 0 { return DesignTokens.statusOk }     // Erstattung
        return DesignTokens.text
    }

    private func saldoLabel(_ s: Decimal) -> String {
        if s > 0 { return "Nachzahlung" }
        if s < 0 { return "Erstattung" }
        return "ausgeglichen"
    }

    private func einheitFarbe(_ bezeichnung: String) -> Color {
        guard let e = (immobilie?.wohneinheiten ?? [])
            .first(where: { $0.bezeichnung.caseInsensitiveCompare(bezeichnung) == .orderedSame })
        else { return DesignTokens.unitObjekt }
        return ScopeFarbe.farbe(fuer: e)
    }
}

/// Wrapper für das sheet(item:)-Routing.
private struct AbrechnungenDetailAuswahl: Identifiable {
    let abrechnung: Mieterabrechnung
    let periodeText: String
    var id: UUID { abrechnung.id }
}
