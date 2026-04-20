//
//  ZaehlerView.swift
//  NebenkostenApp — UI/Zaehler
//
//  Zähler-Tab nach Design-Handoff + UI-Fix-2.
//    1. Kennzahlen-Card (Ablesungen · Geräte).
//    2. Je Medium eine CollapsibleSection mit Rows (alle default offen).
//       Row-Layout: Symbol + anzeigename (17pt/600) + (typ · ort),
//       rechts großer Mono-Wert (18pt/600) + Einheit (12pt) +
//       StatusDot. Datum darunter (12pt).
//    3. Footer-Hinweis zum Tappen.
//
//  Scope-Verhalten:
//    objekt  → alle Hauptzähler + alle Einheit-Zähler, gruppiert.
//    einheit → nur Zähler dieser Einheit (Hauptzähler ausgeblendet).
//
//  Tap → ZaehlerstandErfassenView-Sheet.
//

import SwiftUI
import SwiftData

struct ZaehlerView: View {
    @Environment(ScopeManager.self) private var scope
    @Query(sort: \Immobilie.erstelltAm) private var immobilien: [Immobilie]

    @State private var zeigeScopePicker = false
    @State private var zeigeEinstellungen = false
    @State private var erfassenZaehler: Zaehler?

    private var immobilie: Immobilie? { immobilien.first }

    private var aktivePeriode: Abrechnungsperiode? {
        let perioden = (immobilie?.perioden ?? []).sorted(by: { $0.bis > $1.bis })
        let heute = Date()
        return perioden.first(where: { $0.bis < heute }) ?? perioden.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                kennzahlenCard
                mediumSektionen
                hinweisFooter
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(DesignTokens.bgApp)
        .appShellChrome(
            titel: "Zähler",
            subtitel: subtitel,
            onAdresse: { zeigeScopePicker = true },
            onEinstellungen: { zeigeEinstellungen = true }
        )
        .sheet(isPresented: $zeigeScopePicker) { ScopePickerSheet() }
        .sheet(isPresented: $zeigeEinstellungen) { EinstellungenSheet() }
        .sheet(item: $erfassenZaehler) { z in
            NavigationStack { ZaehlerstandErfassenView(zaehler: z) }
        }
    }

    // MARK: - Kennzahlen

