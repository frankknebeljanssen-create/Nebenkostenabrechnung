//
//  AbrechnungsKachelView.swift
//  NebenkostenApp — UI/Kacheln
//
//  Kachel-Screen der Abrechnungs-Kategorie. Wird aus
//  `KachelansichtView` per `NavigationLink` geoeffnet.
//
//  Layout:
//    - Periode-Chips (ScrollView .horizontal), nur wenn >=2
//      Perioden vorhanden.
//    - Status-Hero-Block: gruen „Bereit zur Abrechnung" bei 100 %,
//      sonst orange/rot „N Punkte fehlen noch" + Top-3-Blocker
//      als tappbare Sprungziele.
//    - Pro aktivem Mietverhaeltnis eine `MieterAbrechnungCard`
//      mit Saldo-Vorschau (Guthaben gruen / Nachzahlung rot /
//      Ausgeglichen neutral). Tap → `AbrechnungDetailView`.
//    - Bottom-CTA „Abrechnung erstellen" — disabled solange
//      Blocker offen. Batch-Erstellung folgt im naechsten Commit.
//
//  Der Tab-Root `AbrechnungenView` bleibt unveraendert — diese
//  Kachel ist eine alternative Perspektive (Fokus: naechster
//  Schritt), der Tab bietet Perioden-Uebersicht.
//

import SwiftUI
import SwiftData

struct AbrechnungsKachelView: View {
    @Environment(ScopeManager.self) private var scope
    @Environment(AppShellRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Immobilie.erstelltAm) private var immobilien: [Immobilie]
    @Query private var users: [AppUser]

    /// Aktuell gewaehlte Periode. Default: die letzte
    /// abgeschlossene oder sonst die juengste Periode.
    @State private var gewaehltePeriodeID: UUID?
    @State private var auswahl: Mieterabrechnung?

    // MARK: - Abgeleitet

    private var aktiveImmobilie: Immobilie? {
        if let id = scope.aktuelleImmobilieID,
           let match = immobilien.first(where: { $0.id == id }) {
            return match
        }
        return immobilien.first
    }

    private var allePerioden: [Abrechnungsperiode] {
        (aktiveImmobilie?.perioden ?? []).sorted { $0.bis > $1.bis }
    }

    private var aktivePeriode: Abrechnungsperiode? {
        if let id = gewaehltePeriodeID,
           let match = allePerioden.first(where: { $0.id == id }) {
            return match
        }
        let heute = Date()
        return allePerioden.first(where: { $0.bis < heute }) ?? allePerioden.first
    }

    private var anforderungen: [AnforderungMitStatus] {
        guard let immobilie = aktiveImmobilie,
              let p = aktivePeriode else { return [] }
        return VollstaendigkeitsPruefung.pruefe(immobilie: immobilie, periode: p)
    }

    private var zusammenfassung: VollstaendigkeitsPruefung.Zusammenfassung {
        VollstaendigkeitsPruefung.zusammenfassung(fuer: anforderungen)
    }

    private var prozent: Int { zusammenfassung.completionProzent }

    private var istBereit: Bool { prozent == 100 }

    /// Bis zu drei offene Blocker-Anforderungen mit Sprungziel —
    /// konsistent zu Home-„Naechste Schritte". Warnungen (WMZ-
    /// Plausi, §35a) werden rausgefiltert — sie blockieren die
    /// Abrechnung nicht, gehoeren also nicht in diese Liste.
    private var top3Blocker: [AnforderungMitStatus] {
        let offen = anforderungen.filter {
            $0.sprungZiel != nil
                && $0.status != .erfuellt
                && $0.status != .nichtErwartet
                && $0.schwere == .blocker
        }
        let sortiert = offen.sorted { lhs, rhs in
            kategorieRang(lhs.anforderung.kategorie)
                < kategorieRang(rhs.anforderung.kategorie)
        }
        return Array(sortiert.prefix(3))
    }

    private func kategorieRang(_ k: AnforderungsKategorie) -> Int {
        switch k {
        case .stammdaten:   return 0
        case .zaehlerstand: return 1
        case .rechnung:     return 2
        }
    }

