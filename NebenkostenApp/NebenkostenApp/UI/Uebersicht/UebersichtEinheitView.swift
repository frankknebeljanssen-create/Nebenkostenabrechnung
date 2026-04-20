//
//  UebersichtEinheitView.swift
//  NebenkostenApp — UI/Uebersicht
//
//  Einheit-Dashboard. Fünf Sections nach 02-dashboard-einheit.jpg:
//    1. Perioden-Hero (Vorauszahlungs-Summe als monoHero)
//    2. Mieter-Card (Name + Einzug + Mietertyp)
//    3. Zähler-Card (Medium-Icon, letzter Stand, Status)
//    4. Vorauszahlungs-Detail (Monatsbetrag · Monate · Summe)
//    5. Schnellaktionen
//
//  Grundsatz "keine geschätzten Werte": zeige ausschließlich
//  abrechnungs-neutrale Daten (gezahlte Vorauszahlungen, Zähler-
//  Status, Stammdaten). Ein Saldo-Hero kommt erst, wenn eine echte
//  Abrechnung dieser Einheit berechnet/gespeichert wurde.
//

import SwiftUI
import SwiftData

struct UebersichtEinheitView: View {
    let einheitId: String

    @Environment(ScopeManager.self) private var scope
    @Query(sort: \Immobilie.erstelltAm) private var immobilien: [Immobilie]

    @State private var zeigeScopePicker = false
    @State private var zeigeEinstellungen = false
    @State private var zeigeInspektor = false

    private var immobilie: Immobilie? { immobilien.first }

    private var einheit: Wohneinheit? {
        (immobilie?.wohneinheiten ?? []).first(where: {
            $0.bezeichnung.caseInsensitiveCompare(einheitId) == .orderedSame
        })
    }

    private var aktivePeriode: Abrechnungsperiode? {
        let perioden = (immobilie?.perioden ?? []).sorted(by: { $0.bis > $1.bis })
        let heute = Date()
        return perioden.first(where: { $0.bis < heute }) ?? perioden.first
    }

    private var aktivesMietverhaeltnis: Mietverhaeltnis? {
        (einheit?.mietverhaeltnisse ?? []).first { $0.auszugAm == nil }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                periodenHero
                mieterCard
                zaehlerCard
                vorauszahlungCard
                schnellaktionen
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(DesignTokens.bgApp)
        .appShellChrome(
            titel: einheitTitel,
            subtitel: einheitSubtitel,
            onAdresse: { zeigeScopePicker = true },
            onEinstellungen: { zeigeEinstellungen = true }
        )
        .sheet(isPresented: $zeigeScopePicker) { ScopePickerSheet() }
        .sheet(isPresented: $zeigeEinstellungen) { EinstellungenSheet() }
        .sheet(isPresented: $zeigeInspektor) { InspektorPlatzhalter() }
    }

    // MARK: - Perioden-Hero

