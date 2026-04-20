//
//  RechnungenView.swift
//  NebenkostenApp — UI/Rechnung
//
//  Rechnungen-Tab nach Design-Handoff. Drei Schichten:
//    1. Kennzahlen-Card — Anzahl, Summe, ungeprüfte der Periode.
//    2. Gruppierte Rechnungs-Liste in BetrKV-Reihenfolge,
//       Default: alle zugeklappt. Header = Icon + Name + Count +
//       Summe + Chevron. Body = Row pro Rechnung.
//    3. Footer-Hinweis im Einheit-Scope („Rechnungen betreffen
//       das gesamte Objekt, umgelegt je nach Schlüssel").
//
//  Neue Rechnung = "+"-Button in der NavBar-Toolbar via
//  AppShellChrome-Aktion; fehlt noch, deshalb Fallback-Button in
//  der Kennzahlen-Card.
//

import SwiftUI
import SwiftData

struct RechnungenView: View {
    @Environment(ScopeManager.self) private var scope
    @Query(sort: \Immobilie.erstelltAm) private var immobilien: [Immobilie]

    @State private var zeigeScopePicker = false
    @State private var zeigeEinstellungen = false
    @State private var zeigeNeu = false
    @State private var auswahl: Rechnung?
    @State private var aufgeklappt: Set<String> = []
    @State private var suchtext: String = ""

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
                if alleRechnungen.isEmpty {
                    leerZustand
                } else if gruppen.isEmpty {
                    sucheLeerZustand
                } else {
                    VStack(spacing: 10) {
                        ForEach(gruppen) { gruppe in
                            gruppenCard(gruppe)
                        }
                    }
                }
                scopeHinweis
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(DesignTokens.bgApp)
        .searchable(text: $suchtext, prompt: "Lieferant, Nummer oder Betrag")
        .appShellChrome(
            titel: "Rechnungen",
            subtitel: subtitel,
            onAdresse: { zeigeScopePicker = true },
            onEinstellungen: { zeigeEinstellungen = true }
        )
        .sheet(isPresented: $zeigeScopePicker) { ScopePickerSheet() }
        .sheet(isPresented: $zeigeEinstellungen) { EinstellungenSheet() }
        .sheet(isPresented: $zeigeNeu) {
            if let immobilie {
                RechnungEditView(modus: .neu(immobilie: immobilie))
            }
        }
        .sheet(item: $auswahl) { r in
            RechnungEditView(modus: .bearbeiten(r))
        }
    }

    // MARK: - Kennzahlen

    private var kennzahlenCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Periode")
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
                        label: "Rechnungen",
                        wert: "\(rechnungenInPeriode.count)",
                        detail: "in dieser Periode"
                    ),
                    rechts: StatBlock(
                        label: "Bruttosumme",
                        wert: Formatting.euro(summeInPeriode),
                        detail: gepruftDetail
                    )
                )
                DividerLine()
                Button {
                    zeigeNeu = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Neue Rechnung anlegen")
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

    // MARK: - Gruppen-Card

    private func gruppenCard(_ gruppe: Gruppe) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sektionHeader(gruppe)
            if aufgeklappt.contains(gruppe.schluessel) {
                DividerLine()
                VStack(spacing: 0) {
                    ForEach(Array(gruppe.rechnungen.enumerated()), id: \.element.id) { idx, r in
                        Row(
                            label: r.lieferant.isEmpty ? "Ohne Lieferant" : r.lieferant,
                            subtitel: zeilenSubtitel(r),
                            chevron: true,
                            action: { auswahl = r },
                            leading: {
                                StatusDot(status: statusDot(r))
                                    .frame(width: 24, height: 24, alignment: .center)
                            },
                            trailing: {
                                Text(Formatting.euro(r.betragBruttoEuro))
                                    .appFont(AppFont.monoBody())
                                    .foregroundStyle(DesignTokens.text)
                            }
                        )
                        if idx < gruppe.rechnungen.count - 1 {
                            DividerLine().padding(.leading, 14)
                        }
                    }
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

    private func sektionHeader(_ gruppe: Gruppe) -> some View {
        Button {
            toggle(gruppe.schluessel)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: Self.symbolFuer(gruppe.schluessel))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DesignTokens.accent)
                    .frame(width: 24, height: 24, alignment: .center)
                VStack(alignment: .leading, spacing: 2) {
                    Text(gruppe.schluessel == "ohne" ? "Ohne Kostenart" : gruppe.schluessel)
                        .appFont(AppFont.bodySemi())
                        .foregroundStyle(DesignTokens.text)
                    Text("\(gruppe.rechnungen.count) Rechnung\(gruppe.rechnungen.count == 1 ? "" : "en")")
                        .appFont(AppFont.caption())
                        .foregroundStyle(DesignTokens.textSecondary)
                }
                Spacer(minLength: 8)
                Text(Formatting.euro(gruppe.summe))
                    .appFont(AppFont.monoBody())
                    .foregroundStyle(DesignTokens.text)
                Image(systemName: aufgeklappt.contains(gruppe.schluessel) ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func zeilenSubtitel(_ r: Rechnung) -> String {
        var parts: [String] = []
        if !r.rechnungsnummer.isEmpty { parts.append(r.rechnungsnummer) }
        parts.append(Formatting.datum(r.rechnungsdatum))
        if let lohn = r.lohnanteilBruttoEuro {
            parts.append("Lohn \(Formatting.euro(lohn))")
        }
        return parts.joined(separator: " · ")
    }

    private func statusDot(_ r: Rechnung) -> StatusDot.Status {
        if let ka = r.kostenart, ka.paragraph35a, r.lohnanteilBruttoEuro == nil {
            return .warn
        }
        if !r.geprueft { return .warn }
        return .ok
    }

    // MARK: - Scope-Hinweis

    @ViewBuilder
    private var scopeHinweis: some View {
        if case .einheit = scope.current {
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.textTertiary)
                Text("Rechnungen betreffen das gesamte Objekt und werden je nach Umlageschlüssel auf die Einheiten verteilt.")
                    .appFont(AppFont.caption())
                    .foregroundStyle(DesignTokens.textTertiary)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Leer-Zustände

    private var leerZustand: some View {
        Card {
            VStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 28))
                    .foregroundStyle(DesignTokens.textTertiary)
                Text("Noch keine Rechnungen erfasst")
                    .appFont(AppFont.bodySemi())
                    .foregroundStyle(DesignTokens.text)
                Button {
                    zeigeNeu = true
                } label: {
                    Text("Erste Rechnung anlegen")
                        .appFont(AppFont.bodySemi())
                        .foregroundStyle(DesignTokens.accentText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(DesignTokens.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private var sucheLeerZustand: some View {
        Card {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 24))
                    .foregroundStyle(DesignTokens.textTertiary)
                Text("Keine Treffer für »\(suchtext)«")
                    .appFont(AppFont.caption())
                    .foregroundStyle(DesignTokens.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Daten

    private var subtitel: String? {
        guard let p = aktivePeriode else { return nil }
        let kal = Calendar(identifier: .gregorian)
        let j = kal.component(.year, from: p.bis)
        return "Periode \(j)"
    }

    private var alleRechnungen: [Rechnung] { immobilie?.rechnungen ?? [] }

    private var rechnungenInPeriode: [Rechnung] {
        guard let p = aktivePeriode else { return alleRechnungen }
        return alleRechnungen.filter {
            $0.rechnungsdatum >= p.von && $0.rechnungsdatum <= p.bis
        }
    }

    private var summeInPeriode: Decimal {
        rechnungenInPeriode.reduce(Decimal(0)) { $0 + $1.betragBruttoEuro }
    }

    private var gepruftDetail: String {
        let offen = rechnungenInPeriode.filter { !$0.geprueft }.count
        if offen == 0 { return "alle geprüft" }
        return "\(offen) ungeprüft"
    }

    private var gefiltert: [Rechnung] {
        alleRechnungen.filter(passtZumSuchtext)
    }

    private var gruppen: [Gruppe] {
        let nachSchluessel = Dictionary(grouping: gefiltert) { r -> String in
            r.kostenart?.bezeichnung ?? "ohne"
        }
        return nachSchluessel
            .map { (schluessel, rechnungen) -> Gruppe in
                Gruppe(
                    schluessel: schluessel,
                    rechnungen: rechnungen.sorted { $0.rechnungsdatum > $1.rechnungsdatum }
                )
            }
            .sorted {
                let l = Self.betrKvRang($0.schluessel)
                let r = Self.betrKvRang($1.schluessel)
                if l != r { return l < r }
                return $0.schluessel.localizedCompare($1.schluessel) == .orderedAscending
            }
    }

    fileprivate struct Gruppe: Identifiable {
        let schluessel: String
        let rechnungen: [Rechnung]
        var id: String { schluessel }
        var summe: Decimal {
            rechnungen.reduce(Decimal(0)) { $0 + $1.betragBruttoEuro }
        }
    }

    private func passtZumSuchtext(_ r: Rechnung) -> Bool {
        let s = suchtext.trimmingCharacters(in: .whitespaces).lowercased()
        guard !s.isEmpty else { return true }
        if r.lieferant.lowercased().contains(s) { return true }
        if r.rechnungsnummer.lowercased().contains(s) { return true }
        let betrag = NSDecimalNumber(decimal: r.betragBruttoEuro).stringValue
        if betrag.contains(s) { return true }
        if betrag.replacingOccurrences(of: ".", with: ",").contains(s) { return true }
        return false
    }

    private func toggle(_ s: String) {
        if aufgeklappt.contains(s) {
            aufgeklappt.remove(s)
        } else {
            aufgeklappt.insert(s)
        }
    }

    // MARK: - BetrKV-Reihenfolge + Icons

    private static func betrKvRang(_ name: String) -> Int {
        let n = name.lowercased()
        if n == "ohne"                                               { return 99 }
        if n.contains("entwäss") || (n.contains("wasser") && !n.contains("heiz") && !n.contains("warm")) { return 1 }
        if n.contains("heiz") || n.contains("warmwasser")            { return 2 }
        if n.contains("strom") || n.contains("allgemein")            { return 3 }
        if n.contains("grundsteuer")                                 { return 4 }
        if n.contains("versicher")                                   { return 5 }
        if n.contains("reinig")                                      { return 6 }
        if n.contains("garten") || n.contains("schnee") || n.contains("eis") { return 7 }
        if n.contains("müll") || n.contains("bsr") || n.contains("stadtrein") { return 8 }
        if n.contains("schornstein")                                 { return 9 }
        return 10
    }

    private static func symbolFuer(_ name: String) -> String {
        let n = name.lowercased()
        if n == "ohne"                                          { return "questionmark.circle" }
        if n.contains("entwäss") || (n.contains("wasser") && !n.contains("heiz") && !n.contains("warm")) { return "drop.fill" }
        if n.contains("heiz") || n.contains("warmwasser")       { return "flame.fill" }
        if n.contains("strom") || n.contains("allgemein")       { return "bolt.fill" }
        if n.contains("grundsteuer")                            { return "building.columns.fill" }
        if n.contains("versicher")                              { return "shield.fill" }
        if n.contains("reinig")                                 { return "sparkles" }
        if n.contains("garten")                                 { return "leaf.fill" }
        if n.contains("schnee") || n.contains("eis")            { return "snowflake" }
        if n.contains("müll") || n.contains("bsr") || n.contains("stadtrein") { return "trash.fill" }
        if n.contains("schornstein")                            { return "smoke.fill" }
        return "doc.text.fill"
    }
}