    private var mieterabrechnungen: [Mieterabrechnung] {
        guard let immobilie = aktiveImmobilie,
              let p = aktivePeriode else { return [] }
        // AbrechnungsService wirft bei Blockern — die fangen wir,
        // die UI zeigt dann den Status-Hero-Block statt Mieter-Cards.
        return (try? AbrechnungsService.aggregiere(periode: p, immobilie: immobilie)) ?? []
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if allePerioden.count >= 2 {
                    periodenChips
                }
                statusHero
                if istBereit && !mieterabrechnungen.isEmpty {
                    mieterListe
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 120)
        }
        .overlay(alignment: .bottom) { bottomCTA }
        .background(DesignTokens.bgAppCompact)
        .navigationTitle("Abrechnung")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $auswahl) { ma in
            NavigationStack {
                AbrechnungDetailView(
                    abrechnung: ma,
                    periode: aktivePeriode.map { Formatting.periode($0.von, $0.bis) } ?? "",
                    warnungen: warnungenZurPeriode,
                    pdfPeriode: aktivePeriode,
                    pdfImmobilie: aktiveImmobilie,
                    pdfUser: users.first
                )
            }
        }
    }

    /// Warnungen (nicht blockierend, z.B. WMZ-Plausi, §35a-Lohn)
    /// werden als Meta an `AbrechnungDetailView` uebergeben.
    private var warnungenZurPeriode: [AnforderungMitStatus] {
        anforderungen.filter { $0.schwere == .warnung }
    }

    // MARK: - Periode-Chips

    private var periodenChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(allePerioden) { p in
                    chip(fuer: p)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func chip(fuer p: Abrechnungsperiode) -> some View {
        let istAktiv = aktivePeriode?.id == p.id
        let jahr = Calendar(identifier: .gregorian).component(.year, from: p.bis)
        return Button {
            gewaehltePeriodeID = p.id
        } label: {
            HStack(spacing: 6) {
                if p.abgeschlossen {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(istAktiv ? Color.white : DesignTokens.statusOk)
                }
                Text("\(jahr)")
                    .appFont(AppFont.Basis.captionMedium())
            }
            .foregroundStyle(istAktiv ? Color.white : DesignTokens.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(istAktiv ? DesignTokens.accent : DesignTokens.bgSurface)
            .overlay(
                Capsule()
                    .stroke(istAktiv ? Color.clear : DesignTokens.separator, lineWidth: 0.5)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Status-Hero

    @ViewBuilder
    private var statusHero: some View {
        if istBereit {
            heroBereit
        } else if top3Blocker.isEmpty {
            heroLeer
        } else {
            heroBlockiert
        }
    }

    private var heroBereit: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(DesignTokens.statusOk)
            Text("Bereit zur Abrechnung")
                .appFont(AppFont.Basis.bodySemi())
                .foregroundStyle(DesignTokens.text)
            Text("Alle Pflichtdaten vollständig.")
                .appFont(AppFont.Basis.caption())
                .foregroundStyle(DesignTokens.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 16)
        .background(DesignTokens.statusOkSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var heroBlockiert: some View {
        let offenGesamt = anforderungen.filter {
            $0.schwere == .blocker && $0.status != .erfuellt && $0.status != .nichtErwartet
        }.count
        let ist100OhneBlocker = offenGesamt == 0
        let fill: Color = ist100OhneBlocker
            ? DesignTokens.statusWarnSoft
            : DesignTokens.statusErrorSoft
        let akzent: Color = ist100OhneBlocker
            ? DesignTokens.statusWarn
            : DesignTokens.statusError
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(akzent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(offenGesamt) Punkt\(offenGesamt == 1 ? "" : "e") fehl\(offenGesamt == 1 ? "t" : "en") noch")
                        .appFont(AppFont.Basis.bodySemi())
                        .foregroundStyle(DesignTokens.text)
                    Text("Ohne diese Daten kann keine finale Abrechnung erstellt werden.")
                        .appFont(AppFont.Basis.caption())
                        .foregroundStyle(DesignTokens.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            VStack(spacing: 0) {
                ForEach(Array(top3Blocker.enumerated()), id: \.element.anforderung.id) { idx, a in
                    blockerRow(a)
                    if idx < top3Blocker.count - 1 {
                        DividerLine().padding(.leading, 28)
                    }
                }
            }
            .background(DesignTokens.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            if offenGesamt > top3Blocker.count {
                Text("+ \(offenGesamt - top3Blocker.count) weitere — erscheinen nach Klärung der ersten.")
                    .appFont(AppFont.Basis.smallCaption())
                    .foregroundStyle(DesignTokens.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fill)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func blockerRow(_ a: AnforderungMitStatus) -> some View {
        Button {
            if let ziel = a.sprungZiel {
                router.springe(zu: ziel)
                dismiss()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignTokens.accent)
                Text(a.anforderung.titel)
                    .appFont(AppFont.Basis.body())
                    .foregroundStyle(DesignTokens.text)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var heroLeer: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(DesignTokens.textSecondary)
            Text("Keine Periode ausgewählt")
                .appFont(AppFont.Basis.bodySemi())
                .foregroundStyle(DesignTokens.textSecondary)
            Text("Legen Sie im Stammdaten-Bereich eine Abrechnungsperiode an.")
                .appFont(AppFont.Basis.caption())
                .foregroundStyle(DesignTokens.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
        .background(DesignTokens.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Mieter-Liste

    private var mieterListe: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Einheiten")
            VStack(spacing: 8) {
                ForEach(mieterabrechnungen) { ma in
                    MieterAbrechnungCard(
                        abrechnung: ma,
                        farbe: einheitFarbe(fuer: ma),
                        onTap: { auswahl = ma }
                    )
                }
            }
        }
    }

    private func einheitFarbe(fuer ma: Mieterabrechnung) -> Color {
        guard let einheit = (aktiveImmobilie?.wohneinheiten ?? [])
            .first(where: { $0.bezeichnung == ma.einheitBezeichnung })
        else { return DesignTokens.unitObjekt }
        return ScopeFarbe.farbe(fuer: einheit)
    }

    // MARK: - Bottom-CTA

    private var bottomCTA: some View {
        VStack(spacing: 0) {
            DividerLine()
            Button {
                // Batch-Erstellung folgt im naechsten Commit.
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: ctaIcon)
                        .font(.system(size: 15, weight: .semibold))
                    Text(ctaText)
                        .appFont(AppFont.Basis.bodySemi())
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(istBereit ? DesignTokens.accent : DesignTokens.textQuaternary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!istBereit)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .background(DesignTokens.bgAppCompact)
    }

    private var ctaIcon: String {
        if aktivePeriode?.abgeschlossen == true {
            return "checkmark.seal.fill"
        }
        return istBereit ? "doc.text.fill" : "lock.fill"
    }

    private var ctaText: String {
        if aktivePeriode?.abgeschlossen == true {
            return "Abrechnung abgeschlossen"
        }
        return istBereit ? "Abrechnung erstellen" : "Abrechnung erstellen · gesperrt"
    }
}

// MARK: - MieterAbrechnungCard

fileprivate struct MieterAbrechnungCard: View {
    let abrechnung: Mieterabrechnung
    let farbe: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                UnitBalken(farbe: farbe)
                    .frame(width: 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mieterTitel)
                        .appFont(AppFont.Basis.bodySemi())
                        .foregroundStyle(DesignTokens.text)
                        .lineLimit(1)
                    Text(abrechnung.einheitBezeichnung)
                        .appFont(AppFont.Basis.caption())
                        .foregroundStyle(DesignTokens.textSecondary)
                }
                .padding(.leading, 12)
                Spacer(minLength: 8)
                saldoBlock
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignTokens.textTertiary)
                    .padding(.leading, 10)
                    .padding(.trailing, 14)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.bgSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(DesignTokens.separator, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var mieterTitel: String {
        let name = abrechnung.mieterName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Einheit" : name
    }

    @ViewBuilder
    private var saldoBlock: some View {
        let saldo = abrechnung.saldoEuro
        VStack(alignment: .trailing, spacing: 2) {
            Text(saldoLabel(saldo))
                .appFont(AppFont.Basis.caption())
                .foregroundStyle(saldoFarbe(saldo))
            Text(Formatting.euro(abs(saldo)))
                .appFont(AppFont.Basis.monoBodySemi())
                .foregroundStyle(saldoFarbe(saldo))
        }
    }

    private func saldoLabel(_ saldo: Decimal) -> String {
        if saldo > 0  { return "Nachzahlung" }
        if saldo < 0  { return "Guthaben" }
        return "Ausgeglichen"
    }

    private func saldoFarbe(_ saldo: Decimal) -> Color {
        if saldo > 0  { return DesignTokens.statusError }
        if saldo < 0  { return DesignTokens.statusOk }
        return DesignTokens.textSecondary
    }
}
