//
//  BelegeView.swift
//  NebenkostenApp — UI/Belege
//
//  Belege-Tab nach Design-Handoff. Nutzt GespeichertesDokument (Task
//  1.1/1.2). Aufbau:
//    1. Kennzahlen-Card — Dokumente gesamt, mit OCR, validiert.
//    2. Monats-Cards — pro Jahr-Monat ein Card mit Rows: Thumbnail,
//       Dateiname, Typ · Datum · Seitenzahl, Pipeline-StatusPill.
//       Tap auf Row → PDFVorschauSheet bzw. ValidierungsView je nach
//       Pipeline-Stage.
//    3. Scan-Button als primärer Action in der Card (bis NavBar-
//       Actions in C8 aktiviert werden).
//
//  Scope-Filter:
//    Objekt-Scope → alle Belege der Immobilie.
//    Einheit-Scope → nur Belege mit einheitId == <scope-id>.
//    Fußzeile macht die Filterung explizit.
//

import SwiftUI
import SwiftData
import UIKit

struct BelegeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ScopeManager.self) private var scope

    @Query(sort: \GespeichertesDokument.erstelltAm, order: .reverse)
    private var alleDokumente: [GespeichertesDokument]

    @State private var zeigeScopePicker = false
    @State private var zeigeEinstellungen = false
    @State private var zeigeScan = false
    @State private var vorschauDokument: GespeichertesDokument?
    @State private var validierungsDokument: GespeichertesDokument?
    @State private var zuLoeschen: GespeichertesDokument?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                kennzahlenCard
                if sichtbareDokumente.isEmpty {
                    leerZustand
                } else {
                    VStack(spacing: 10) {
                        ForEach(monatsgruppen, id: \.schluessel) { gruppe in
                            monatsCard(gruppe)
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
        .appShellChrome(
            titel: "Belege",
            subtitel: subtitel,
            onAdresse: { zeigeScopePicker = true },
            onEinstellungen: { zeigeEinstellungen = true }
        )
        .sheet(isPresented: $zeigeScopePicker) { ScopePickerSheet() }
        .sheet(isPresented: $zeigeEinstellungen) { EinstellungenSheet() }
        .sheet(isPresented: $zeigeScan) {
            ScanEntryView { _ in }
        }
        .sheet(item: $validierungsDokument) { d in
            ValidierungsView(dokument: d)
        }
        .sheet(item: $vorschauDokument) { d in
            vorschauSheet(d)
        }
        .alert(
            "Dokument löschen?",
            isPresented: .init(
                get: { zuLoeschen != nil },
                set: { if !$0 { zuLoeschen = nil } }
            ),
            actions: {
                Button("Abbrechen", role: .cancel) { zuLoeschen = nil }
                Button("Löschen", role: .destructive) {
                    if let d = zuLoeschen {
                        DokumentAblageService.loesche(d, context: modelContext)
                        try? modelContext.save()
                    }
                    zuLoeschen = nil
                }
            },
            message: {
                Text("Datei und Eintrag werden unwiderruflich entfernt.")
            }
        )
    }

    // MARK: - Kennzahlen

    private var kennzahlenCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Belege")
                        .appFont(AppFont.uppercaseLabel())
                        .foregroundStyle(DesignTokens.textTertiary)
                    Spacer()
                    Text("\(sichtbareDokumente.count) gesamt")
                        .appFont(AppFont.monoCaption())
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                PeriodStatsBlock(
                    links: StatBlock(
                        label: "Validiert",
                        wert: "\(validierteCount)",
                        detail: validiertDetail
                    ),
                    rechts: StatBlock(
                        label: "Neu",
                        wert: "\(neueCount)",
                        detail: "brauchen Prüfung"
                    )
                )
                DividerLine()
                Button {
                    zeigeScan = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.viewfinder")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Beleg scannen oder importieren")
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

    // MARK: - Monatsgruppe

    private func monatsCard(_ gruppe: Monatsgruppe) -> some View {
        CollapsibleSection(
            titel: gruppe.ueberschrift,
            summary: nil,
            count: gruppe.dokumente.count,
            persistKey: "belege.monat.\(gruppe.schluessel).open",
            defaultOffen: gruppe.schluessel == Self.aktuellerMonatsSchluessel
        ) {
            VStack(spacing: 0) {
                ForEach(Array(gruppe.dokumente.enumerated()), id: \.element.id) { idx, d in
                    Button {
                        handleTap(d)
                    } label: {
                        zeile(d)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            validierungsDokument = d
                        } label: {
                            Label("Validieren", systemImage: "sparkles")
                        }
                        Button {
                            vorschauDokument = d
                        } label: {
                            Label("Vorschau", systemImage: "eye")
                        }
                        Button(role: .destructive) {
                            zuLoeschen = d
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                    if idx < gruppe.dokumente.count - 1 {
                        DividerLine()
                    }
                }
            }
        }
    }

    private static var aktuellerMonatsSchluessel: String {
        monatsSchluesselFormatter.string(from: Date())
    }

    private func zeile(_ d: GespeichertesDokument) -> some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail(d)
            VStack(alignment: .leading, spacing: 4) {
                Text(d.dateiname)
                    .appFont(AppFont.bodyMedium())
                    .foregroundStyle(DesignTokens.text)
                    .lineLimit(1)
                Text(metaZeile(d))
                    .appFont(AppFont.caption())
                    .foregroundStyle(DesignTokens.textSecondary)
                    .lineLimit(1)
                pipelineBadge(d)
                    .padding(.top, 2)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(DesignTokens.textTertiary)
                .padding(.top, 14)
        }
    }

    @ViewBuilder
    private func thumbnail(_ d: GespeichertesDokument) -> some View {
        if let bild = thumbnailBild(d) {
            Image(uiImage: bild)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            ZStack {
                Image(systemName: symbolFuer(d.dokumenttyp))
                    .font(.system(size: 18))
                    .foregroundStyle(DesignTokens.accent)
            }
            .frame(width: 48, height: 62)
            .background(DesignTokens.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func metaZeile(_ d: GespeichertesDokument) -> String {
        var parts: [String] = [d.dokumenttyp.anzeigeName]
        if let vg = d.versorger, !vg.isEmpty { parts.append(vg) }
        parts.append(Formatting.datum(d.erstelltAm))
        if d.seitenanzahl > 1 {
            parts.append("\(d.seitenanzahl) Seiten")
        }
        return parts.joined(separator: " · ")
    }

    private func pipelineBadge(_ d: GespeichertesDokument) -> some View {
        let (text, style) = pipelineBadgeStyle(d)
        return StatusPill(text: text, style: style)
    }

    private func pipelineBadgeStyle(_ d: GespeichertesDokument) -> (String, StatusPill.Style) {
        if d.rechnungId != nil { return ("Validiert", .ok) }
        if d.aiVorschlag != nil { return ("KI-Vorschlag", .warn) }
        if d.ocrVolltext != nil { return ("OCR vorhanden", .accent) }
        return ("Roh", .muted)
    }

    private func handleTap(_ d: GespeichertesDokument) {
        // Pipeline-Stage bestimmt Default-Aktion:
        //   - Noch kein OCR / nur OCR → Vorschau.
        //   - AI-Vorschlag vorhanden (unvalidiert) → Validierung.
        //   - Validiert (rechnungId gesetzt) → Vorschau.
        if d.aiVorschlag != nil && d.rechnungId == nil {
            validierungsDokument = d
        } else {
            vorschauDokument = d
        }
    }

    // MARK: - Vorschau

    @ViewBuilder
    private func vorschauSheet(_ d: GespeichertesDokument) -> some View {
        NavigationStack {
            if let url = try? DokumentAblageService.absoluterPfad(
                fuer: d.dateipfadRelativ
            ),
               FileManager.default.fileExists(atPath: url.path) {
                PDFVorschauView(url: url)
                    .ignoresSafeArea()
                    .navigationTitle(d.dateiname)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Fertig") { vorschauDokument = nil }
                        }
                    }
            } else {
                Text("Datei nicht gefunden.")
                    .appFont(AppFont.caption())
                    .foregroundStyle(DesignTokens.textSecondary)
            }
        }
    }

    // MARK: - Scope-Hinweis

    @ViewBuilder
    private var scopeHinweis: some View {
        if case .einheit(let id) = scope.current {
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.textTertiary)
                Text("Nur Belege, die der Einheit \(id) zugeordnet sind.")
                    .appFont(AppFont.caption())
                    .foregroundStyle(DesignTokens.textTertiary)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.top, 4)
        }
    }

    private var leerZustand: some View {
        Card {
            VStack(spacing: 12) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 28))
                    .foregroundStyle(DesignTokens.textTertiary)
                Text(leerZustandTitel)
                    .appFont(AppFont.bodySemi())
                    .foregroundStyle(DesignTokens.text)
                Text("Tippe oben auf Scannen oder Importieren, um einen Beleg hinzuzufügen.")
                    .appFont(AppFont.caption())
                    .foregroundStyle(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private var leerZustandTitel: String {
        switch scope.current {
        case .objekt:          return "Noch keine Belege erfasst"
        case .einheit(let id): return "Keine Belege für \(id)"
        }
    }

    // MARK: - Daten

    private var subtitel: String? {
        switch scope.current {
        case .objekt:          return nil
        case .einheit(let id): return "Belege · \(id)"
        }
    }

    private var sichtbareDokumente: [GespeichertesDokument] {
        ScopeFilter.sichtbareDokumente(alle: alleDokumente, scope: scope.current)
    }

    private var validierteCount: Int {
        sichtbareDokumente.filter { $0.rechnungId != nil }.count
    }

    private var neueCount: Int {
        sichtbareDokumente.filter { $0.ocrVolltext == nil || $0.aiVorschlag != nil && $0.rechnungId == nil }.count
    }

    private var validiertDetail: String {
        if sichtbareDokumente.isEmpty { return "—" }
        let p = Double(validierteCount) / Double(sichtbareDokumente.count)
        return Formatting.prozent(p, dezimal: 0)
    }

    // MARK: - Monats-Gruppierung

    private struct Monatsgruppe {
        let schluessel: String
        let ueberschrift: String
        let dokumente: [GespeichertesDokument]
    }

    private var monatsgruppen: [Monatsgruppe] {
        let dict = Dictionary(grouping: sichtbareDokumente) { d -> String in
            Self.monatsSchluessel(d.erstelltAm)
        }
        return dict
            .map { (key, liste) -> Monatsgruppe in
                Monatsgruppe(
                    schluessel: key,
                    ueberschrift: Self.monatsUeberschrift(liste.first?.erstelltAm ?? Date()),
                    dokumente: liste.sorted { $0.erstelltAm > $1.erstelltAm }
                )
            }
            .sorted { $0.schluessel > $1.schluessel }
    }

    private static let monatsSchluesselFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        f.timeZone = TimeZone.current
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let monatsUeberschriftFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        f.timeZone = TimeZone.current
        f.locale = Locale(identifier: "de_DE")
        return f
    }()

    private static func monatsSchluessel(_ datum: Date) -> String {
        monatsSchluesselFormatter.string(from: datum)
    }

    private static func monatsUeberschrift(_ datum: Date) -> String {
        monatsUeberschriftFormatter.string(from: datum).capitalized
    }

    // MARK: - Helper

    private func thumbnailBild(_ d: GespeichertesDokument) -> UIImage? {
        guard !d.thumbnailPfad.isEmpty,
              let url = try? DokumentAblageService.absoluterPfad(
                fuer: d.thumbnailPfad
              ),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return UIImage(data: data)
    }

    private func symbolFuer(_ typ: Dokumenttyp) -> String {
        switch typ {
        case .rechnung:          return "doc.text.fill"
        case .bescheid:          return "building.columns.fill"
        case .handwerkerbeleg:   return "wrench.and.screwdriver.fill"
        case .winterdienstbeleg: return "snowflake"
        case .zaehlerfoto:       return "gauge.medium"
        case .mietvertrag:       return "person.text.rectangle.fill"
        case .sonstiges:         return "doc.text"
        }
    }
}
