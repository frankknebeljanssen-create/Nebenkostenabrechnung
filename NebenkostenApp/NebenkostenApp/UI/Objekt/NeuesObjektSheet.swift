//
//  NeuesObjektSheet.swift
//  NebenkostenApp — UI/Objekt
//
//  Gefuehrter Flow zum Anlegen eines neuen Objekts — deckt alle
//  Typen ab (Gesamtgebaeude, einzelne WE, einfaches Objekt) und
//  legt beim Speichern ab:
//    1. Immobilie (Adresse, Ort, Flaeche, Abrechnungsstart,
//       Heizung/Warmwasser).
//    2. Wohneinheiten inkl. optionalem Mietverhaeltnis pro
//       Einheit (Toggle „vermietet").
//    3. Standard-Kostenarten passend zum Objekt-Typ
//       (`StandardKostenarten.anlegen`).
//    4. Erste Abrechnungsperiode (DatePickers von/bis).
//

import SwiftUI
import SwiftData

struct NeuesObjektSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let onAngelegt: (Immobilie) -> Void

    // MARK: - Adresse / Eckdaten

    @State private var adresse: String = ""
    @State private var plz: String = ""
    @State private var stadt: String = ""
    @State private var gesamtflaecheText: String = ""

    // MARK: - Objekt-Typ

    @State private var objektTyp: StandardKostenarten.Typ = .gesamtgebaeude

    // MARK: - Heizung

    @State private var heizungsart: Heizungsart = .gasZentral
    @State private var warmwasser: Warmwasserbereitung = .zentralMitHeizung

    // MARK: - Wohneinheiten

    @State private var wohneinheiten: [EinheitEntwurf] = [EinheitEntwurf()]

    // MARK: - Periode

    @State private var periodeVon: Date = Self.ersterDesMonats()
    @State private var periodeBis: Date = Calendar(identifier: .gregorian)
        .date(byAdding: .year, value: 1, to: Self.ersterDesMonats())
        .flatMap { Calendar(identifier: .gregorian).date(byAdding: .day, value: -1, to: $0) }
        ?? Date()

    var body: some View {
        NavigationStack {
            Form {
                hauptmieterSektion
                adresseSektion
                eckdatenSektion
                objektTypSektion
                heizungSektion
                wohneinheitenSektion
                periodenSektion
            }
            .navigationTitle("Neues Objekt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetToolbar.abbrechen { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    SheetToolbar.primaer(
                        titel: "Anlegen",
                        istAktiv: istGueltig
                    ) { anlegen() }
                }
            }
            .keyboardFertigButton()
        }
        .tint(DesignTokens.accent)
    }

    // MARK: - Sections

    /// Prominentes Mieter-Feld GANZ OBEN im Formular. Bindet direkt
    /// an den Namen der ersten Einheit — das ist der typische Fall
    /// (ein Objekt, ein Hauptmieter). Bei mehreren Einheiten bleibt
    /// das Per-WE-Feld das Primaere; dieses Feld hier ist dann die
    /// Schnellspur fuer Einheit 1.
    @ViewBuilder
    private var hauptmieterSektion: some View {
        Section {
            TextField("Mietername", text: Binding(
                get: { wohneinheiten.first?.mieterName ?? "" },
                set: { neu in
                    guard !wohneinheiten.isEmpty else { return }
                    wohneinheiten[0].mieterName = neu
                }
            ))
            .textContentType(.name)
        } header: {
            Text("Mieter")
        } footer: {
            Text("Name des Hauptmieters. Weitere Mieter werden bei den jeweiligen Wohneinheiten eingetragen.")
        }
    }

    private var adresseSektion: some View {
        Section("Adresse") {
            TextField("Straße und Hausnummer", text: $adresse)
                .textContentType(.streetAddressLine1)
            TextField("PLZ", text: $plz)
                .textContentType(.postalCode)
                .keyboardType(.numberPad)
            TextField("Ort / Stadt", text: $stadt)
                .textContentType(.addressCity)
        }
    }

    private var eckdatenSektion: some View {
        Section("Gesamtflaeche") {
            HStack {
                TextField("0", text: $gesamtflaecheText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                Text("m²").foregroundStyle(.secondary)
            }
        }
    }

    private var objektTypSektion: some View {
        Section {
            ForEach(StandardKostenarten.Typ.allCases) { typ in
                Button {
                    objektTyp = typ
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: objektTyp == typ ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(objektTyp == typ ? DesignTokens.accent : DesignTokens.textTertiary)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(typ.anzeigeName)
                                .foregroundStyle(DesignTokens.text)
                            Text(typ.beschreibung)
                                .appFont(AppFont.caption())
                                .foregroundStyle(DesignTokens.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Objekt-Typ")
        } footer: {
            Text("Der Typ bestimmt, welche Standard-Kostenarten automatisch angelegt werden.")
        }
    }

    @ViewBuilder
    private var heizungSektion: some View {
        Section("Heizung") {
            Picker("Heizungsart", selection: $heizungsart) {
                ForEach(Heizungsart.allCases, id: \.self) { art in
                    Text(art.rawValue).tag(art)
                }
            }
            if heizungsart != .keine {
                Picker("Warmwasser", selection: $warmwasser) {
                    ForEach(Warmwasserbereitung.allCases, id: \.self) { bereitung in
                        Text(bereitung.rawValue).tag(bereitung)
                    }
                }
            }
        }
    }

    private var wohneinheitenSektion: some View {
        Section {
            ForEach($wohneinheiten) { $entwurf in
                EinheitZeile(entwurf: $entwurf)
            }
            .onDelete { offsets in
                wohneinheiten.remove(atOffsets: offsets)
            }
            Button {
                wohneinheiten.append(EinheitEntwurf())
            } label: {
                Label("Einheit hinzufügen", systemImage: "plus.circle")
            }
        } header: {
            Text("Wohneinheiten")
        } footer: {
            Text("Pro Einheit optional Mieter + Vorauszahlung. Toggle ausschalten, um den Mieter später einzutragen.")
        }
    }

    private var periodenSektion: some View {
        Section("Abrechnungszeitraum") {
            DatePicker(
                "Von",
                selection: $periodeVon,
                displayedComponents: .date
            )
            .environment(\.locale, Locale(identifier: "de_DE"))
            DatePicker(
                "Bis",
                selection: $periodeBis,
                in: periodeVon...,
                displayedComponents: .date
            )
            .environment(\.locale, Locale(identifier: "de_DE"))
        }
    }

    // MARK: - Validierung

    /// Pragmatisch: der Button ist aktiv, sobald die strukturellen
    /// Pflicht-Eckdaten gefuellt sind — Adresse + mindestens eine
    /// Einheit mit Bezeichnung. Flaeche und weitere Details koennen
    /// auch mit 0/Default gespeichert und spaeter in den
    /// Einstellungen editiert werden. Das ermoeglicht „anlegen und
    /// dann polieren" statt harter Formular-Blockade.
    private var istGueltig: Bool {
        !adresse.trimmingCharacters(in: .whitespaces).isEmpty
            && !wohneinheiten.isEmpty
            && wohneinheiten.allSatisfy {
                !$0.bezeichnung.trimmingCharacters(in: .whitespaces).isEmpty
            }
            && periodeVon < periodeBis
    }

    private var gesamtflaecheDecimal: Decimal? {
        Decimal(string: gesamtflaecheText.replacingOccurrences(of: ",", with: "."))
    }

    // MARK: - Anlegen

    private func anlegen() {
        // 1. Immobilie
        let objekt = Immobilie()
        objekt.adresse = adresse.trimmingCharacters(in: .whitespaces)
        // Immobilie.ort speichert PLZ + Ort als EIN String — die
        // UI hat zwei Felder, die wir hier mergen. Fehlende Teile
        // werden ausgelassen.
        let plzTrim = plz.trimmingCharacters(in: .whitespaces)
        let stadtTrim = stadt.trimmingCharacters(in: .whitespaces)
        objekt.ort = [plzTrim, stadtTrim]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        objekt.gesamtflaecheM2 = gesamtflaecheDecimal ?? 0
        let kal = Calendar(identifier: .gregorian)
        objekt.abrechnungsstartMonat = kal.component(.month, from: periodeVon)
        objekt.abrechnungsstartTag = kal.component(.day, from: periodeVon)
        objekt.heizungsart = heizungsart
        objekt.warmwasserbereitung = warmwasser
        modelContext.insert(objekt)

        // 2. Wohneinheiten + optionale Mietverhaeltnisse
        for entwurf in wohneinheiten {
            let wohneinheit = Wohneinheit()
            wohneinheit.bezeichnung = entwurf.bezeichnung.trimmingCharacters(in: .whitespaces)
            wohneinheit.flaecheM2 = entwurf.flaecheM2
            wohneinheit.nutzungsart = entwurf.nutzungsart
            wohneinheit.immobilie = objekt
            modelContext.insert(wohneinheit)

            if entwurf.istVermietet,
               !entwurf.mieterName.trimmingCharacters(in: .whitespaces).isEmpty {
                let mv = Mietverhaeltnis()
                mv.mieterName = entwurf.mieterName.trimmingCharacters(in: .whitespaces)
                mv.mieterAnschrift = entwurf.mieterAnschrift.trimmingCharacters(in: .whitespacesAndNewlines)
                mv.einzugAm = entwurf.einzugAm
                if let vz = Self.parseVz(entwurf.vorauszahlungText) {
                    mv.vorauszahlungMonatEuro = vz
                    mv.vorauszahlungErfasst = true
                    mv.vorauszahlungGueltigAb = entwurf.einzugAm
                }
                mv.wohneinheit = wohneinheit
                modelContext.insert(mv)
            }
        }

        // 3. Standard-Kostenarten passend zum Typ
        StandardKostenarten.anlegen(
            fuer: objekt,
            typ: objektTyp,
            mitZentralheizung: heizungsart != .keine,
            context: modelContext
        )

        // 4. Abrechnungsperiode
        let periode = Abrechnungsperiode()
        periode.von = periodeVon
        periode.bis = periodeBis
        periode.immobilie = objekt
        modelContext.insert(periode)

        // Explizit persistieren + Fehler loggen (nicht silently
        // wegschlucken). Frueher `try?` hat Save-Fehler verschluckt,
        // sodass der User „Anlegen" tippte, das Sheet aber nicht
        // dismisste und nichts sichtbar passierte.
        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("[NeuesObjekt] save fehlgeschlagen:", error.localizedDescription)
            #endif
            // Rollback, damit Halb-Zustand nicht im Context haengen
            // bleibt; User bleibt im Sheet und kann korrigieren.
            modelContext.rollback()
            return
        }

        onAngelegt(objekt)
        dismiss()
    }

    // MARK: - Helper

    private static func ersterDesMonats(heute: Date = Date()) -> Date {
        let kal = Calendar(identifier: .gregorian)
        let komps = kal.dateComponents([.year, .month], from: heute)
        return kal.date(from: komps) ?? heute
    }

    private static func parseVz(_ text: String) -> Decimal? {
        let norm = text
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard !norm.isEmpty else { return nil }
        return Decimal(string: norm)
    }
}

// MARK: - Einheit-Entwurf

struct EinheitEntwurf: Identifiable, Equatable, Sendable {
    let id: UUID = UUID()
    var bezeichnung: String = ""
    var flaecheM2: Decimal = 0
    var nutzungsart: Nutzungsart = .wohnung
    var istVermietet: Bool = true
    var mieterName: String = ""
    /// Postanschrift des Mieters (Strasse + PLZ + Ort in einer
    /// Zeile). Wird spaeter fuer Abrechnungs-PDFs gebraucht; hier
    /// optional.
    var mieterAnschrift: String = ""
    var einzugAm: Date = Date()
    var vorauszahlungText: String = ""
}

private struct EinheitZeile: View {
    @Binding var entwurf: EinheitEntwurf
    @State private var flaecheText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Bezeichnung (z.B. EG, OG, Datsche)", text: $entwurf.bezeichnung)

            HStack {
                TextField("Fläche m²", text: $flaecheText)
                    .keyboardType(.decimalPad)
                    .onChange(of: flaecheText) { _, neu in
                        entwurf.flaecheM2 = Decimal(string: neu.replacingOccurrences(of: ",", with: ".")) ?? 0
                    }

                Picker("Nutzung", selection: $entwurf.nutzungsart) {
                    ForEach(Nutzungsart.allCases, id: \.self) { art in
                        Text(art.rawValue.capitalized).tag(art)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            Toggle("Wohnung ist vermietet", isOn: $entwurf.istVermietet)

            if entwurf.istVermietet {
                TextField("Mietername", text: $entwurf.mieterName)
                    .textContentType(.name)
                TextField("Anschrift Mieter (Straße, PLZ, Ort)", text: $entwurf.mieterAnschrift, axis: .vertical)
                    .textContentType(.fullStreetAddress)
                    .lineLimit(1...2)
                DatePicker(
                    "Einzug am",
                    selection: $entwurf.einzugAm,
                    displayedComponents: .date
                )
                .environment(\.locale, Locale(identifier: "de_DE"))
                HStack {
                    TextField("Monatliche Vorauszahlung", text: $entwurf.vorauszahlungText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                    Text("€").foregroundStyle(.secondary)
                }
            } else {
                Text("Mieter später eintragen")
                    .appFont(AppFont.caption())
                    .foregroundStyle(DesignTokens.textTertiary)
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            if flaecheText.isEmpty && entwurf.flaecheM2 > 0 {
                flaecheText = NSDecimalNumber(decimal: entwurf.flaecheM2).stringValue
            }
        }
    }
}
