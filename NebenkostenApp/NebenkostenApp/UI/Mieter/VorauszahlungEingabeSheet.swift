//
//  VorauszahlungEingabeSheet.swift
//  NebenkostenApp — UI/Mieter
//
//  Sammel-Eingabe der monatlichen Betriebskostenvorauszahlung fuer
//  alle aktiven Mietverhaeltnisse einer Immobilie. Ersetzt den
//  frueheren Umweg ueber das EinstellungenSheet: der Nachster-
//  Schritt-Eintrag „Vorauszahlungen eintragen" oeffnet jetzt
//  direkt diese Eingabemaske.
//
//  Layout je Mietverhaeltnis:
//    - WE-Label (Farbbalken + Bezeichnung · Mieter-Name)
//    - Feld „Monatliche Vorauszahlung NK" (Decimal, €-Suffix,
//      Mono-Font)
//    - Feld „Gueltig ab" (DatePicker, default = Perioden-Start)
//    - „Aktuell: X €/Monat" darunter, wenn eine VZ schon gesetzt
//      ist
//
//  Strikte-Daten-Regel: Speichern setzt `vorauszahlungErfasst =
//  true` explizit — auch 0 € ist erlaubt (Selbstnutzer-Fall),
//  solange der User den Wert aktiv bestaetigt hat.
//

import SwiftUI
import SwiftData

