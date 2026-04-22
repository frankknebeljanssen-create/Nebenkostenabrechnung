//
//  StammdatenView.swift
//  NebenkostenApp — UI/Kacheln
//
//  Kachel-Screen der Stammdaten-Kategorie. Wird aus
//  `KachelansichtView` per `NavigationLink` geoeffnet und zeigt:
//
//    - Fortschrittsbalken (Completion der Stammdaten-Anforderungen)
//    - Sektion A — Objekt (Adresse, Flaeche, Heizungsart, Periode)
//    - Sektion B — Mieter pro Wohneinheit (Name, Einzug,
//      Vorauszahlung, Mietvertrag)
//    - Sektion C — Dokumente (Energieausweis, Grundsteuer-Bescheid)
//    - Bottom-CTA "Dokument scannen" → Typ-Picker-Sheet → Scan-Flow
//
//  Alle Edit-Views (ObjektEditView, WohneinheitEditView,
//  PeriodeEditView, MieterEditView, VorauszahlungEingabeSheet)
//  werden als Sheets von hier geoeffnet. Dokumenten-Anzeige ueber
//  `PDFVorschauView` im Sheet.
//

import SwiftUI
import SwiftData

struct StammdatenView: View {
    @Environment(ScopeManager.self) private var scope
    @Environment(AppShellRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Immobilie.erstelltAm) private var immobilien: [Immobilie]

    // MARK: - Sheet-States

    @State private var zeigeObjektEdit = false
    @State private var periodeBearbeiten: Abrechnungsperiode?
    @State private var einheitBearbeiten: Wohneinheit?
    @State private var mieterBearbeiten: Mietverhaeltnis?
    @State private var mieterNeuFuer: Wohneinheit?
    @State private var pdfVorschauURL: URL?
    @State private var zeigeTypPicker = false
    /// Typ + Ziel-Verlinkung fuer den aus dem Bottom-CTA gestarteten
    /// Scan — wird gesetzt, sobald der User im `TypPickerSheet`
    /// einen Typ gewaehlt hat. Nach Scan triggert das `onFertig` die
    /// passende Relation (Stammdaten-Dokument oder Mietvertrag).
    @State private var aktiverScan: AktiverScan?

    struct AktiverScan: Identifiable {
        let id = UUID()
        let typ: Dokumenttyp
        /// Wenn gesetzt: Mietvertrag-Scan fuer genau dieses MV —
        /// `onFertig` setzt `mv.mietvertragDokument`.
        /// Nil: Stammdaten-Dokument → haengt an der Immobilie.
        let mietvertragFuer: Mietverhaeltnis?
    }

    // MARK: - Abgeleitet

    private var aktiveImmobilie: Immobilie? {
        if let id = scope.aktuelleImmobilieID,
           let treffer = immobilien.first(where: { $0.id == id }) {
            return treffer
        }
        return immobilien.first
    }

    private var aktivePeriode: Abrechnungsperiode? {
        let perioden = (aktiveImmobilie?.perioden ?? [])
            .sorted(by: { $0.bis > $1.bis })
        let heute = Date()
        return perioden.first(where: { $0.bis < heute }) ?? perioden.first
    }

    private var anforderungen: [AnforderungMitStatus] {
        guard let immobilie = aktiveImmobilie,
              let p = aktivePeriode else { return [] }
        return VollstaendigkeitsPruefung.pruefe(immobilie: immobilie, periode: p)
            .filter { $0.anforderung.kategorie == .stammdaten }
    }

    private var zusammenfassung: VollstaendigkeitsPruefung.Zusammenfassung {
        VollstaendigkeitsPruefung.zusammenfassung(fuer: anforderungen)
    }

