//
//  VorauszahlungEingabeSheet.swift
//  NebenkostenApp — UI/Mieter
//
//  Sammel-Eingabe der monatlichen Betriebskostenvorauszahlung fuer
//  alle aktiven Mietverhaeltnisse einer Immobilie.
//
//  Architektur (v2, nach Device-Bug):
//    Jeder Row ist ein eigenes `VorauszahlungRow`-Subview mit
//    `@Bindable mv: Mietverhaeltnis`. Eingaben landen via
//    `.onChange(of:)` DIREKT auf dem @Model-Objekt. Speichern
//    commitet nur noch `modelContext.save()`; Abbrechen ruft
//    `modelContext.rollback()` und verwirft damit alle
//    uncommitteten Feld-Aenderungen dieses Sheets.
//
//  Das ersetzt die frueher dict-basierte Zwischenspeicherung
//  (`@State var eintraege: [UUID: Eintrag]`), bei der die
//  Bindings im Einzelfall nicht an die Mietverhaeltnis-Objekte
//  durchgereicht haben.
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

    private var mietverhaeltnisse: [Mietverhaeltnis] {
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
                    SheetToolbar.abbrechen {
                        modelContext.rollback()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    SheetToolbar.primaer(
                        titel: "Speichern",
                        istAktiv: !mietverhaeltnisse.isEmpty
                    ) { speichern() }
                }
            }
            .keyboardFertigButton()
        }
        .tint(DesignTokens.accent)
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
                    VorauszahlungRow(
                        mv: mv,
                        defaultGueltigAb: defaultGueltigAb
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Persistenz

    private func speichern() {
        // Die Aenderungen sitzen bereits auf den Mietverhaeltnis-
        // Objekten (via `.onChange` im Subview). Nur noch den
        // Context persistieren; Fehler explizit loggen, damit wir
        // bei Problemen nicht im Blind-Save landen wie frueher
        // mit `try?`.
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("[VZ] modelContext.save fehlgeschlagen:", error.localizedDescription)
            #endif
        }
        dismiss()
    }
}

// MARK: - VorauszahlungRow

/// Eine Zeile im Vorauszahlungs-Sheet. Haelt `@Bindable mv`, damit
/// onChange direkt auf das @Model-Objekt schreibt — keine Umwege
/// ueber Dictionaries oder Custom-Bindings.
private struct VorauszahlungRow: View {
    @Bindable var mv: Mietverhaeltnis
    let defaultGueltigAb: Date

    @State private var betragText: String = ""
    @State private var gueltigAb: Date = Date()
    @State private var geladen: Bool = false

    var body: some View {
        Card(tiefe: .flach) {
            VStack(alignment: .leading, spacing: 14) {
                kopfZeile
                betragFeld
                gueltigAbFeld
                if mv.vorauszahlungErfasst {
                    Text("Gespeichert: \(Self.format(mv.vorauszahlungMonatEuro)) / Monat")
                        .appFont(AppFont.Basis.monoSmall())
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            }
        }
        .onAppear { ladenFallsNoetig() }
    }

    private func ladenFallsNoetig() {
        guard !geladen else { return }
        betragText = mv.vorauszahlungErfasst
            ? Self.format(mv.vorauszahlungMonatEuro)
            : ""
        gueltigAb = mv.vorauszahlungGueltigAb ?? defaultGueltigAb
        geladen = true
    }

    // MARK: - Unterviews

    private var kopfZeile: some View {
        HStack(alignment: .center, spacing: 10) {
            if let e = mv.wohneinheit {
                UnitBalken(farbe: ScopeFarbe.farbe(fuer: e))
                    .frame(height: 32)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(kopfTitel)
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

    private var kopfTitel: String {
        guard let e = mv.wohneinheit else { return "Mieter" }
        let name = ScopeTexte.abkuerzungName(mv.mieterName)
        if name.isEmpty { return e.bezeichnung }
        return "\(e.bezeichnung) · \(name)"
    }

    private var betragFeld: some View {
        HStack(spacing: 8) {
            Text("Monatliche Vorauszahlung NK")
                .appFont(AppFont.bodyMedium())
                .foregroundStyle(DesignTokens.textSecondary)
            Spacer()
            TextField("0,00", text: $betragText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .appFont(AppFont.Basis.monoBodySemi())
                .foregroundStyle(DesignTokens.text)
                .frame(maxWidth: 120)
                .onChange(of: betragText) { _, neu in
                    schreibeBetrag(neu)
                }
            Text("€")
                .appFont(AppFont.Basis.monoBody())
                .foregroundStyle(DesignTokens.textSecondary)
        }
    }

    private var gueltigAbFeld: some View {
        HStack(spacing: 8) {
            Text("Gültig ab")
                .appFont(AppFont.bodyMedium())
                .foregroundStyle(DesignTokens.textSecondary)
            Spacer()
            DatePicker(
                "",
                selection: $gueltigAb,
                displayedComponents: .date
            )
            .labelsHidden()
            .environment(\.locale, Locale(identifier: "de_DE"))
            .tint(DesignTokens.text)
            .onChange(of: gueltigAb) { _, neu in
                mv.vorauszahlungGueltigAb = neu
                // Datum zaehlt als aktive Bestaetigung: wenn der
                // User ein Datum setzt, ist die VZ „erfasst".
                mv.vorauszahlungErfasst = true
            }
        }
    }

    // MARK: - Write-through

    private func schreibeBetrag(_ text: String) {
        guard let wert = Self.parse(text) else {
            // Leerer / ungueltiger Input: nicht ueberschreiben.
            return
        }
        mv.vorauszahlungMonatEuro = wert
        mv.vorauszahlungErfasst = true
        // Wenn noch kein Gueltig-ab gesetzt ist, den aktuellen
        // Picker-Wert persistieren — sonst bliebe vorauszahlungGueltigAb
        // `nil`, wenn der User den DatePicker nicht angefasst hat.
        if mv.vorauszahlungGueltigAb == nil {
            mv.vorauszahlungGueltigAb = gueltigAb
        }
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
