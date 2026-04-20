//
//  RechnungenView.swift
//  NebenkostenApp — UI/Rechnung
//
//  Rechnungen-Tab nach Design-Handoff + UI-Fix-2.
//    - Layout: gruppiert nach Kostenart in BetrKV-Reihenfolge,
//      Default: nur "Heizung & Warmwasser" offen. Keine Icons
//      vor Gruppen-Headern.
//    - Suche: .searchable am ScrollView-Root, filtert einzelne
//      Rechnungen (nicht Gruppen-Summen).
//    - "Neue Rechnung": Toolbar-Button (AppShellChrome.primaryAction)
//      — keine Content-Card mehr.
//    - Perioden-Info: kompakt in den NavBar-Subtitle ("Periode 2025 ·
//      7 Rechnungen · 7.984,67 €").
//    - Rechnungs-Rows: Issuer (16pt/500), Betrag (17pt/600 mono),
//      Datum+Periode (12pt), rechts StatusPill.
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
    @State private var suchtext: String = ""

    private var immobilie: Immobilie? { immobilien.first }

    private var aktivePeriode: Abrechnungsperiode? {
        let perioden = (immobilie?.perioden ?? []).sorted(by: { $0.bis > $1.bis })
        let heute = Date()
        return perioden.first(where: { $0.bis < heute }) ?? perioden.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if aktivePeriode != nil {
                    periodenCard
                }
                if alleRechnungen.isEmpty {
                    leerZustand
                } else if gruppen.isEmpty {
                    sucheLeerZustand
                } else {
                    ForEach(gruppen) { g in
                        gruppenSection(g)
                    }
                }
                scopeHinweis
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(DesignTokens.bgApp)
        .searchable(text: $suchtext, prompt: "Rechnung oder Versorger suchen …")
        .appShellChrome(
            titel: "Rechnungen",
            subtitel: subtitel,
            onAdresse: { zeigeScopePicker = true },
            onEinstellungen: { zeigeEinstellungen = true },
            primaryAction: .init(
                symbol: "plus",
                label: "Neue Rechnung",
                handler: { zeigeNeu = true }
            )
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

    // MARK: - Perioden-Card (kompakt, einzeilig)

    @ViewBuilder
    private var periodenCard: some View {
        if let p = aktivePeriode {
            let jahr = Calendar(identifier: .gregorian).component(.year, from: p.bis)
            let n = rechnungenInPeriode.count
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Periode \(jahr)")
                        .appFont(AppFont.uppercaseLabel())
                        .foregroundStyle(DesignTokens.textTertiary)
                    Text(Formatting.periode(p.von, p.bis))
                        .appFont(AppFont.monoSmall())
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                Spacer(minLength: 8)
                Text("\(n) Rechnung\(n == 1 ? "" : "en") · \(Formatting.euro(summeInPeriode))")
                    .appFont(AppFont.monoBody())
                    .foregroundStyle(DesignTokens.text)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.bgSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(DesignTokens.separator, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - Gruppe

    private func gruppenSection(_ g: Gruppe) -> some View {
        CollapsibleSection(
            titel: g.titel,
            summary: Formatting.euro(g.summe),
            count: g.rechnungen.count,
            persistKey: "rechnungen.kostenart.\(g.rang).open",
            defaultOffen: g.rang == 1  // Heizung & Warmwasser
        ) {
            VStack(spacing: 0) {
                ForEach(Array(g.rechnungen.enumerated()), id: \.element.id) { idx, r in
                    rechnungZeile(r)
                    if idx < g.rechnungen.count - 1 {
                        DividerLine().padding(.leading, 14)
                    }
                }
            }
        }
    }

    private func rechnungZeile(_ r: Rechnung) -> some View {
        Button {
            auswahl = r
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(r.lieferant.isEmpty ? "Ohne Lieferant" : r.lieferant)
                        .appFont(AppFont.bodyMedium16())
                        .foregroundStyle(DesignTokens.text)
                        .lineLimit(1)
                    Text(metaZeile(r))
                        .appFont(AppFont.captionEmphasis())
                        .foregroundStyle(DesignTokens.textTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(Formatting.euro(r.betragBruttoEuro))
                        .appFont(AppFont.monoBetrag17())
                        .foregroundStyle(DesignTokens.text)
                    pillFuer(r)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func pillFuer(_ r: Rechnung) -> some View {
        let (text, style) = pillDaten(r)
        return StatusPill(text: text, style: style)
    }

    private func pillDaten(_ r: Rechnung) -> (String, StatusPill.Style) {
        if let ka = r.kostenart, ka.paragraph35a, r.lohnanteilBruttoEuro == nil {
            return ("§35a offen", .warn)
        }
        if !r.geprueft { return ("ungeprüft", .warn) }
        return ("validiert", .ok)
    }

    private func metaZeile(_ r: Rechnung) -> String {
        var parts: [String] = [Formatting.datum(r.rechnungsdatum)]
        if r.leistungVon != r.rechnungsdatum || r.leistungBis != r.rechnungsdatum {
            parts.append(Formatting.periode(r.leistungVon, r.leistungBis))
        }
        if !r.rechnungsnummer.isEmpty {
            parts.append("Nr. \(r.rechnungsnummer)")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Scope-Hinweis + Leer

    @ViewBuilder
    private var scopeHinweis: some View {
        if case .einheit = scope.current {
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.textTertiary)
                Text("Rechnungen betreffen das gesamte Objekt und werden je nach Umlageschlüssel auf die Einheiten verteilt.")
                    .appFont(AppFont.captionEmphasis())
                    .foregroundStyle(DesignTokens.textTertiary)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.top, 8)
        }
    }

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
        let jahr = Calendar(identifier: .gregorian).component(.year, from: p.bis)
        return "Periode \(jahr)"
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

    private var gefiltert: [Rechnung] {
        alleRechnungen.filter(passtZumSuchtext)
    }

    private var gruppen: [Gruppe] {
        let nachKat = Dictionary(grouping: gefiltert) { r -> Int in
            Self.betrKvRang(r.kostenart?.bezeichnung ?? "ohne")
        }
        return Self.betrKvDefinition
            .compactMap { def -> Gruppe? in
                guard let rechnungen = nachKat[def.rang], !rechnungen.isEmpty else { return nil }
                return Gruppe(
                    rang: def.rang,
                    titel: def.titel,
                    rechnungen: rechnungen.sorted { $0.rechnungsdatum > $1.rechnungsdatum }
                )
            }
    }

    private func passtZumSuchtext(_ r: Rechnung) -> Bool {
        let s = suchtext.trimmingCharacters(in: .whitespaces).lowercased()
        guard !s.isEmpty else { return true }
        if r.lieferant.lowercased().contains(s) { return true }
        if r.rechnungsnummer.lowercased().contains(s) { return true }
        if (r.kostenart?.bezeichnung ?? "").lowercased().contains(s) { return true }
        let betrag = NSDecimalNumber(decimal: r.betragBruttoEuro).stringValue
        if betrag.contains(s) { return true }
        if betrag.replacingOccurrences(of: ".", with: ",").contains(s) { return true }
        return false
    }

    // MARK: - BetrKV-Reihenfolge (UI-Fix-2)

    struct Gruppe: Identifiable {
        let rang: Int
        let titel: String
        let rechnungen: [Rechnung]
        var id: Int { rang }
        var summe: Decimal {
            rechnungen.reduce(Decimal(0)) { $0 + $1.betragBruttoEuro }
        }
    }

    fileprivate struct KategorieDef {
        let rang: Int
        let titel: String
    }

    fileprivate static let betrKvDefinition: [KategorieDef] = [
        .init(rang: 1, titel: "Heizung & Warmwasser"),
        .init(rang: 2, titel: "Wasser & Entwässerung"),
        .init(rang: 3, titel: "Müllabfuhr"),
        .init(rang: 4, titel: "Grundsteuer"),
        .init(rang: 5, titel: "Gebäudeversicherung"),
        .init(rang: 6, titel: "Schornsteinfeger"),
        .init(rang: 7, titel: "Hausreinigung & Gartenpflege"),
        .init(rang: 8, titel: "Hauswart"),
        .init(rang: 9, titel: "Allgemeinstrom"),
        .init(rang: 10, titel: "Reparatur (nicht umlagefähig)"),
        .init(rang: 99, titel: "Ohne Kostenart")
    ]

    static func betrKvRang(_ name: String) -> Int {
        let n = name.lowercased()
        if n == "ohne" || n.isEmpty                                 { return 99 }
        if n.contains("heiz") || n.contains("warmwasser")           { return 1 }
        if n.contains("entwäss") || (n.contains("wasser") && !n.contains("heiz") && !n.contains("warm")) { return 2 }
        if n.contains("müll") || n.contains("bsr") || n.contains("stadtrein") { return 3 }
        if n.contains("grundsteuer")                                { return 4 }
        if n.contains("versicher")                                  { return 5 }
        if n.contains("schornstein")                                { return 6 }
        if n.contains("reinig") || n.contains("garten") || n.contains("schnee") || n.contains("eis") { return 7 }
        if n.contains("hauswart") || n.contains("hausmeister")      { return 8 }
        if n.contains("strom") || n.contains("allgemein")           { return 9 }
        if n.contains("reparatur") || n.contains("instandhaltung")  { return 10 }
        return 10
    }
}