    private var prozent: Int { zusammenfassung.completionProzent }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                fortschrittHeader
                if let immobilie = aktiveImmobilie {
                    sektionObjekt(immobilie)
                    sektionMieter(immobilie)
                    sektionDokumente(immobilie)
                } else {
                    leerHinweis
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 100)
        }
        .overlay(alignment: .bottom) { scanCTA }
        .background(DesignTokens.bgAppCompact)
        .navigationTitle("Stammdaten")
        .navigationBarTitleDisplayMode(.inline)
        // Sheets
        .sheet(isPresented: $zeigeObjektEdit) {
            if let immobilie = aktiveImmobilie {
                ObjektEditView(immobilie: immobilie)
            }
        }
        .sheet(item: $periodeBearbeiten) { p in
            PeriodeEditView(modus: .bearbeiten(p))
        }
        .sheet(item: $einheitBearbeiten) { e in
            WohneinheitEditView(modus: .bearbeiten(e))
        }
        .sheet(item: $mieterBearbeiten) { mv in
            MieterEditView(modus: .bearbeiten(mv))
        }
        .sheet(item: $mieterNeuFuer) { einheit in
            if let immobilie = aktiveImmobilie {
                MieterEditView(modus: .neu(
                    immobilie: immobilie,
                    vorauswahl: einheit
                ))
            }
        }
        .sheet(item: $pdfVorschauURL) { url in
            NavigationStack {
                PDFVorschauView(url: url)
                    .ignoresSafeArea(edges: .bottom)
                    .navigationTitle("Dokument")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            SheetToolbar.abbrechen(titel: "Schließen") {
                                pdfVorschauURL = nil
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $zeigeTypPicker) {
            TypPickerSheet { typ in
                zeigeTypPicker = false
                aktiverScan = AktiverScan(typ: typ, mietvertragFuer: nil)
            }
        }
        .sheet(item: $aktiverScan) { scan in
            ScanEntryView(
                vorausgewaehlterTyp: scan.typ,
                onFertig: { dokument in
                    verknuepfe(dokument: dokument, mit: scan)
                }
            )
        }
    }

    // MARK: - Fortschritts-Header

    private var fortschrittHeader: some View {
        let anzahlGesamt = zusammenfassung.total - zusammenfassung.nichtErwartet
        let anzahlOK = zusammenfassung.erfuellt
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Vollständigkeit")
                    .appFont(AppFont.Basis.kicker())
                    .foregroundStyle(DesignTokens.textSecondary)
                Spacer()
                Text("\(prozent) %")
                    .appFont(AppFont.Basis.monoBodySemi())
                    .foregroundStyle(CompletionFarbe.fuer(prozent: prozent))
            }
            fortschrittsBalken
            Text("\(anzahlOK) von \(anzahlGesamt) vollständig")
                .appFont(AppFont.Basis.caption())
                .foregroundStyle(DesignTokens.textTertiary)
        }
    }

    private var fortschrittsBalken: some View {
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

    // MARK: - Sektion A · Objekt

    private func sektionObjekt(_ immobilie: Immobilie) -> some View {
        CollapsibleSection(
            titel: "Objekt",
            persistKey: "stammdaten.objekt.offen",
            defaultOffen: true
        ) {
            VStack(spacing: 0) {
                StammdatenRow(
                    label: "Adresse",
                    wert: immobilieAdresseZeile(immobilie),
                    tappbar: true,
                    onTap: { zeigeObjektEdit = true }
                )
                DividerLine()
                StammdatenRow(
                    label: "Gesamtfläche",
                    wert: Formatting.m2(immobilie.gesamtflaecheM2),
                    mono: true,
                    tappbar: true,
                    onTap: { zeigeObjektEdit = true }
                )
                DividerLine()
                StammdatenRow(
                    label: "Heizung",
                    wert: immobilie.heizungsart.rawValue,
                    tappbar: true,
                    onTap: { zeigeObjektEdit = true }
                )
                DividerLine()
                StammdatenRow(
                    label: "Abrechnungsperiode",
                    wert: periodeZeile(),
                    mono: aktivePeriode != nil,
                    tappbar: aktivePeriode != nil,
                    onTap: {
                        if let p = aktivePeriode {
                            periodeBearbeiten = p
                        }
                    }
                )
            }
        }
    }

    private func immobilieAdresseZeile(_ i: Immobilie) -> String {
        let adresse = i.adresse.trimmingCharacters(in: .whitespaces)
        let ort = i.ort.trimmingCharacters(in: .whitespaces)
        switch (adresse.isEmpty, ort.isEmpty) {
        case (false, false): return "\(adresse), \(ort)"
        case (false, true):  return adresse
        case (true, false):  return ort
        case (true, true):   return "—"
        }
    }

    private func periodeZeile() -> String {
        guard let p = aktivePeriode else { return "—" }
        return Formatting.periode(p.von, p.bis)
    }

    // MARK: - Sektion B · Mieter pro WE

    private func sektionMieter(_ immobilie: Immobilie) -> some View {
        let einheiten = ScopeFilter.sichtbareEinheiten(
            alle: immobilie.wohneinheiten ?? [],
            scope: .objekt
        )
        return VStack(alignment: .leading, spacing: 18) {
            ForEach(einheiten) { einheit in
                CollapsibleSection(
                    titel: einheitHeader(einheit),
                    persistKey: "stammdaten.mieter.\(einheit.bezeichnung).offen",
                    defaultOffen: true
                ) {
                    einheitInhalt(einheit)
                }
            }
        }
    }

    private func einheitHeader(_ e: Wohneinheit) -> String {
        let bezeichnung = e.bezeichnung.uppercased()
        return bezeichnung.isEmpty ? "Einheit" : bezeichnung
    }

    @ViewBuilder
    private func einheitInhalt(_ einheit: Wohneinheit) -> some View {
        let aktiverMieter = (einheit.mietverhaeltnisse ?? [])
            .first(where: { $0.auszugAm == nil })
        VStack(spacing: 0) {
            StammdatenRow(
                label: "Mieter",
                wert: aktiverMieter?.mieterName ?? "Neu anlegen",
                tappbar: true,
                onTap: {
                    if let mv = aktiverMieter {
                        mieterBearbeiten = mv
                    } else {
                        mieterNeuFuer = einheit
                    }
                }
            )
            DividerLine()
            StammdatenRow(
                label: "Einzug",
                wert: aktiverMieter.map { Formatting.datum($0.einzugAm) } ?? "—",
                mono: aktiverMieter != nil,
                tappbar: aktiverMieter != nil,
                onTap: {
                    if let mv = aktiverMieter { mieterBearbeiten = mv }
                }
            )
            DividerLine()
            StammdatenRow(
                label: "Vorauszahlung",
                wert: vorauszahlungText(aktiverMieter),
                mono: aktiverMieter?.vorauszahlungErfasst == true,
                tappbar: true,
                onTap: {
                    router.oeffneVorauszahlungSheet(einheitID: einheit.bezeichnung)
                }
            )
            DividerLine()
            mietvertragRow(einheit: einheit, mieter: aktiverMieter)
        }
    }

    private func vorauszahlungText(_ mv: Mietverhaeltnis?) -> String {
        guard let mv, mv.vorauszahlungErfasst else { return "Nicht erfasst" }
        return Formatting.euro(mv.vorauszahlungMonatEuro) + " / Monat"
    }

    @ViewBuilder
    private func mietvertragRow(einheit: Wohneinheit, mieter: Mietverhaeltnis?) -> some View {
        if let mv = mieter {
            if let doc = mv.mietvertragDokument {
                StammdatenRow(
                    label: "Mietvertrag",
                    wert: "Anzeigen",
                    wertFarbe: DesignTokens.accent,
                    tappbar: true,
                    onTap: { oeffnePDF(dokument: doc) }
                )
            } else {
                StammdatenRow(
                    label: "Mietvertrag",
                    wert: "Scannen",
                    wertFarbe: DesignTokens.accent,
                    tappbar: true,
                    onTap: {
                        aktiverScan = AktiverScan(
                            typ: .mietvertrag,
                            mietvertragFuer: mv
                        )
                    }
                )
            }
        } else {
            StammdatenRow(
                label: "Mietvertrag",
                wert: "Mieter fehlt",
                tappbar: false,
                onTap: {}
            )
        }
    }

    // MARK: - Sektion C · Dokumente

    private func sektionDokumente(_ immobilie: Immobilie) -> some View {
        CollapsibleSection(
            titel: "Dokumente",
            persistKey: "stammdaten.dokumente.offen",
            defaultOffen: false
        ) {
            VStack(spacing: 0) {
                dokumentRow(
                    label: "Energieausweis",
                    typ: .energieausweis,
                    immobilie: immobilie,
                    abgelaufenNachJahren: 10
                )
                DividerLine()
                dokumentRow(
                    label: "Grundsteuer-Bescheid",
                    typ: .grundsteuerbescheid,
                    immobilie: immobilie,
                    abgelaufenNachJahren: nil
                )
            }
        }
    }

    @ViewBuilder
    private func dokumentRow(
        label: String,
        typ: Dokumenttyp,
        immobilie: Immobilie,
        abgelaufenNachJahren: Int?
    ) -> some View {
        let doc = (immobilie.stammdatenDokumente ?? [])
            .filter { $0.dokumenttyp == typ }
            .sorted { $0.erstelltAm > $1.erstelltAm }
            .first
        if let doc {
            let abgelaufen = istAbgelaufen(doc, jahre: abgelaufenNachJahren)
            StammdatenRow(
                label: label,
                wert: Formatting.datum(doc.erstelltAm),
                mono: true,
                trailing: {
                    if abgelaufen {
                        StatusPill(text: "Abgelaufen", style: .error)
                    } else {
                        EmptyView()
                    }
                },
                tappbar: true,
                onTap: { oeffnePDF(dokument: doc) }
            )
        } else {
            StammdatenRow(
                label: label,
                wert: "Scannen",
                wertFarbe: DesignTokens.accent,
                tappbar: true,
                onTap: {
                    aktiverScan = AktiverScan(typ: typ, mietvertragFuer: nil)
                }
            )
        }
    }

    private func istAbgelaufen(_ doc: GespeichertesDokument, jahre: Int?) -> Bool {
        guard let jahre else { return false }
        let kal = Calendar(identifier: .gregorian)
        guard let grenze = kal.date(byAdding: .year, value: jahre, to: doc.erstelltAm) else {
            return false
        }
        return grenze < Date()
    }

    // MARK: - Bottom-CTA

    private var scanCTA: some View {
        VStack(spacing: 0) {
            DividerLine()
            Button {
                zeigeTypPicker = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "doc.viewfinder")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Dokument scannen")
                        .appFont(AppFont.Basis.bodySemi())
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(DesignTokens.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .background(DesignTokens.bgAppCompact)
    }

    // MARK: - Leerhinweis

    private var leerHinweis: some View {
        VStack(spacing: 12) {
            Image(systemName: "house")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(DesignTokens.textSecondary)
            Text("Kein Objekt ausgewählt")
                .appFont(AppFont.Basis.bodySemi())
                .foregroundStyle(DesignTokens.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Helpers

    private func oeffnePDF(dokument: GespeichertesDokument) {
        guard let url = try? DokumentAblageService.absoluterPfad(
            fuer: dokument.dateipfadRelativ
        ) else { return }
        pdfVorschauURL = url
    }

    /// Setzt nach erfolgreichem Scan die richtige Relation:
    /// Mietvertrag → an das gegebene MV. Stammdaten-Dokument → an
    /// die Immobilie. Callback laeuft im MainActor-Kontext, save
    /// erfolgt synchron.
    private func verknuepfe(dokument: GespeichertesDokument, mit scan: AktiverScan) {
        if let mv = scan.mietvertragFuer {
            mv.mietvertragDokument = dokument
        } else if let immobilie = aktiveImmobilie {
            dokument.immobilie = immobilie
        }
        try? modelContext.save()
    }
}

// MARK: - StammdatenRow

/// Einheitliche Row im Stammdaten-Screen. Layout nach Spec:
/// `HStack { label (textSecondary 13pt) | wert (bodySemi) |
///  chevron }`, 12pt vertikal + 16pt horizontal Padding.
fileprivate struct StammdatenRow<Trailing: View>: View {
    let label: String
    let wert: String
    var wertFarbe: Color = DesignTokens.text
    var mono: Bool = false
    @ViewBuilder var trailing: () -> Trailing
    var tappbar: Bool = false
    var onTap: () -> Void = {}

    init(
        label: String,
        wert: String,
        wertFarbe: Color = DesignTokens.text,
        mono: Bool = false,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() },
        tappbar: Bool = false,
        onTap: @escaping () -> Void = {}
    ) {
        self.label = label
        self.wert = wert
        self.wertFarbe = wertFarbe
        self.mono = mono
        self.trailing = trailing
        self.tappbar = tappbar
        self.onTap = onTap
    }

    var body: some View {
        Button {
            if tappbar { onTap() }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(label)
                    .appFont(AppFont.Basis.subtitle())
                    .foregroundStyle(DesignTokens.textSecondary)
                Spacer(minLength: 8)
                Text(wert)
                    .appFont(mono
                             ? AppFont.Basis.monoBodySemi()
                             : AppFont.Basis.bodySemi())
                    .foregroundStyle(wertFarbe)
                    .lineLimit(1)
                    .truncationMode(.tail)
                trailing()
                if tappbar {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!tappbar)
    }
}

// MARK: - TypPickerSheet

/// Auswahl des Dokumenttyps vor dem eigentlichen Scan. Drei feste
/// Optionen (Energieausweis, Grundsteuer-Bescheid, Mietvertrag)
/// plus "Sonstiges" als Fallback. Nach Tap: Callback, der den
/// eigentlichen Scan startet.
fileprivate struct TypPickerSheet: View {
    let onAuswahl: (Dokumenttyp) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    zeile(.energieausweis, symbol: "doc.badge.gearshape")
                    zeile(.grundsteuerbescheid, symbol: "doc.text")
                    zeile(.mietvertrag, symbol: "doc.text.fill")
                }
                Section("Sonstiges") {
                    zeile(.sonstiges, symbol: "doc")
                }
            }
            .navigationTitle("Was soll gescannt werden?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetToolbar.abbrechen { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func zeile(_ typ: Dokumenttyp, symbol: String) -> some View {
        Button { onAuswahl(typ) } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DesignTokens.accent)
                    .frame(width: 32)
                Text(typ.anzeigeName)
                    .appFont(AppFont.Basis.bodySemi())
                    .foregroundStyle(DesignTokens.text)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - URL + Identifiable (fuer sheet(item:))

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
