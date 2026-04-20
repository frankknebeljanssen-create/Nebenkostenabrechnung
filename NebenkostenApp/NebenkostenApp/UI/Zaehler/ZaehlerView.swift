//
//  ZaehlerView.swift
//  NebenkostenApp — UI/Zaehler
//
//  Zähler-Tab nach Design-Handoff. Drei Sections:
//    1. PeriodStatsBlock — "Ablesungen · Periode" und "Geräte gesamt".
//    2. Hauptzähler — Card-Liste der Liegenschafts-Hauptzähler.
//    3. Wohnungszähler — gruppiert nach Einheit (im Objekt-Scope) bzw.
//       nur die Einheit-Zähler (im Einheit-Scope).
//
//  Tap auf einen Zähler öffnet in UI-2 das Detail-Sheet mit Stands-
//  historie und "Stand erfassen"-Button. Bis dahin ist der Row read-
//  only — ein "Zählerstand erfassen"-Primary-Button am Ende startet
//  den Flow global.
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
                hauptzaehlerSektion
                wohnungsZaehlerSektion
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
            NavigationStack {
                ZaehlerstandErfassenView(zaehler: z)
            }
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

    // MARK: - Hauptzähler

    @ViewBuilder
    private var hauptzaehlerSektion: some View {
        let liste = hauptzaehlerSichtbar
        if !liste.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader("Hauptzähler") {
                    Text("\(liste.count) Gerät\(liste.count == 1 ? "" : "e")")
                        .appFont(AppFont.monoCaption())
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                zaehlerListe(liste, farbe: DesignTokens.unitObjekt)
            }
        }
    }

    // MARK: - Wohnungszähler

    @ViewBuilder
    private var wohnungsZaehlerSektion: some View {
        switch scope.current {
        case .objekt:
            ForEach(sichtbareEinheiten) { e in
                let zaehler = (e.zaehler ?? []).sorted { $0.medium.rawValue < $1.medium.rawValue }
                if !zaehler.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(einheitTitel(e)) {
                            Text("\(zaehler.count) Gerät\(zaehler.count == 1 ? "" : "e")")
                                .appFont(AppFont.monoCaption())
                                .foregroundStyle(DesignTokens.textTertiary)
                        }
                        zaehlerListe(zaehler, farbe: ScopeFarbe.farbe(fuer: e))
                    }
                }
            }
        case .einheit(let id):
            if let e = (immobilie?.wohneinheiten ?? []).first(where: {
                $0.bezeichnung.caseInsensitiveCompare(id) == .orderedSame
            }) {
                let zaehler = (e.zaehler ?? []).sorted { $0.medium.rawValue < $1.medium.rawValue }
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(einheitTitel(e)) {
                        if !zaehler.isEmpty {
                            Text("\(zaehler.count) Gerät\(zaehler.count == 1 ? "" : "e")")
                                .appFont(AppFont.monoCaption())
                                .foregroundStyle(DesignTokens.textTertiary)
                        }
                    }
                    if zaehler.isEmpty {
                        Card {
                            Text("Keine Zähler dieser Einheit erfasst.")
                                .appFont(AppFont.caption())
                                .foregroundStyle(DesignTokens.textSecondary)
                        }
                    } else {
                        zaehlerListe(zaehler, farbe: ScopeFarbe.farbe(fuer: e))
                    }
                }
            }
        }
    }

    private func zaehlerListe(_ liste: [Zaehler], farbe: Color) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(liste.enumerated()), id: \.element.id) { idx, z in
                Row(
                    label: anzeigeNameZaehler(z),
                    subtitel: zaehlerDetailText(z),
                    chevron: true,
                    action: { erfassenZaehler = z },
                    leading: {
                        Image(systemName: mediumSymbol(z.medium))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(farbe)
                            .frame(width: 24, height: 24, alignment: .center)
                    },
                    trailing: {
                        HStack(spacing: 8) {
                            if let stand = letzterStand(z) {
                                Text(formatiere(stand.stand, einheit: z.einheit))
                                    .appFont(AppFont.monoCaption())
                                    .foregroundStyle(DesignTokens.text)
                            }
                            StatusDot(status: zaehlerDotStatus(z))
                        }
                    }
                )
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

    // MARK: - Derived

    private var subtitel: String? {
        guard let p = aktivePeriode else { return nil }
        let kal = Calendar(identifier: .gregorian)
        let j = kal.component(.year, from: p.bis)
        return "Periode \(j)"
    }

    private var sichtbareEinheiten: [Wohneinheit] {
        (immobilie?.wohneinheiten ?? []).sorted {
            Self.sortRang($0.bezeichnung) < Self.sortRang($1.bezeichnung)
        }
    }

    /// Alle Zähler im aktuellen Scope — für Kennzahlen.
    private var sichtbareZaehler: [Zaehler] {
        switch scope.current {
        case .objekt:
            return hauptzaehlerSichtbar + sichtbareEinheiten.flatMap { $0.zaehler ?? [] }
        case .einheit(let id):
            guard let e = sichtbareEinheiten.first(where: {
                $0.bezeichnung.caseInsensitiveCompare(id) == .orderedSame
            }) else { return [] }
            return e.zaehler ?? []
        }
    }

    private var hauptzaehlerSichtbar: [Zaehler] {
        switch scope.current {
        case .objekt:
            return (immobilie?.hauptzaehler ?? []).sorted { $0.medium.rawValue < $1.medium.rawValue }
        case .einheit:
            // Im Einheit-Scope werden Hauptzähler nicht angezeigt.
            return []
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
            let haupt = hauptzaehlerSichtbar.count
            let wohnung = sichtbareEinheiten.flatMap { $0.zaehler ?? [] }.count
            return "\(haupt) Haus · \(wohnung) Wohnung"
        case .einheit:
            return "in dieser Einheit"
        }
    }

    // MARK: - Zähler-Helper

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

    private func anzeigeNameZaehler(_ z: Zaehler) -> String {
        if !z.bezeichnung.isEmpty { return z.bezeichnung }
        return mediumName(z.medium)
    }

    private func zaehlerDetailText(_ z: Zaehler) -> String {
        let basis = mediumName(z.medium)
        if let stand = letzterStand(z) {
            return "\(basis) · letzte Ablesung \(Formatting.datum(stand.ablesedatum))"
        }
        if !z.seriennummer.isEmpty {
            return "\(basis) · SN \(z.seriennummer)"
        }
        return basis
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

    private func einheitTitel(_ e: Wohneinheit) -> String {
        switch e.nutzungsart {
        case .gewerbe: return "\(e.bezeichnung) Gewerbe"
        case .leerstand: return "\(e.bezeichnung) Leerstand"
        default: return "\(e.bezeichnung) Wohnung"
        }
    }

    private func formatiere(_ value: Decimal, einheit: String) -> String {
        let zahl = NSDecimalNumber(decimal: value).stringValue
        if einheit.isEmpty { return zahl }
        return "\(zahl) \(einheit)"
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
