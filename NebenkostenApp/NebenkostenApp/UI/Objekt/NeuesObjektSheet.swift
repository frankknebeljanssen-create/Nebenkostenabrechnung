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
//  Mietvertrag-Scan-Flow (M1 = Stub):
//  Ganz oben im Formular ein "Mietvertrag scannen"-Button. Wird er
//  getippt, oeffnet sich der Apple-Dokument-Scanner; anschliessend
//  laeuft ein Analyse-Overlay (`MietvertragsExtraktionService`
//  liefert deterministische Demo-Daten nach 1.5 s). Die erkannten
//  Felder werden ins Formular uebernommen und erhalten pro Zeile
//  einen kleinen Ampel-Punkt (gruen/gelb/rot), der die Konfidenz
//  der Extraktion anzeigt. Der User kann jeden Wert ueberschreiben;
//  sobald er das tut, verschwindet der Ampel-Punkt fuer dieses
//  Feld. M2 haengt dort den echten Claude-Call inkl.
//  PII-Schwaerzung ein, der Stub wird ersetzt.
//

import SwiftUI
import SwiftData
import UIKit

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

    // MARK: - Mietvertrag-Scan (M1)

    /// Apple-Dokument-Scanner ist offen.
    @State private var zeigeScanner: Bool = false

    /// Analyse-Overlay wird angezeigt (KI extrahiert gerade).
    @State private var zeigeAnalyse: Bool = false

    /// Ergebnis der letzten Extraktion — quelle fuer die Ampel-
    /// Punkte pro Feld. `nil`, wenn noch kein Scan gelaufen ist.
    @State private var extraktion: MietvertragsExtraktion? = nil

    /// Optionaler Fehler (Netzwerk, Parse) aus der Extraktion.
    @State private var scanFehler: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                scanSektion
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
        .fullScreenCover(isPresented: $zeigeScanner) {
            ScanService.kameraScanner(
                onFertig: { bilder in
                    zeigeScanner = false
                    starteAnalyse(bilder: bilder)
                },
                onAbbruch: { zeigeScanner = false },
                onFehler: { err in
                    zeigeScanner = false
                    scanFehler = err.localizedDescription
                }
            )
            .ignoresSafeArea()
        }
        .overlay { analyseOverlay }
        .alert(
            "Fehler beim Scan",
            isPresented: Binding(
                get: { scanFehler != nil },
                set: { if !$0 { scanFehler = nil } }
            ),
            actions: { Button("OK", role: .cancel) {} },
            message: { Text(scanFehler ?? "") }
        )
    }

    // MARK: - Sections

    /// Mietvertrag-Scan als erster Einstieg. Optional — wer lieber
    /// alles selbst eintippt, scrollt einfach weiter.
    @ViewBuilder
    private var scanSektion: some View {
        Section {
            Button {
                starteScan()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(DesignTokens.accent)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(extraktion == nil ? "Mietvertrag scannen" : "Mietvertrag erneut scannen")
                            .appFont(AppFont.bodySemi())
                            .foregroundStyle(DesignTokens.accent)
                        Text(extraktion == nil
                             ? "Felder automatisch vorausfüllen lassen"
                             : "Felder mit neuen Werten ersetzen")
                            .appFont(AppFont.caption())
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                    Spacer()
                    if extraktion != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(DesignTokens.statusOk)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!ScanService.istKameraVerfuegbar)

            if !ScanService.istKameraVerfuegbar {
                Text("Kamera auf diesem Gerät nicht verfügbar — manuelle Eingabe unten fortsetzen.")
                    .appFont(AppFont.caption())
                    .foregroundStyle(DesignTokens.textTertiary)
            } else if extraktion != nil {
                Text("Prüfe die farbig markierten Felder: grün = sicher, gelb = bitte prüfen, rot = unsicher.")
                    .appFont(AppFont.caption())
                    .foregroundStyle(DesignTokens.textTertiary)
            }
        } header: {
            Text("Mietvertrag")
        } footer: {
            Text("Optional. Felder werden nach dem Scan automatisch ausgefüllt und können manuell korrigiert werden.")
        }
    }

    /// Vollflaechiges Overlay waehrend die Extraktion laeuft.
    @ViewBuilder
    private var analyseOverlay: some View {
        if zeigeAnalyse {
            ZStack {
                Color.black.opacity(0.35).ignoresSafeArea()
                VStack(spacing: 14) {
                    ProgressView()
                        .scaleEffect(1.3)
                        .tint(DesignTokens.accent)
                    Text("Mietvertrag wird analysiert …")
                        .appFont(AppFont.bodySemi())
                        .foregroundStyle(DesignTokens.text)
                    Text("Nur wenige Sekunden")
                        .appFont(AppFont.caption())
                        .foregroundStyle(DesignTokens.textSecondary)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .background(DesignTokens.bgSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.black.opacity(0.2), radius: 24, y: 8)
            }
            .transition(.opacity)
            .zIndex(10)
        }
    }

    /// Prominentes Mieter-Feld GANZ OBEN im Formular. Bindet direkt
    /// an den Namen der ersten Einheit — das ist der typische Fall
    /// (ein Objekt, ein Hauptmieter). Bei mehreren Einheiten bleibt
    /// das Per-WE-Feld das Primaere; dieses Feld hier ist dann die
    /// Schnellspur fuer Einheit 1.
    @ViewBuilder
    private var hauptmieterSektion: some View {
        Section {
            HStack {
                TextField("Mietername", text: Binding(
                    get: { wohneinheiten.first?.mieterName ?? "" },
                    set: { neu in
                        guard !wohneinheiten.isEmpty else { return }
                        wohneinheiten[0].mieterName = neu
                    }
                ))
                .textContentType(.name)
                KonfidenzPunkt(farbe: AmpelHelper.farbe(
                    feld: extraktion?.mieterName,
                    aktuell: wohneinheiten.first?.mieterName ?? ""
                ))
            }
        } header: {
            Text("Mieter")
        } footer: {
            Text("Name des Hauptmieters. Weitere Mieter werden bei den jeweiligen Wohneinheiten eingetragen.")
        }
    }

    private var adresseSektion: some View {
        Section("Adresse") {
            HStack {
                TextField("Straße und Hausnummer", text: $adresse)
                    .textContentType(.streetAddressLine1)
                KonfidenzPunkt(farbe: AmpelHelper.farbe(feld: extraktion?.adresse, aktuell: adresse))
            }
            HStack {
                TextField("PLZ", text: $plz)
                    .textContentType(.postalCode)
                    .keyboardType(.numberPad)
                KonfidenzPunkt(farbe: AmpelHelper.farbe(feld: extraktion?.plz, aktuell: plz))
            }
            HStack {
                TextField("Ort / Stadt", text: $stadt)
                    .textContentType(.addressCity)
                KonfidenzPunkt(farbe: AmpelHelper.farbe(feld: extraktion?.stadt, aktuell: stadt))
            }
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
                KonfidenzPunkt(farbe: AmpelHelper.farbe(
                    feld: extraktion?.gesamtflaecheM2,
                    aktuell: gesamtflaecheDecimal ?? Decimal(-1)
                ))
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
                // Ampeln nur auf der ersten Einheit — der Stub
                // liefert genau eine Einheit pro Mietvertrag.
                let istErste = wohneinheiten.first?.id == entwurf.id
                EinheitZeile(
                    entwurf: $entwurf,
                    extraktion: istErste ? extraktion : nil
                )
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

    private static func decimalText(_ d: Decimal) -> String {
        let nf = NumberFormatter()
        nf.locale = Locale(identifier: "de_DE")
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 2
        nf.groupingSeparator = ""
        return nf.string(from: NSDecimalNumber(decimal: d)) ?? "\(d)"
    }

    // MARK: - Mietvertrag-Scan Flow (M1)

    private func starteScan() {
        scanFehler = nil
        zeigeScanner = true
    }

    private func starteAnalyse(bilder: [UIImage]) {
        guard !bilder.isEmpty else { return }
        zeigeAnalyse = true
        Task {
            do {
                let analyse = try await MietvertragsExtraktionService.extrahiere(ausBildern: bilder)
                uebernehmeExtraktion(analyse.extraktion)
                extraktion = analyse.extraktion
            } catch {
                scanFehler = error.localizedDescription
            }
            zeigeAnalyse = false
        }
    }

    /// Alle nicht-nil Felder der Extraktion in die Formular-States
    /// uebernehmen. Leere Einheitenliste wird abgefangen — der
    /// Default-Init liefert immer mindestens eine Einheit.
    private func uebernehmeExtraktion(_ e: MietvertragsExtraktion) {
        if let a = e.adresse.wert { adresse = a }
        if let p = e.plz.wert { plz = p }
        if let s = e.stadt.wert { stadt = s }
        if let f = e.gesamtflaecheM2.wert { gesamtflaecheText = Self.decimalText(f) }

        guard !wohneinheiten.isEmpty else { return }
        if let b = e.einheitBezeichnung.wert { wohneinheiten[0].bezeichnung = b }
        if let f = e.einheitFlaecheM2.wert   { wohneinheiten[0].flaecheM2 = f }
        if let m = e.mieterName.wert {
            wohneinheiten[0].mieterName = m
            wohneinheiten[0].istVermietet = true
        }
        if let a = e.mieterAnschrift.wert { wohneinheiten[0].mieterAnschrift = a }
        if let d = e.einzugAm.wert        { wohneinheiten[0].einzugAm = d }
        if let v = e.vorauszahlungMonatEuro.wert {
            wohneinheiten[0].vorauszahlungText = Self.decimalText(v)
        }
    }
}

// MARK: - Konfidenz-Ampel

/// Berechnet die Ampel-Farbe fuer einen Formular-Feld-Wert in
/// Abhaengigkeit von der letzten Mietvertrags-Extraktion. Regel:
/// der Punkt erscheint nur, wenn das aktuelle Feld noch identisch
/// mit dem extrahierten Wert ist — sobald der User tippt, verliert
/// das Feld den Konfidenz-Marker (der User-Wert ist dann
/// "seiner", nicht mehr "der KI").
fileprivate enum AmpelHelper {
    static func farbe<T: Equatable>(
        feld: FeldMitKonfidenz<T>?,
        aktuell: T
    ) -> Color? {
        guard let feld, let wert = feld.wert, wert == aktuell else { return nil }
        if feld.konfidenz >= 0.8 { return DesignTokens.statusOk }
        if feld.konfidenz >= 0.5 { return DesignTokens.statusWarn }
        return DesignTokens.statusError
    }
}

/// 8-pt Kreis in der Ampel-Farbe. Rendert nichts, wenn `farbe`
/// nil ist — so kann die Zeile einfach einen Punkt einblenden
/// oder nicht, ohne Layout-Jitter.
fileprivate struct KonfidenzPunkt: View {
    let farbe: Color?
    var body: some View {
        if let farbe {
            Circle()
                .fill(farbe)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
        }
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
    /// Nur gesetzt, wenn diese Zeile die erste Einheit ist und ein
    /// Mietvertrag-Scan gelaufen ist — in dem Fall zeigen die
    /// relevanten Felder ihren Konfidenz-Punkt.
    var extraktion: MietvertragsExtraktion? = nil

    @State private var flaecheText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("Bezeichnung (z.B. EG, OG, Datsche)", text: $entwurf.bezeichnung)
                KonfidenzPunkt(farbe: AmpelHelper.farbe(
                    feld: extraktion?.einheitBezeichnung,
                    aktuell: entwurf.bezeichnung
                ))
            }

            HStack {
                TextField("Fläche m²", text: $flaecheText)
                    .keyboardType(.decimalPad)
                    .onChange(of: flaecheText) { _, neu in
                        entwurf.flaecheM2 = Decimal(string: neu.replacingOccurrences(of: ",", with: ".")) ?? 0
                    }
                KonfidenzPunkt(farbe: AmpelHelper.farbe(
                    feld: extraktion?.einheitFlaecheM2,
                    aktuell: entwurf.flaecheM2
                ))

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
                HStack {
                    TextField("Mietername", text: $entwurf.mieterName)
                        .textContentType(.name)
                    KonfidenzPunkt(farbe: AmpelHelper.farbe(
                        feld: extraktion?.mieterName,
                        aktuell: entwurf.mieterName
                    ))
                }
                HStack(alignment: .top) {
                    TextField("Anschrift Mieter (Straße, PLZ, Ort)", text: $entwurf.mieterAnschrift, axis: .vertical)
                        .textContentType(.fullStreetAddress)
                        .lineLimit(1...2)
                    KonfidenzPunkt(farbe: AmpelHelper.farbe(
                        feld: extraktion?.mieterAnschrift,
                        aktuell: entwurf.mieterAnschrift
                    ))
                    .padding(.top, 8)
                }
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
                    KonfidenzPunkt(farbe: AmpelHelper.farbe(
                        feld: extraktion?.vorauszahlungMonatEuro,
                        aktuell: Decimal(string: entwurf.vorauszahlungText.replacingOccurrences(of: ",", with: ".")) ?? Decimal(-1)
                    ))
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
        .onChange(of: entwurf.flaecheM2) { _, neu in
            // Nach Mietvertrag-Scan-Uebernahme den Feld-Text
            // nachziehen. Nur ueberschreiben, wenn der aktuell
            // eingetippte Text NICHT bereits den neuen Wert
            // darstellt — so geht "65,5" des Users nicht verloren.
            let aktuellerParsed = Decimal(
                string: flaecheText.replacingOccurrences(of: ",", with: ".")
            ) ?? 0
            if aktuellerParsed != neu {
                flaecheText = neu > 0 ? NSDecimalNumber(decimal: neu).stringValue : ""
            }
        }
    }
}
