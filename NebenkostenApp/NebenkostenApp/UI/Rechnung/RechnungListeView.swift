//
//  RechnungListeView.swift
//  NebenkostenApp — UI/Rechnung
//
//  Gruppierte Rechnungsliste: Sektionen nach Kostenart (BetrKV-
//  Reihenfolge), ein-/ausklappbar, mit Suche und Status-Icon je
//  Rechnung. Alle Sektionen sind default zu.
//

import SwiftUI
import SwiftData

struct RechnungListeView: View {
    @Bindable var immobilie: Immobilie

    @State private var zeigeNeu = false
    @State private var auswahl: Rechnung?
    @State private var suchtext = ""
    /// Kostenart-Bezeichnung → aufgeklappt? "ohne" für Rechnungen ohne
    /// Kostenart. Bezeichnung statt ID, weil der Default-Zustand sonst
    /// nach Re-Fetch verloren ginge.
    @State private var aufgeklappt: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if alleRechnungen.isEmpty {
                    leerZustand
                } else if gruppen.isEmpty {
                    sucheLeerZustand
                } else {
                    ForEach(gruppen) { gruppe in
                        gruppenCard(gruppe)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .background(Color(.systemGroupedBackground))
        .searchable(text: $suchtext, prompt: "Versorger, Rechnungsnummer oder Betrag")
        .navigationTitle("Rechnungen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    zeigeNeu = true
                } label: {
                    Label("Neue Rechnung", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $zeigeNeu) {
            RechnungEditView(modus: .neu(immobilie: immobilie))
        }
        .sheet(item: $auswahl) { r in
            RechnungEditView(modus: .bearbeiten(r))
        }
    }

    // MARK: - Gruppen-Card (eigene Card pro Kostenart)

    private func gruppenCard(_ gruppe: RechnungGruppe) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sektionHeader(gruppe)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

            if aufgeklappt.contains(gruppe.schluessel) {
                Divider().padding(.leading, 14)
                VStack(spacing: 0) {
                    ForEach(Array(gruppe.rechnungen.enumerated()), id: \.element.id) { idx, r in
                        Button {
                            auswahl = r
                        } label: {
                            zeile(r)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        if idx < gruppe.rechnungen.count - 1 {
                            Divider().padding(.leading, 14)
                        }
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Daten

    private var alleRechnungen: [Rechnung] {
        (immobilie.rechnungen ?? [])
    }

    private var defaultPeriode: Abrechnungsperiode? {
        let perioden = (immobilie.perioden ?? []).sorted(by: { $0.bis > $1.bis })
        let heute = Date()
        return perioden.first(where: { $0.bis < heute }) ?? perioden.first
    }

    private var gefiltert: [Rechnung] {
        alleRechnungen.filter(passtZumSuchtext)
    }

    private var gruppen: [RechnungGruppe] {
        let nachSchluessel = Dictionary(grouping: gefiltert) { r -> String in
            r.kostenart?.bezeichnung ?? "ohne"
        }
        return nachSchluessel
            .map { (schluessel, rechnungen) -> RechnungGruppe in
                RechnungGruppe(
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

    // MARK: - Sektions-Header

    private func sektionHeader(_ gruppe: RechnungGruppe) -> some View {
        Button {
            toggle(gruppe.schluessel)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: Self.symbolFuer(gruppe.schluessel))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 22)
                Text(gruppe.schluessel == "ohne" ? "Ohne Kostenart" : gruppe.schluessel)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("(\(gruppe.rechnungen.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatiertBetrag(gruppe.summe))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.primary)
                Image(systemName: aufgeklappt.contains(gruppe.schluessel)
                      ? "chevron.up"
                      : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .textCase(nil)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Zeile

    private func zeile(_ r: Rechnung) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: statusSymbol(r))
                .foregroundStyle(statusFarbe(r))
                .font(.title3)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(r.lieferant.isEmpty ? "Ohne Lieferant" : r.lieferant)
                    .font(.callout.weight(.semibold))
                HStack(spacing: 6) {
                    if !r.rechnungsnummer.isEmpty {
                        Text(r.rechnungsnummer)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(r.rechnungsdatum.formatted(date: .numeric, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(formatiertBetrag(r.betragBruttoEuro))
                .font(.callout.monospacedDigit())
        }
        .contentShape(Rectangle())
    }

    // MARK: - Leerzustände

    private var leerZustand: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Noch keine Rechnungen erfasst")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                zeigeNeu = true
            } label: {
                Label("Erste Rechnung anlegen", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var sucheLeerZustand: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("Keine Rechnungen zu „\(suchtext)“")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Filter / Status

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

    private func statusFarbe(_ r: Rechnung) -> Color {
        guard let p = defaultPeriode else { return .gray }
        let inPeriode = r.rechnungsdatum >= p.von && r.rechnungsdatum <= p.bis
        if !inPeriode { return .gray }
        if hatWarnung(r) { return .yellow }
        return .green
    }

    private func statusSymbol(_ r: Rechnung) -> String {
        guard let p = defaultPeriode else { return "circle" }
        let inPeriode = r.rechnungsdatum >= p.von && r.rechnungsdatum <= p.bis
        if !inPeriode { return "circle.dotted" }
        if hatWarnung(r) { return "exclamationmark.circle.fill" }
        return "checkmark.circle.fill"
    }

    /// Praktische Warnungs-Heuristik pro Rechnung. Aktuell gecheckt:
    ///  - §35a-Kostenart, aber kein Lohnanteil ausgewiesen.
    ///  - Rechnung noch nicht als geprüft markiert.
    /// Task 0.20 Check 2 (historischer Ausreißer) braucht mehrere
    /// Abrechnungsjahre und wird in Phase 1 nachgezogen.
    private func hatWarnung(_ r: Rechnung) -> Bool {
        if let ka = r.kostenart, ka.paragraph35a, r.lohnanteilBruttoEuro == nil {
            return true
        }
        if !r.geprueft {
            return true
        }
        return false
    }

    private func toggle(_ schluessel: String) {
        if aufgeklappt.contains(schluessel) {
            aufgeklappt.remove(schluessel)
        } else {
            aufgeklappt.insert(schluessel)
        }
    }

    // MARK: - Formatter

    private func formatiertBetrag(_ betrag: Decimal) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = "EUR"
        nf.locale = Locale(identifier: "de_DE")
        return nf.string(from: NSDecimalNumber(decimal: betrag)) ?? "\(betrag) €"
    }

    // MARK: - BetrKV-Reihenfolge + Icons

    /// Rang nach BetrKV-Systematik (siehe Task-Brief).
    private static func betrKvRang(_ name: String) -> Int {
        let n = name.lowercased()
        if n == "ohne"                                               { return 99 }
        if n.contains("entwäss") || n.contains("wasser") && !n.contains("heiz") && !n.contains("warm") { return 1 }
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

// MARK: - Hilfstyp

private struct RechnungGruppe: Identifiable {
    let schluessel: String
    let rechnungen: [Rechnung]
    var id: String { schluessel }
    var summe: Decimal {
        rechnungen.reduce(Decimal(0)) { $0 + $1.betragBruttoEuro }
    }
}