    private var kennzahlenCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Abrechnungsperiode")
                        .appFont(AppFont.uppercaseLabel())
                        .foregroundStyle(DesignTokens.textTertiary)
                    Spacer()
                    if let p = aktivePeriode {
                        Text(Formatting.periode(p.von, p.bis))
                            .appFont(AppFont.monoCaption())
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                }
                PeriodStatsBlock(
                    links: StatBlock(
                        label: "Ablesungen",
                        wert: "\(ablesungenInPeriode)",
                        detail: "in der Periode"
                    ),
                    rechts: StatBlock(
                        label: "Geräte",
                        wert: "\(sichtbareZaehler.count)",
                        detail: geraeteDetail
                    )
                )
                if offeneEndstaende > 0 {
                    DividerLine()
                    HStack(spacing: 10) {
                        StatusDot(status: .warn)
                        Text("\(offeneEndstaende) Endstand\(offeneEndstaende == 1 ? "" : "-Werte") fehlt\(offeneEndstaende == 1 ? "" : "en")")
                            .appFont(AppFont.caption())
                            .foregroundStyle(DesignTokens.text)
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Medium-Gruppen

    private var mediumSektionen: some View {
        VStack(spacing: 10) {
            ForEach(sichtbareMedienMitZaehlern, id: \.medium) { gruppe in
                CollapsibleSection(
                    titel: gruppe.anzeigeName,
                    summary: nil,
                    count: gruppe.zaehler.count,
                    persistKey: "zaehler.medium.\(gruppe.medium.rawValue).open",
                    defaultOffen: true
                ) {
                    VStack(spacing: 0) {
                        ForEach(Array(gruppe.zaehler.enumerated()), id: \.element.id) { idx, z in
                            zaehlerZeile(z)
                            if idx < gruppe.zaehler.count - 1 {
                                DividerLine().padding(.leading, 14)
                            }
                        }
                    }
                }
            }
        }
    }

    private func zaehlerZeile(_ z: Zaehler) -> some View {
        Button {
            erfassenZaehler = z
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: mediumSymbol(z.medium))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(mediumFarbe(z))
                    .frame(width: 28, height: 28, alignment: .center)

                VStack(alignment: .leading, spacing: 4) {
                    Text(z.anzeigename)
                        .appFont(AppFont.bodySemi17())
                        .foregroundStyle(DesignTokens.text)
                        .lineLimit(1)
                    Text(zaehlerSubLine(z))
                        .appFont(AppFont.subtitleEmphasis())
                        .foregroundStyle(DesignTokens.textSecondary)
                        .lineLimit(1)
                    if let stand = letzterStand(z) {
                        Text("letzter Stand am \(Formatting.datum(stand.ablesedatum))")
                            .appFont(AppFont.captionEmphasis())
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    if let stand = letzterStand(z) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(standZahl(stand.stand))
                                .appFont(AppFont.monoMesswert())
                                .foregroundStyle(DesignTokens.text)
                            if !z.einheit.isEmpty {
                                Text(z.einheit)
                                    .appFont(AppFont.monoCaption())
                                    .foregroundStyle(DesignTokens.textSecondary)
                            }
                        }
                    } else {
                        Text("—")
                            .appFont(AppFont.monoMesswert())
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                    StatusDot(status: zaehlerDotStatus(z))
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.textTertiary)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func zaehlerSubLine(_ z: Zaehler) -> String {
        var parts: [String] = [z.anzeigetyp]
        if !z.anzeigeort.isEmpty { parts.append(z.anzeigeort) }
        return parts.joined(separator: " · ")
    }

    // MARK: - Footer

    private var hinweisFooter: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap")
                .font(.caption)
                .foregroundStyle(DesignTokens.textTertiary)
            Text("Auf einen Zähler tippen, um einen Stand zu erfassen.")
                .appFont(AppFont.caption())
                .foregroundStyle(DesignTokens.textTertiary)
            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: - Daten

    private var subtitel: String? {
        guard let p = aktivePeriode else { return nil }
        let kal = Calendar(identifier: .gregorian)
        let j = kal.component(.year, from: p.bis)
        return "Periode \(j) · \(sichtbareZaehler.count) Geräte"
    }

    private var sichtbareEinheiten: [Wohneinheit] {
        ScopeFilter.sichtbareEinheiten(alle: immobilie?.wohneinheiten ?? [], scope: .objekt)
    }

    private var sichtbareZaehler: [Zaehler] {
        let p = ScopeFilter.zaehlerGetrennt(
            hauptzaehler: immobilie?.hauptzaehler ?? [],
            einheiten: immobilie?.wohneinheiten ?? [],
            scope: scope.current
        )
        return p.haupt + p.wohnung
    }

    private struct MediumGruppe {
        let medium: Medium
        let anzeigeName: String
        let zaehler: [Zaehler]
    }

    private var sichtbareMedienMitZaehlern: [MediumGruppe] {
        let alle = sichtbareZaehler
        let gruppiert = Dictionary(grouping: alle) { $0.medium }
        return Medium.allCases.compactMap { m -> MediumGruppe? in
            guard let liste = gruppiert[m], !liste.isEmpty else { return nil }
            return MediumGruppe(
                medium: m,
                anzeigeName: mediumName(m),
                zaehler: liste.sorted { lhs, rhs in
                    let lh = lhs.wohneinheit == nil ? 0 : 1  // Hauptzähler zuerst
                    let rh = rhs.wohneinheit == nil ? 0 : 1
                    if lh != rh { return lh < rh }
                    return ScopeFilter.einheitRang(lhs.wohneinheit?.bezeichnung ?? "")
                        < ScopeFilter.einheitRang(rhs.wohneinheit?.bezeichnung ?? "")
                }
            )
        }
    }

    private var ablesungenInPeriode: Int {
        guard let p = aktivePeriode else { return 0 }
        return sichtbareZaehler.reduce(0) { acc, z in
            acc + (z.staende ?? []).filter {
                $0.ablesedatum >= p.von && $0.ablesedatum <= p.bis
            }.count
        }
    }

    private var offeneEndstaende: Int {
        guard let p = aktivePeriode else { return 0 }
        return sichtbareZaehler.filter { z in
            let inPeriode = (z.staende ?? []).filter {
                $0.ablesedatum >= p.von && $0.ablesedatum <= p.bis
            }
            return inPeriode.count < 2
        }.count
    }

    private var geraeteDetail: String {
        switch scope.current {
        case .objekt:
            let haupt = (immobilie?.hauptzaehler ?? []).count
            let wohnung = sichtbareEinheiten.flatMap { $0.zaehler ?? [] }.count
            return "\(haupt) Haus · \(wohnung) Einheit"
        case .einheit:
            return "in dieser Einheit"
        }
    }

    // MARK: - Helper

    private func letzterStand(_ z: Zaehler) -> Zaehlerstand? {
        (z.staende ?? []).max(by: { $0.ablesedatum < $1.ablesedatum })
    }

    private func zaehlerDotStatus(_ z: Zaehler) -> StatusDot.Status {
        guard let p = aktivePeriode else { return .muted }
        let inPeriode = (z.staende ?? []).filter {
            $0.ablesedatum >= p.von && $0.ablesedatum <= p.bis
        }
        if inPeriode.count >= 2 { return .ok }
        if inPeriode.count == 1 { return .warn }
        return .error
    }

    private func standZahl(_ value: Decimal) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 3
        f.groupingSeparator = "."
        f.decimalSeparator = ","
        return f.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }

    private func mediumFarbe(_ z: Zaehler) -> Color {
        if let e = z.wohneinheit {
            return ScopeFarbe.farbe(fuer: e)
        }
        return DesignTokens.unitObjekt
    }

    private func mediumSymbol(_ m: Medium) -> String {
        switch m {
        case .strom:         return "bolt.fill"
        case .gas:           return "flame.fill"
        case .warmwasser:    return "drop.fill"
        case .kaltwasser:    return "drop"
        case .waermeenergie: return "thermometer"
        case .oel:           return "drop.triangle.fill"
        }
    }

    private func mediumName(_ m: Medium) -> String {
        switch m {
        case .strom:         return "Strom"
        case .warmwasser:    return "Warmwasser"
        case .kaltwasser:    return "Kaltwasser"
        case .waermeenergie: return "Wärmemenge"
        case .gas:           return "Gas"
        case .oel:           return "Öl"
        }
    }
}
