//
//  ZaehlerstaendeView.swift
//  NebenkostenApp — UI/Kacheln
//
//  Kachel-Screen der Zaehlerstaende-Kategorie. Variante A aus der
//  Bestandsanalyse — bauen auf den bestehenden Zaehler-Components
//  auf, ohne den Tab-Root (ZaehlerView) mitzuberuehren.
//
//  Layout:
//    - Fortschrittsbalken oben: „X von Y vollstaendig"
//      (Zaehler mit Anfangs- UND Endstand / alle Zaehler,
//       WMZ-Plausi ist kein Zaehler → faellt natuerlich raus)
//    - ScrollView: CollapsibleSection pro Medium (MediumMeta-
//      Reihenfolge), leere Medien werden ausgeblendet.
//    - Bottom-CTA: „Zaehlerstand erfassen" springt direkt zum
//      naechsten offenen Zaehler (Spec §4). Alle voll → disabled
//      mit „Alle vollstaendig".
//

import SwiftUI
import SwiftData

struct ZaehlerstaendeView: View {
    @Environment(ScopeManager.self) private var scope
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Immobilie.erstelltAm) private var immobilien: [Immobilie]

    @State private var erfassenZaehler: Zaehler?

    // MARK: - Abgeleitet

    private var aktiveImmobilie: Immobilie? {
        if let id = scope.aktuelleImmobilieID,
           let match = immobilien.first(where: { $0.id == id }) {
            return match
        }
        return immobilien.first
    }

    private var aktivePeriode: Abrechnungsperiode? {
        let perioden = (aktiveImmobilie?.perioden ?? [])
            .sorted(by: { $0.bis > $1.bis })
        let heute = Date()
        return perioden.first(where: { $0.bis < heute }) ?? perioden.first
    }

    private var alleZaehler: [Zaehler] {
        let haupt = aktiveImmobilie?.hauptzaehler ?? []
        let wohnung = (aktiveImmobilie?.wohneinheiten ?? [])
            .flatMap { $0.zaehler ?? [] }
        return haupt + wohnung
    }

    private var gruppen: [(medium: Medium, zaehler: [Zaehler])] {
        let grouped = Dictionary(grouping: alleZaehler) { $0.medium }
        return MediumMeta.reihenfolge.compactMap { medium in
            guard let liste = grouped[medium], !liste.isEmpty else { return nil }
            let sortiert = liste.sorted { lhs, rhs in
                let lh = lhs.wohneinheit == nil ? 0 : 1
                let rh = rhs.wohneinheit == nil ? 0 : 1
                if lh != rh { return lh < rh }
                return ScopeFilter.einheitRang(lhs.wohneinheit?.bezeichnung ?? "")
                    < ScopeFilter.einheitRang(rhs.wohneinheit?.bezeichnung ?? "")
            }
            return (medium: medium, zaehler: sortiert)
        }
    }

    private var prozent: Int {
        let gesamt = alleZaehler.count
        guard gesamt > 0 else { return 0 }
        return Int(Double(vollstaendigeAnzahl) / Double(gesamt) * 100)
    }

    private var vollstaendigeAnzahl: Int {
        guard let p = aktivePeriode else { return 0 }
        return alleZaehler.filter { rowStatus($0, periode: p) == .gruen }.count
    }

    /// Spec §4: erst Zaehler ohne Anfangsstand, dann ohne Endstand.
    /// Aus unserer Row-Status-Logik heisst das: `rot` (kein Stand)
    /// zuerst, danach `gelb` (genau ein Stand).
    private var naechsterOffener: Zaehler? {
        guard let p = aktivePeriode else { return nil }
        if let z = alleZaehler.first(where: { rowStatus($0, periode: p) == .rot }) {
            return z
        }
        return alleZaehler.first(where: { rowStatus($0, periode: p) == .gelb })
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                fortschrittHeader
                if alleZaehler.isEmpty {
                    leerZustand
                } else {
                    gruppenListe
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 100)
        }
        .overlay(alignment: .bottom) { bottomCTA }
        .background(DesignTokens.bgAppCompact)
        .navigationTitle("Zählerstände")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $erfassenZaehler) { z in
            NavigationStack { ZaehlerstandErfassenView(zaehler: z) }
        }
    }

    // MARK: - Header

    private var fortschrittHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Vollständigkeit")
                    .appFont(AppFont.Basis.kicker())
                    .foregroundStyle(DesignTokens.textSecondary)
                Spacer()
                Text("\(prozent) %")
                    .appFont(AppFont.Basis.monoBodySemi())
                    .foregroundStyle(CompletionFarbe.fuer(prozent: prozent))
            }
            balken
            Text("\(vollstaendigeAnzahl) von \(alleZaehler.count) Zähler\(alleZaehler.count == 1 ? "" : "n") vollständig")
                .appFont(AppFont.Basis.caption())
                .foregroundStyle(DesignTokens.textTertiary)
        }
    }

    private var balken: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(CompletionFarbe.fuer(prozent: prozent).opacity(0.15))
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(CompletionFarbe.fuer(prozent: prozent))
                    .frame(width: max(6, geo.size.width * CGFloat(prozent) / 100))
            }
        }
        .frame(height: 6)
    }

    // MARK: - Gruppen

    private var gruppenListe: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(gruppen, id: \.medium) { gruppe in
                CollapsibleSection(
                    titel: MediumMeta.gruppenName(gruppe.medium),
                    persistKey: "zaehlerstaende.\(gruppe.medium.rawValue).offen",
                    defaultOffen: true
                ) {
                    VStack(spacing: 0) {
                        ForEach(Array(gruppe.zaehler.enumerated()), id: \.element.id) { idx, z in
                            ZaehlerRow(
                                zaehler: z,
                                periode: aktivePeriode,
                                onTap: { erfassenZaehler = z }
                            )
                            if idx < gruppe.zaehler.count - 1 {
                                DividerLine()
                            }
                        }
                    }
                }
            }
        }
    }

    private var leerZustand: some View {
        VStack(spacing: 12) {
            Image(systemName: "gauge.with.dots.needle.0percent")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(DesignTokens.textSecondary)
            Text("Keine Zähler erfasst")
                .appFont(AppFont.Basis.bodySemi())
                .foregroundStyle(DesignTokens.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Bottom-CTA

    private var bottomCTA: some View {
        VStack(spacing: 0) {
            DividerLine()
            Button {
                if let z = naechsterOffener { erfassenZaehler = z }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: naechsterOffener == nil
                          ? "checkmark.circle.fill"
                          : "gauge.medium")
                        .font(.system(size: 15, weight: .semibold))
                    Text(naechsterOffener == nil
                         ? "Alle vollständig"
                         : "Zählerstand erfassen")
                        .appFont(AppFont.Basis.bodySemi())
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(naechsterOffener == nil
                            ? DesignTokens.statusOk
                            : DesignTokens.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(naechsterOffener == nil)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .background(DesignTokens.bgAppCompact)
    }
}

// MARK: - Row

/// Eine Zaehler-Zeile mit Row-weitem Status-Dot + A/E-Werten rechts.
/// Status:
///   gruen — Anfangs- UND Endstand erfasst
///   gelb  — genau ein Stand erfasst
///   rot   — kein Stand erfasst
///
/// „Anfang" = erster Stand in Periode (sortiert nach ablesedatum),
/// „Ende" = letzter. Bei nur einem Stand wird er als Anfang
/// angezeigt, Ende bleibt leer (User hat Endstand noch nicht
/// eingegeben).
fileprivate struct ZaehlerRow: View {
    let zaehler: Zaehler
    let periode: Abrechnungsperiode?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Circle()
                    .fill(statusFarbe)
                    .frame(width: 10, height: 10)
                    .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 2 }
                VStack(alignment: .leading, spacing: 2) {
                    Text(zaehler.anzeigename)
                        .appFont(AppFont.Basis.bodySemi())
                        .foregroundStyle(DesignTokens.text)
                        .lineLimit(1)
                    Text(zaehler.anzeigetyp)
                        .appFont(AppFont.Basis.caption())
                        .foregroundStyle(DesignTokens.textSecondary)
                }
                Spacer(minLength: 8)
                staendeBlock
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var staendeBlock: some View {
        VStack(alignment: .trailing, spacing: 2) {
            standZeile(label: "A", wert: anfangText)
            standZeile(label: "E", wert: endText)
        }
    }

    private func standZeile(label: String, wert: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .appFont(AppFont.Basis.caption())
                .foregroundStyle(DesignTokens.textSecondary)
            Text(wert)
                .appFont(AppFont.Basis.monoCaption())
                .foregroundStyle(DesignTokens.text)
        }
    }

    // MARK: - Daten

    private var erfassteStaendeInPeriode: [Zaehlerstand] {
        guard let p = periode else { return [] }
        return (zaehler.staende ?? [])
            .filter {
                $0.ablesedatum >= p.von
                    && $0.ablesedatum <= p.bis
                    && $0.erfasstAm != nil
            }
            .sorted { $0.ablesedatum < $1.ablesedatum }
    }

    private var anfangText: String {
        if let erster = erfassteStaendeInPeriode.first {
            return Formatting.zaehlerstand(erster.stand, einheit: zaehler.einheit)
        }
        return "—"
    }

    private var endText: String {
        let stds = erfassteStaendeInPeriode
        if stds.count >= 2, let letzter = stds.last {
            return Formatting.zaehlerstand(letzter.stand, einheit: zaehler.einheit)
        }
        return "—"
    }

    private var statusFarbe: Color {
        switch erfassteStaendeInPeriode.count {
        case 0:  return DesignTokens.statusError
        case 1:  return DesignTokens.statusWarn
        default: return DesignTokens.statusOk
        }
    }
}

// MARK: - Row-Status-Helfer (fuer ZaehlerstaendeView)

fileprivate enum RowStatus { case gruen, gelb, rot }

@MainActor
fileprivate func rowStatus(
    _ zaehler: Zaehler,
    periode: Abrechnungsperiode
) -> RowStatus {
    let count = (zaehler.staende ?? [])
        .filter {
            $0.ablesedatum >= periode.von
                && $0.ablesedatum <= periode.bis
                && $0.erfasstAm != nil
        }
        .count
    switch count {
    case 0:  return .rot
    case 1:  return .gelb
    default: return .gruen
    }
}
