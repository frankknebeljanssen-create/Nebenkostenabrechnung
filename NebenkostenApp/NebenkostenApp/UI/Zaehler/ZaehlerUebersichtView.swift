//
//  ZaehlerUebersichtView.swift
//  NebenkostenApp — UI/Zaehler
//
//  Eigenständiger Zähler-Screen: oben Zusammenfassungs-Card mit
//  Fortschritt, darunter Zähler gruppiert nach Medium. Erreichbar
//  über den NavigationLink der Zähler-Kachel im Dashboard.
//

import SwiftUI
import SwiftData

struct ZaehlerUebersichtsZiel: Hashable {
    let immobilie: Immobilie
}

struct ZaehlerUebersichtView: View {
    @Bindable var immobilie: Immobilie

    @Environment(ScopeManager.self) private var scopeManager

    @State private var gewaehltePeriodeID: UUID?
    @State private var navigationZiel: Zaehler?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                fortschrittsCard
                ForEach(gruppen, id: \.titel) { gruppe in
                    gruppenCard(gruppe)
                }
                if let naechster = naechsterOffenerZaehler {
                    quickActionCard(zaehler: naechster)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ScopePickerToolbar(immobilie: immobilie)
            ToolbarItem(placement: .primaryAction) {
                periodeMenu
            }
        }
        .scopeIndicator(immobilie: immobilie)
        .navigationDestination(item: $navigationZiel) { zaehler in
            ZaehlerDetailView(zaehler: zaehler)
        }
        .onAppear(perform: waehleDefaultPeriode)
    }

    // MARK: - Daten

    /// Alle Zähler der Immobilie (Einheit + Haupt).
    private var alleZaehler: [Zaehler] {
        let einheit = (immobilie.wohneinheiten ?? []).flatMap { $0.zaehler ?? [] }
        let haupt = immobilie.hauptzaehler ?? []
        return einheit + haupt
    }

    /// Scope-gefilterte Sicht — siehe `ScopeFilter.sichtbareZaehler`.
    private var sichtbareZaehler: [Zaehler] {
        ScopeFilter.sichtbareZaehler(immobilie: immobilie, scope: scopeManager.scope)
    }

    private var perioden: [Abrechnungsperiode] {
        (immobilie.perioden ?? []).sorted(by: { $0.bis > $1.bis })
    }

    private var aktivePeriode: Abrechnungsperiode? {
        if let id = gewaehltePeriodeID,
           let t = perioden.first(where: { $0.id == id }) {
            return t
        }
        let heute = Date()
        return perioden.first(where: { $0.bis < heute }) ?? perioden.first
    }

    private func waehleDefaultPeriode() {
        if gewaehltePeriodeID == nil {
            gewaehltePeriodeID = aktivePeriode?.id
        }
    }

    // MARK: - Fortschritts-Card

    /// (erfasst, erwartet, offeneAnfangsstaende, offeneEndstaende)
    private var fortschritt: (ist: Int, soll: Int, offeneA: Int, offeneE: Int) {
        guard let p = aktivePeriode else {
            return (0, 0, 0, 0)
        }
        var ist = 0
        var offA = 0
        var offE = 0
        for z in sichtbareZaehler {
            let staendeInP = (z.staende ?? [])
                .filter { $0.ablesedatum >= p.von && $0.ablesedatum <= p.bis }
            let n = staendeInP.count
            ist += min(n, 2)
            if n == 0 { offA += 1; offE += 1 }
            else if n == 1 { offE += 1 }
        }
        let soll = sichtbareZaehler.count * 2
        return (ist, soll, offA, offE)
    }

    private var fortschrittsCard: some View {
        let f = fortschritt
        let prozent = f.soll == 0 ? 1.0 : Double(f.ist) / Double(f.soll)
        let fertig = f.soll > 0 && f.ist >= f.soll

        return VStack(alignment: .leading, spacing: 10) {
            if fertig {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                    Text("Alle Zählerstände erfasst für diese Periode")
                        .font(.callout.weight(.semibold))
                    Spacer()
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(f.ist) von \(f.soll)")
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                    Text("Zählerständen erfasst")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            balken(prozent: prozent, fertig: fertig)
            if !fertig {
                Text(offenText(anfangs: f.offeneA, ende: f.offeneE))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func balken(prozent: Double, fertig: Bool) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.18))
                RoundedRectangle(cornerRadius: 6)
                    .fill(fertig ? Color.green : Color.orange)
                    .frame(width: proxy.size.width * max(0, min(1, prozent)))
                    .animation(.easeInOut(duration: 0.3), value: prozent)
            }
        }
        .frame(height: 10)
    }

    private func offenText(anfangs: Int, ende: Int) -> String {
        switch (anfangs, ende) {
        case (0, 0): return ""
        case (0, let e): return "Es fehlt noch \(e == 1 ? "ein Endstand" : "\(e) Endstände")."
        case (let a, 0): return "Es \(a == 1 ? "fehlt ein Anfangsstand" : "fehlen \(a) Anfangsstände")."
        default:
            let a = anfangs == 1 ? "1 Anfangsstand" : "\(anfangs) Anfangsstände"
            let e = ende == 1 ? "1 Endstand" : "\(ende) Endstände"
            return "Es fehlen noch \(a) und \(e)."
        }
    }

    // MARK: - Gruppen

    private struct Gruppe {
        let titel: String
        let symbol: String
        let tint: Color
        let zaehler: [Zaehler]
        let rang: Int
    }

    private var gruppen: [Gruppe] {
        let alle = sichtbareZaehler
        var buckets: [Int: (titel: String, symbol: String, tint: Color, zaehler: [Zaehler])] = [:]

        for z in alle {
            let (titel, symbol, tint, rang) = klassifizierung(z)
            var eintrag = buckets[rang] ?? (titel, symbol, tint, [])
            eintrag.zaehler.append(z)
            buckets[rang] = eintrag
        }

        return buckets
            .map { (rang, v) -> Gruppe in
                Gruppe(titel: v.titel, symbol: v.symbol, tint: v.tint,
                       zaehler: v.zaehler.sorted { $0.bezeichnung < $1.bezeichnung },
                       rang: rang)
            }
            .sorted { $0.rang < $1.rang }
    }

    private func klassifizierung(_ z: Zaehler) -> (String, String, Color, Int) {
        switch z.medium {
        case .strom:         return ("Strom",       "bolt.fill",    .orange, 1)
        case .warmwasser:    return ("Warmwasser",  "drop.fill",    .red,    2)
        case .kaltwasser:    return ("Kaltwasser",  "drop",         .blue,   3)
        case .waermeenergie: return ("Wärmemenge",  "flame",        .orange, 4)
        case .gas:           return ("Gas",         "flame.fill",   .yellow, 5)
        case .oel:           return ("Öl",          "drop.triangle",.brown,  6)
        }
    }

    private func gruppenCard(_ gruppe: Gruppe) -> some View {
        let volls = vollstaendigeCount(gruppe.zaehler)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: gruppe.symbol)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(gruppe.tint)
                    .frame(width: 22)
                Text("\(gruppe.titel) (\(gruppe.zaehler.count) Zähler)")
                    .font(.callout.weight(.semibold))
                Spacer()
                Text("\(volls)/\(gruppe.zaehler.count)")
                    .font(.caption.monospacedDigit())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 6)

            Divider().padding(.horizontal, 14)

            VStack(spacing: 0) {
                ForEach(Array(gruppe.zaehler.enumerated()), id: \.element.id) { idx, z in
                    Button {
                        navigationZiel = z
                    } label: {
                        ZaehlerSammelZeile(zaehler: z, periode: aktivePeriode)
                            .padding(.horizontal, 14)
                    }
                    .buttonStyle(.plain)
                    if idx < gruppe.zaehler.count - 1 {
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func vollstaendigeCount(_ liste: [Zaehler]) -> Int {
        guard let p = aktivePeriode else { return 0 }
        return liste.filter { z in
            let n = (z.staende ?? [])
                .filter { $0.ablesedatum >= p.von && $0.ablesedatum <= p.bis }
                .count
            return n >= 2
        }.count
    }

    // MARK: - Quick-Action

    private var naechsterOffenerZaehler: Zaehler? {
        guard let p = aktivePeriode else { return nil }
        return sichtbareZaehler.first { z in
            let n = (z.staende ?? [])
                .filter { $0.ablesedatum >= p.von && $0.ablesedatum <= p.bis }
                .count
            return n < 2
        }
    }

    private func quickActionCard(zaehler: Zaehler) -> some View {
        Button {
            navigationZiel = zaehler
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                Text("Nächsten offenen Zähler erfassen")
                    .font(.callout.weight(.semibold))
                Spacer()
                Text(zaehler.bezeichnung.isEmpty ? "—" : zaehler.bezeichnung)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Color.accentColor.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Periode-Menu

    private var periodeMenu: some View {
        Menu {
            if perioden.isEmpty {
                Text("Keine Perioden angelegt")
            } else {
                ForEach(perioden) { p in
                    Button {
                        gewaehltePeriodeID = p.id
                    } label: {
                        HStack {
                            Text(ObjektDashboardViewModel.formatiere(p))
                            if p.id == aktivePeriode?.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(aktivePeriode.map(ObjektDashboardViewModel.formatiere) ?? "Periode")
                    .font(.caption.weight(.medium))
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
        }
    }
}