    private var periodenHero: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Periode")
                        .appFont(AppFont.uppercaseLabel())
                        .foregroundStyle(DesignTokens.textTertiary)
                    Spacer()
                    StatusPill(text: statusPillText, style: statusPillStyle)
                }
                Text(Formatting.euro(vorauszahlungsSumme))
                    .appFont(AppFont.monoHero())
                    .foregroundStyle(DesignTokens.text)
                HStack(spacing: 6) {
                    Text("Vorauszahlungen \(jahrText)")
                        .appFont(AppFont.subtitle())
                        .foregroundStyle(DesignTokens.textSecondary)
                    if monateInPeriode > 0 {
                        Text("·")
                            .foregroundStyle(DesignTokens.textTertiary)
                        Text("\(monateInPeriode) Monate")
                            .appFont(AppFont.monoCaption())
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                }
                DividerLine().padding(.vertical, 2)
                periodenZeitraumZeile
            }
        }
    }

    private var periodenZeitraumZeile: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Abrechnungszeitraum")
                .appFont(AppFont.caption())
                .foregroundStyle(DesignTokens.textSecondary)
            Spacer()
            if let p = aktivePeriode {
                Text(Formatting.periode(p.von, p.bis))
                    .appFont(AppFont.monoCaption())
                    .foregroundStyle(DesignTokens.text)
            } else {
                Text("—")
                    .appFont(AppFont.monoCaption())
                    .foregroundStyle(DesignTokens.textTertiary)
            }
        }
    }

    // MARK: - Mieter-Card

    private var mieterCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Mieter")
            if let mv = aktivesMietverhaeltnis {
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            UnitBalken(farbe: einheitFarbe)
                                .frame(height: 44)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mv.mieterName)
                                    .appFont(AppFont.bodySemi())
                                    .foregroundStyle(DesignTokens.text)
                                Text(mieterTypLabel(mv.mieterTyp))
                                    .appFont(AppFont.caption())
                                    .foregroundStyle(DesignTokens.textSecondary)
                            }
                            Spacer()
                        }
                        DividerLine()
                        HStack {
                            Text("Einzug")
                                .appFont(AppFont.caption())
                                .foregroundStyle(DesignTokens.textSecondary)
                            Spacer()
                            Text(Formatting.datum(mv.einzugAm))
                                .appFont(AppFont.monoCaption())
                                .foregroundStyle(DesignTokens.text)
                        }
                        if mv.anzahlPersonen > 0 {
                            HStack {
                                Text("Haushalt")
                                    .appFont(AppFont.caption())
                                    .foregroundStyle(DesignTokens.textSecondary)
                                Spacer()
                                Text("\(mv.anzahlPersonen) \(mv.anzahlPersonen == 1 ? "Person" : "Personen")")
                                    .appFont(AppFont.monoCaption())
                                    .foregroundStyle(DesignTokens.text)
                            }
                        }
                    }
                }
            } else {
                Card {
                    HStack {
                        StatusDot(status: .muted)
                        Text("Kein aktiver Mieter")
                            .appFont(AppFont.bodyMedium())
                            .foregroundStyle(DesignTokens.textSecondary)
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Zähler-Card

    private var zaehlerCard: some View {
        let liste = einheitZaehler
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Zähler") {
                if !liste.isEmpty {
                    Text("\(liste.count) Gerät\(liste.count == 1 ? "" : "e")")
                        .appFont(AppFont.monoCaption())
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }
            if liste.isEmpty {
                Card {
                    Text("Keine Zähler für diese Einheit erfasst.")
                        .appFont(AppFont.caption())
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(liste.enumerated()), id: \.element.id) { idx, z in
                        Row(
                            label: anzeigeNameZaehler(z),
                            subtitel: zaehlerDetailText(z),
                            chevron: false,
                            leading: {
                                Image(systemName: mediumSymbol(z.medium))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(einheitFarbe)
                                    .frame(width: 24, height: 24, alignment: .center)
                            },
                            trailing: {
                                StatusDot(status: zaehlerDotStatus(z))
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
        }
    }

    // MARK: - Vorauszahlung-Detail

    private var vorauszahlungCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Vorauszahlungen")
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Monatsbetrag")
                            .appFont(AppFont.caption())
                            .foregroundStyle(DesignTokens.textSecondary)
                        Spacer()
                        Text(Formatting.euro(monatsbetrag))
                            .appFont(AppFont.monoBody())
                            .foregroundStyle(DesignTokens.text)
                    }
                    DividerLine()
                    HStack {
                        Text("Monate in Periode")
                            .appFont(AppFont.caption())
                            .foregroundStyle(DesignTokens.textSecondary)
                        Spacer()
                        Text("\(monateInPeriode)")
                            .appFont(AppFont.monoBody())
                            .foregroundStyle(DesignTokens.text)
                    }
                    DividerLine()
                    HStack(alignment: .firstTextBaseline) {
                        Text("Summe")
                            .appFont(AppFont.bodySemi())
                            .foregroundStyle(DesignTokens.text)
                        Spacer()
                        Text(Formatting.euro(vorauszahlungsSumme))
                            .appFont(AppFont.monoLarge())
                            .foregroundStyle(DesignTokens.text)
                    }
                }
            }
        }
    }

    // MARK: - Schnellaktionen

    private var schnellaktionen: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Schnellaktionen")
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                aktionButton(titel: "Zählerstand erfassen",
                             symbol: "gauge.medium",
                             primary: true) {
                    // kommt in UI-2
                }
                aktionButton(titel: "Beleg scannen",
                             symbol: "camera.fill",
                             primary: false) {
                    // kommt in UI-2
                }
                aktionButton(titel: "Periode prüfen",
                             symbol: "checklist",
                             primary: false) {
                    zeigeInspektor = true
                }
                aktionButton(titel: "Zurück zum Haus",
                             symbol: "building.2",
                             primary: false) {
                    scope.current = .objekt
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

    private var einheitTitel: String {
        guard let e = einheit else { return einheitId }
        switch e.nutzungsart {
        case .gewerbe: return "\(e.bezeichnung) Gewerbe"
        case .leerstand: return "\(e.bezeichnung) Leerstand"
        default: return "\(e.bezeichnung) Wohnung"
        }
    }

    private var einheitSubtitel: String? {
        guard let e = einheit else { return nil }
        let flaeche = Formatting.m2(e.flaecheM2)
        if let mv = aktivesMietverhaeltnis {
            return "\(flaeche) · \(ScopeTexte.abkuerzungName(mv.mieterName))"
        }
        return flaeche
    }

    private var einheitFarbe: Color {
        guard let e = einheit else { return DesignTokens.unitObjekt }
        return ScopeFarbe.farbe(fuer: e)
    }

    private var jahrText: String {
        guard let p = aktivePeriode else { return "—" }
        let kal = Calendar(identifier: .gregorian)
        let von = kal.component(.year, from: p.von)
        let bis = kal.component(.year, from: p.bis)
        return von == bis ? "\(von)" : "\(von)/\(bis)"
    }

    private var monatsbetrag: Decimal {
        aktivesMietverhaeltnis?.vorauszahlungMonatEuro ?? 0
    }

    private var monateInPeriode: Int {
        guard let p = aktivePeriode, let mv = aktivesMietverhaeltnis else { return 0 }
        var kal = Calendar(identifier: .gregorian)
        kal.timeZone = TimeZone(identifier: "UTC")!
        // Überlappung: max(einzug, von) … min(auszug ?? bis, bis)
        let start = max(mv.einzugAm, p.von)
        let ende  = min(mv.auszugAm ?? p.bis, p.bis)
        guard ende >= start else { return 0 }
        let k = kal.dateComponents([.month], from: start, to: ende)
        return max((k.month ?? 0) + 1, 1)
    }

    private var vorauszahlungsSumme: Decimal {
        monatsbetrag * Decimal(monateInPeriode)
    }

    private var statusPillText: String {
        guard let p = aktivePeriode else { return "Keine Periode" }
        let heute = Date()
        if heute < p.von { return "Periode steht aus" }
        if heute <= p.bis { return "Periode läuft" }
        return "Abrechnung ausstehend"
    }

    private var statusPillStyle: StatusPill.Style {
        guard let p = aktivePeriode else { return .muted }
        let heute = Date()
        if heute < p.von { return .muted }
        if heute <= p.bis { return .accent }
        return .warn
    }

    // MARK: - Zähler-Helper

    private var einheitZaehler: [Zaehler] {
        (einheit?.zaehler ?? []).sorted { $0.medium.rawValue < $1.medium.rawValue }
    }

    private func anzeigeNameZaehler(_ z: Zaehler) -> String {
        if !z.bezeichnung.isEmpty { return z.bezeichnung }
        return mediumName(z.medium)
    }

    private func zaehlerDetailText(_ z: Zaehler) -> String {
        let basis = mediumName(z.medium)
        if let letzter = letzterStand(z) {
            let wert = NSDecimalNumber(decimal: letzter.stand).stringValue
            let datum = Formatting.datum(letzter.ablesedatum)
            let einheit = z.einheit.isEmpty ? "" : " \(z.einheit)"
            return "\(basis) · \(wert)\(einheit) · \(datum)"
        }
        if !z.seriennummer.isEmpty {
            return "\(basis) · SN \(z.seriennummer)"
        }
        return basis
    }

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

    private func mieterTypLabel(_ t: MieterTyp) -> String {
        switch t {
        case .wohnungsmieter: return "Wohnungsmieter"
        case .gewerbemieter:  return "Gewerbemieter"
        case .selbstnutzer:   return "Selbstnutzer"
        }
    }
}