struct VorauszahlungEingabeSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let immobilie: Immobilie
    /// Optional: Einheit-Bezeichnung, die beim Oeffnen fokussiert
    /// (an den Anfang gescrollt) werden soll. `nil` = kein Fokus.
    let fokusEinheitID: String?

    @State private var eintraege: [UUID: Eintrag] = [:]

    private struct Eintrag: Equatable {
        var betragText: String
        var gueltigAb: Date
    }

    private var mietverhaeltnisse: [Mietverhaeltnis] {
        // Sortierung: Fokus-Einheit zuerst, danach nach
        // Geschoss-Rang (KG/EG/OG/...).
        let aktive = (immobilie.wohneinheiten ?? [])
            .sorted { ScopeFilter.einheitRang($0.bezeichnung) < ScopeFilter.einheitRang($1.bezeichnung) }
            .compactMap { e -> Mietverhaeltnis? in
                (e.mietverhaeltnisse ?? []).first { $0.auszugAm == nil }
            }
        guard let fokus = fokusEinheitID,
              let treffer = aktive.firstIndex(where: { $0.wohneinheit?.bezeichnung == fokus }),
              treffer > 0 else {
            return aktive
        }
        var neu = aktive
        let geholt = neu.remove(at: treffer)
        neu.insert(geholt, at: 0)
        return neu
    }

    private var defaultGueltigAb: Date {
        let sortiert = (immobilie.perioden ?? []).sorted { $0.von > $1.von }
        return sortiert.first?.von ?? Date()
    }

    var body: some View {
        NavigationStack {
            Group {
                if mietverhaeltnisse.isEmpty {
                    leerzustand
                } else {
                    liste
                }
            }
            .background(DesignTokens.bgApp)
            .navigationTitle("Vorauszahlungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetToolbar.abbrechen { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    SheetToolbar.primaer(
                        titel: "Speichern",
                        istAktiv: istGueltig
                    ) { speichern() }
                }
            }
        }
        .task { initialisiereEintraege() }
    }

    // MARK: - Unterzustaende

    @ViewBuilder
    private var leerzustand: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(DesignTokens.textTertiary)
            Text("Keine aktiven Mietverhältnisse")
                .appFont(AppFont.bodySemi())
                .foregroundStyle(DesignTokens.text)
            Text("Lege zuerst in den Einstellungen Mieter an — dann kannst du hier die Vorauszahlungen eintragen.")
                .appFont(AppFont.caption())
                .foregroundStyle(DesignTokens.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.vertical, 40)
    }

    private var liste: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(mietverhaeltnisse) { mv in
                    eintragCard(mv)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }

    private func eintragCard(_ mv: Mietverhaeltnis) -> some View {
        let eintragBinding = bindungFuer(mv)
        let einheit = mv.wohneinheit
        return Card(tiefe: .flach) {
            VStack(alignment: .leading, spacing: 14) {
                kopfZeile(mv)
                betragFeld(binding: eintragBinding.betragText)
                gueltigAbFeld(binding: eintragBinding.gueltigAb)
                if mv.vorauszahlungErfasst {
                    Text("Aktuell: \(Formatting.euro(mv.vorauszahlungMonatEuro)) / Monat")
                        .appFont(AppFont.Basis.monoSmall())
                        .foregroundStyle(DesignTokens.textSecondary)
                }
                let _ = einheit  // silence unused warning if einheit nil
            }
        }
    }

    private func kopfZeile(_ mv: Mietverhaeltnis) -> some View {
        HStack(alignment: .center, spacing: 10) {
            if let e = mv.wohneinheit {
                UnitBalken(farbe: ScopeFarbe.farbe(fuer: e))
                    .frame(height: 32)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(kopfTitel(mv))
                    .appFont(AppFont.bodySemi())
                    .foregroundStyle(DesignTokens.text)
                if !mv.mieterName.isEmpty {
                    Text(ScopeTexte.abkuerzungName(mv.mieterName))
                        .appFont(AppFont.caption())
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            }
            Spacer()
        }
    }

    private func kopfTitel(_ mv: Mietverhaeltnis) -> String {
        guard let e = mv.wohneinheit else { return "Mieter" }
        let name = ScopeTexte.abkuerzungName(mv.mieterName)
        if name.isEmpty { return e.bezeichnung }
        return "\(e.bezeichnung) · \(name)"
    }

    private func betragFeld(binding: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Text("Monatliche Vorauszahlung NK")
                .appFont(AppFont.bodyMedium())
                .foregroundStyle(DesignTokens.textSecondary)
            Spacer()
            TextField("0,00", text: binding)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .appFont(AppFont.Basis.monoBodySemi())
                .foregroundStyle(DesignTokens.text)
                .frame(maxWidth: 120)
            Text("€")
                .appFont(AppFont.Basis.monoBody())
                .foregroundStyle(DesignTokens.textSecondary)
        }
    }

    private func gueltigAbFeld(binding: Binding<Date>) -> some View {
        HStack(spacing: 8) {
            Text("Gültig ab")
                .appFont(AppFont.bodyMedium())
                .foregroundStyle(DesignTokens.textSecondary)
            Spacer()
            DatePicker(
                "",
                selection: binding,
                displayedComponents: .date
            )
            .labelsHidden()
            .environment(\.locale, Locale(identifier: "de_DE"))
        }
    }

    // MARK: - State + Validierung

    private func bindungFuer(_ mv: Mietverhaeltnis) -> (betragText: Binding<String>, gueltigAb: Binding<Date>) {
        let id = mv.id
        let default_ = Eintrag(
            betragText: mv.vorauszahlungErfasst ? Self.format(mv.vorauszahlungMonatEuro) : "",
            gueltigAb: mv.vorauszahlungGueltigAb ?? defaultGueltigAb
        )
        let betragBinding = Binding<String>(
            get: { eintraege[id]?.betragText ?? default_.betragText },
            set: { neu in
                var aktuell = eintraege[id] ?? default_
                aktuell.betragText = neu
                eintraege[id] = aktuell
            }
        )
        let dateBinding = Binding<Date>(
            get: { eintraege[id]?.gueltigAb ?? default_.gueltigAb },
            set: { neu in
                var aktuell = eintraege[id] ?? default_
                aktuell.gueltigAb = neu
                eintraege[id] = aktuell
            }
        )
        return (betragBinding, dateBinding)
    }

    private var istGueltig: Bool {
        guard !mietverhaeltnisse.isEmpty else { return false }
        // Alle Eintraege muessen ein valides Decimal ergeben —
        // leere Eingaben sind nicht erlaubt (Strikte-Daten-Regel:
        // aktives Bestaetigen, auch 0 € muss explizit eingetippt
        // werden).
        return mietverhaeltnisse.allSatisfy { mv in
            let txt = eintraege[mv.id]?.betragText
                ?? (mv.vorauszahlungErfasst ? Self.format(mv.vorauszahlungMonatEuro) : "")
            return Self.parse(txt) != nil
        }
    }

    private func initialisiereEintraege() {
        guard eintraege.isEmpty else { return }
        for mv in mietverhaeltnisse {
            let betragText: String
            if mv.vorauszahlungErfasst {
                betragText = Self.format(mv.vorauszahlungMonatEuro)
            } else {
                betragText = ""
            }
            eintraege[mv.id] = Eintrag(
                betragText: betragText,
                gueltigAb: mv.vorauszahlungGueltigAb ?? defaultGueltigAb
            )
        }
    }

    // MARK: - Persistenz

    private func speichern() {
        for mv in mietverhaeltnisse {
            guard let eintrag = eintraege[mv.id] else { continue }
            guard let wert = Self.parse(eintrag.betragText) else { continue }
            mv.vorauszahlungMonatEuro = wert
            mv.vorauszahlungErfasst = true
            mv.vorauszahlungGueltigAb = eintrag.gueltigAb
        }
        try? modelContext.save()
        dismiss()
    }

    // MARK: - Parse / Format

    nonisolated private static func parse(_ text: String) -> Decimal? {
        let norm = text
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard !norm.isEmpty else { return nil }
        return Decimal(string: norm)
    }

    nonisolated private static func format(_ wert: Decimal) -> String {
        let nf = NumberFormatter()
        nf.locale = Locale(identifier: "de_DE")
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 2
        nf.maximumFractionDigits = 2
        return nf.string(from: NSDecimalNumber(decimal: wert)) ?? "\(wert)"
    }
}
