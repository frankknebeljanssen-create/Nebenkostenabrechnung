//
//  UniversellerAnalyseScreen.swift
//  NebenkostenApp — UI/Scan
//
//  Zentraler Hub nach dem globalen Scan-Einwurf. Flow:
//
//    1. `AppShell`-FAB → `ScanEntryView` → Dokument abgelegt.
//    2. AppShell setzt `router.analyseSheet = AnalyseKontext(dokumentID)`.
//    3. Dieser Screen zeigt den erkannten Typ + Felder + CTAs.
//    4. „Uebernehmen" routet auf den passenden Sub-Flow:
//       - rechnung            → `RechnungEditView(.neu…)`
//       - energieausweis      → direkte Verknuepfung + Hinweis
//       - grundsteuerbescheid → direkte Verknuepfung + Hinweis
//       - zaehlerfoto         → Info-Screen (OCR folgt Phase 1.2)
//       - hvAbrechnung        → `HVAnalyseBefundView`
//       - mietvertrag         → `ScanPlatzhalterSheet`
//       - erhoehungsschreiben → `ScanPlatzhalterSheet`
//       - unbekannt           → User-Picker, dann Re-Dispatch
//    5. „Typ aendern" oeffnet denselben Picker.
//
//  Die Klassifikation ist Stub (`ScanKlassifikator.klassifiziere`) —
//  liefert heute immer `.unbekannt`. Damit sieht der User im ersten
//  Schritt bereits den User-Picker, der echte Claude-Call fuegt sich
//  spaeter ohne Call-Site-Aenderung ein.
//

import SwiftUI
import SwiftData

struct UniversellerAnalyseScreen: View {
    let dokument: GespeichertesDokument
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ScopeManager.self) private var scope
    @Query(sort: \Immobilie.erstelltAm) private var immobilien: [Immobilie]

    @State private var ergebnis: ScanKlassifikationsErgebnis?
    @State private var laeuft = true
    @State private var zeigeTypPicker = false
    @State private var subSheet: SubSheet?
    /// Nach einem echten Claude-Call gesetzt, wenn der Request geschlagen
    /// ist — der User sieht einen Banner mit dem Grund und faellt
    /// automatisch auf den User-Picker-Fluss zurueck.
    @State private var klassifikationsFehler: String?

    // Reaktive Spiegel der beiden Entscheidungs-Flags — so reagieren
    // Banner und Diagnose live auf Aenderungen in den Einstellungen.
    @AppStorage(ScanKlassifikator.debugFlagKey)
    private var devModusAktiv: Bool = false
    @AppStorage("anthropic.apiKey")
    private var apiKeyRoh: String = ""
    private var apiKeyDa: Bool {
        !apiKeyRoh.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Welches Folge-Sheet nach „Uebernehmen" gezeigt werden soll.
    /// Nil = keins (Typ verarbeitet ohne zusaetzlichen Screen, z.B.
    /// Stammdaten-Doks werden nur verknuepft).
    private enum SubSheet: Identifiable {
        case rechnung
        case platzhalter(Dokumenttyp)
        case hvHinweis
        case zaehlerfotoHinweis
        case stammdatenHinweis(Dokumenttyp)

        var id: String {
            switch self {
            case .rechnung:                   return "rechnung"
            case .platzhalter(let t):         return "platzhalter-\(t.rawValue)"
            case .hvHinweis:                  return "hv"
            case .zaehlerfotoHinweis:         return "zaehlerfoto"
            case .stammdatenHinweis(let t):   return "stamm-\(t.rawValue)"
            }
        }
    }

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

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if devModusAktiv {
                        devModusBanner
                    }
                    if laeuft {
                        analyseLaeuftBlock
                    } else {
                        if let fehler = klassifikationsFehler {
                            fehlerBanner(fehler)
                        }
                        // Diagnose-Card zeigt live, welchen Pfad der
                        // Klassifikator genommen hat — so siehst Du
                        // ohne Xcode-Console, warum ein bestimmter
                        // Typ (oder eben .unbekannt) rauskam.
                        diagnoseCard
                        typBadge
                        if let erg = ergebnis, !erg.felder.isEmpty {
                            felderCard(erg.felder)
                        }
                        ctaBlock
                    }
                }
                .padding(16)
            }
            .background(DesignTokens.bgAppCompact)
            .sheetTitelHeader("Dokument einwerfen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetToolbar.abbrechen { dismiss() }
                }
            }
        }
        .onAppear {
            print("🟢 UniversellerAnalyseScreen erscheint dokumentID=\(dokument.id)")
            print("🔀 Toggle (reaktiv): \(devModusAktiv)")
            print("🔑 API-Key vorhanden (reaktiv): \(apiKeyDa)")
        }
        .task { await klassifiziere() }
        .sheet(isPresented: $zeigeTypPicker) {
            UniversellerTypPicker { neuerTyp in
                zeigeTypPicker = false
                setzeTyp(neuerTyp)
            }
        }
        .sheet(item: $subSheet) { folge in
            subSheetInhalt(folge)
        }
    }

    // MARK: - Klassifikation

    private func klassifiziere() async {
        let erg = await ScanKlassifikator.klassifiziere(dokument: dokument)
        ergebnis = erg
        // `letzterFehler` wird vom Klassifikator vor jedem Call
        // geleert — nur Fehler dieser Runde kommen an.
        klassifikationsFehler = ScanKlassifikator.letzterFehler
        laeuft = false
    }

    private func setzeTyp(_ neu: Dokumenttyp) {
        if let alt = ergebnis {
            ergebnis = ScanKlassifikationsErgebnis(
                typ: neu,
                konfidenz: alt.konfidenz,
                felder: alt.felder
            )
        } else {
            ergebnis = ScanKlassifikationsErgebnis(
                typ: neu, konfidenz: 0, felder: [:]
            )
        }
    }

    // MARK: - Diagnose-Card

    /// Zeigt den tatsaechlichen Pfad des Klassifikators live in der UI.
    /// Spart den Umweg ueber die Xcode-Konsole: Du siehst sofort, ob
    /// der Dev-Toggle aktiv war, ob der API-Key gefunden wurde und
    /// welche Route gelaufen ist (Stub / Echt / Fehler).
    @ViewBuilder
    private var diagnoseCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            diagZeile(
                label: "Dev-Toggle",
                wert: devModusAktiv ? "AN" : "AUS",
                ok: devModusAktiv
            )
            diagZeile(
                label: "API-Key",
                wert: apiKeyDa ? "vorhanden" : "fehlt",
                ok: apiKeyDa
            )
            diagZeile(
                label: "Pfad",
                wert: pfadBeschreibung,
                ok: {
                    if case .echt = ScanKlassifikator.letzterPfad { return true }
                    return false
                }()
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.bgSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(DesignTokens.separator, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func diagZeile(label: String, wert: String, ok: Bool) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(ok ? DesignTokens.statusOk : DesignTokens.statusWarn)
                .frame(width: 6, height: 6)
            Text(label)
                .appFont(AppFont.Basis.caption())
                .foregroundStyle(DesignTokens.textSecondary)
            Spacer(minLength: 8)
            Text(wert)
                .appFont(AppFont.Basis.monoCaption())
                .foregroundStyle(DesignTokens.text)
                .multilineTextAlignment(.trailing)
        }
    }

    private var pfadBeschreibung: String {
        switch ScanKlassifikator.letzterPfad {
        case .idle:
            return "läuft …"
        case .stub(let grund):
            return "Stub · \(grund)"
        case .echt(let typ, let anzahl):
            return "Claude · \(typ.rawValue) · \(anzahl) Felder"
        case .echtFehler(let b):
            return "Fehler: \(b.prefix(60))"
        }
    }

    // MARK: - Banner

    /// Sichtbar, solange der Debug-Toggle `scan.klassifikation.debug
    /// .aktiv` gesetzt ist. Macht dem User klar, dass das Dokument
    /// ungeschwaerzt an Anthropic geschickt wird — diese Offenheit
    /// ist DSGVO-relevant und steht explizit in CLAUDE.md (Mode B
    /// Opt-in).
    private var devModusBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignTokens.statusError)
            VStack(alignment: .leading, spacing: 2) {
                Text("Dev-Modus · ungeschwärzter Versand")
                    .appFont(AppFont.Basis.bodySemi())
                    .foregroundStyle(DesignTokens.text)
                Text("Das Dokument wird vollständig an Anthropic gesendet. Nicht für Produktiv-Daten.")
                    .appFont(AppFont.Basis.caption())
                    .foregroundStyle(DesignTokens.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.statusErrorSoft)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func fehlerBanner(_ meldung: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignTokens.statusWarn)
            VStack(alignment: .leading, spacing: 2) {
                Text("Automatische Erkennung fehlgeschlagen")
                    .appFont(AppFont.Basis.bodySemi())
                    .foregroundStyle(DesignTokens.text)
                Text(meldung)
                    .appFont(AppFont.Basis.caption())
                    .foregroundStyle(DesignTokens.textSecondary)
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.statusWarnSoft)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Analyse-Animation

    private var analyseLaeuftBlock: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
                .tint(DesignTokens.accent)
            Text("Dokument wird analysiert …")
                .appFont(AppFont.Basis.bodySemi())
                .foregroundStyle(DesignTokens.text)
            Text("Typ-Erkennung läuft. Bei unbekanntem Typ wählen Sie ihn gleich selbst.")
                .appFont(AppFont.Basis.caption())
                .foregroundStyle(DesignTokens.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    // MARK: - Typ-Badge

    @ViewBuilder
    private var typBadge: some View {
        let typ = ergebnis?.typ ?? .unbekannt
        let istUnbekannt = typ == .unbekannt
        HStack(spacing: 12) {
            Image(systemName: istUnbekannt ? "questionmark.circle.fill" : "checkmark.seal.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(istUnbekannt ? DesignTokens.statusWarn : DesignTokens.statusOk)
            VStack(alignment: .leading, spacing: 2) {
                Text(istUnbekannt ? "Typ nicht erkannt" : typ.anzeigeName)
                    .appFont(AppFont.Basis.bodySemi())
                    .foregroundStyle(DesignTokens.text)
                Text(istUnbekannt
                     ? "Bitte unten auswählen"
                     : "Auto-Erkennung · Sie können den Typ ändern")
                    .appFont(AppFont.Basis.caption())
                    .foregroundStyle(DesignTokens.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((istUnbekannt ? DesignTokens.statusWarnSoft : DesignTokens.statusOkSoft))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Felder-Card

    private func felderCard(_ felder: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Erkannte Felder")
                .appFont(AppFont.Basis.kicker())
                .foregroundStyle(DesignTokens.textSecondary)
            VStack(spacing: 0) {
                ForEach(felder.keys.sorted(), id: \.self) { key in
                    HStack(alignment: .firstTextBaseline) {
                        Text(key)
                            .appFont(AppFont.Basis.caption())
                            .foregroundStyle(DesignTokens.textSecondary)
                        Spacer(minLength: 8)
                        Text(felder[key] ?? "—")
                            .appFont(AppFont.Basis.body())
                            .foregroundStyle(DesignTokens.text)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    DividerLine()
                }
            }
            .background(DesignTokens.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    // MARK: - CTA-Block

    @ViewBuilder
    private var ctaBlock: some View {
        let typ = ergebnis?.typ ?? .unbekannt
        VStack(spacing: 10) {
            Button {
                if typ == .unbekannt {
                    zeigeTypPicker = true
                } else {
                    uebernehmen(typ: typ)
                }
            } label: {
                uebernehmenLabel(typ: typ)
            }
            .buttonStyle(.plain)
            Button {
                zeigeTypPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Typ ändern")
                        .appFont(AppFont.Basis.bodySemi())
                }
                .foregroundStyle(DesignTokens.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(DesignTokens.bgSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(DesignTokens.separator, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func uebernehmenLabel(typ: Dokumenttyp) -> some View {
        HStack(spacing: 10) {
            Image(systemName: typ == .unbekannt ? "list.bullet" : "checkmark")
                .font(.system(size: 15, weight: .semibold))
            Text(typ == .unbekannt ? "Typ auswählen" : "Übernehmen")
                .appFont(AppFont.Basis.bodySemi())
        }
        .foregroundStyle(Color.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(DesignTokens.accent)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Uebernahme-Logik

    private func uebernehmen(typ: Dokumenttyp) {
        // Dokumenttyp am Dokument persistieren — so taucht das Dokument
        // in BelegeView bereits unter dem richtigen Icon auf.
        dokument.dokumenttyp = typ
        try? modelContext.save()

        switch typ {
        case .rechnung, .bescheid, .handwerkerbeleg, .winterdienstbeleg:
            subSheet = .rechnung
        case .zaehlerfoto:
            subSheet = .zaehlerfotoHinweis
        case .energieausweis:
            verknuepfeStammdaten()
            subSheet = .stammdatenHinweis(.energieausweis)
        case .grundsteuerbescheid:
            verknuepfeStammdaten()
            subSheet = .stammdatenHinweis(.grundsteuerbescheid)
        case .hvAbrechnung:
            subSheet = .hvHinweis
        case .mietvertrag, .erhoehungsschreiben:
            subSheet = .platzhalter(typ)
        case .unbekannt, .sonstiges:
            // Sollte nicht auftreten — unbekannt fuehrt oben zum Picker.
            zeigeTypPicker = true
        }
    }

    private func verknuepfeStammdaten() {
        guard let immobilie = aktiveImmobilie else { return }
        dokument.immobilie = immobilie
        try? modelContext.save()
    }

    // MARK: - Sub-Sheet-Inhalte

    @ViewBuilder
    private func subSheetInhalt(_ folge: SubSheet) -> some View {
        switch folge {
        case .rechnung:
            if let immobilie = aktiveImmobilie {
                RechnungEditView(modus: .neu(immobilie: immobilie))
            } else {
                ScanPlatzhalterSheet(
                    typ: .rechnung,
                    felder: ergebnis?.felder ?? [:]
                )
            }
        case .platzhalter(let t):
            ScanPlatzhalterSheet(typ: t, felder: ergebnis?.felder ?? [:])
        case .hvHinweis:
            HVEinwurfHinweisSheet(felder: ergebnis?.felder ?? [:])
        case .zaehlerfotoHinweis:
            ZaehlerfotoHinweisSheet()
        case .stammdatenHinweis(let t):
            StammdatenDokumentHinweisSheet(typ: t)
        }
    }
}

// MARK: - Universeller Typ-Picker

fileprivate struct UniversellerTypPicker: View {
    let onAuswahl: (Dokumenttyp) -> Void
    @Environment(\.dismiss) private var dismiss

    /// Auswahl-Reihenfolge: haeufigste Typen zuerst. `.unbekannt` und
    /// `.sonstiges` sind im Picker kein separater Eintrag — der User
    /// soll konkret waehlen.
    private var optionen: [Dokumenttyp] {
        [.rechnung, .zaehlerfoto, .hvAbrechnung, .mietvertrag,
         .erhoehungsschreiben, .energieausweis, .grundsteuerbescheid,
         .handwerkerbeleg, .bescheid, .sonstiges]
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(optionen, id: \.self) { t in
                    Button { onAuswahl(t) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: symbol(fuer: t))
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(DesignTokens.accent)
                                .frame(width: 32)
                            Text(t.anzeigeName)
                                .appFont(AppFont.Basis.bodySemi())
                                .foregroundStyle(DesignTokens.text)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(DesignTokens.textTertiary)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Dokumenttyp wählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetToolbar.abbrechen { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func symbol(fuer t: Dokumenttyp) -> String {
        switch t {
        case .rechnung:            return "doc.text.fill"
        case .bescheid:            return "building.columns.fill"
        case .handwerkerbeleg:     return "wrench.and.screwdriver.fill"
        case .winterdienstbeleg:   return "snowflake"
        case .zaehlerfoto:         return "gauge.medium"
        case .mietvertrag:         return "person.text.rectangle.fill"
        case .energieausweis:     return "doc.badge.gearshape"
        case .grundsteuerbescheid: return "doc.text"
        case .hvAbrechnung:        return "building.2.fill"
        case .erhoehungsschreiben: return "arrow.up.right.circle.fill"
        case .unbekannt:           return "questionmark.circle"
        case .sonstiges:           return "doc"
        }
    }
}

// MARK: - Spezial-Hinweise (Stammdaten + Zaehlerfoto)

/// Bestaetigung nach Ablegen eines Stammdaten-Dokuments (Energie-
/// ausweis, Grundsteuerbescheid). Das Dokument haengt bereits an
/// der Immobilie — hier nur der Sichtbarkeits-Hinweis.
fileprivate struct StammdatenDokumentHinweisSheet: View {
    let typ: Dokumenttyp
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(DesignTokens.statusOk)
                Text("\(typ.anzeigeName) abgelegt")
                    .appFont(AppFont.Basis.bodySemi())
                    .foregroundStyle(DesignTokens.text)
                Text("Das Dokument ist ab sofort in \u{201E}Stammdaten → Dokumente\u{201C} unter dem Objekt sichtbar.")
                    .appFont(AppFont.Basis.caption())
                    .foregroundStyle(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
                Button { dismiss() } label: {
                    Text("Fertig")
                        .appFont(AppFont.Basis.bodySemi())
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(DesignTokens.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignTokens.bgAppCompact)
        }
        .presentationDetents([.medium])
    }
}

/// Minimaler Hinweis-Screen fuer einen HV-Abrechnungs-Einwurf. Das
/// PDF ist abgelegt; der volle HV-Flow (Positions-Extraktion, §35a-
/// Ausweisung, Eigentuemer-Kosten) lebt separat in der bestehenden
/// `HVAnalyseBefundView` unter `UI/Home/`, wird aber aus dem Scan-
/// Einwurf heraus noch nicht angesteuert — die Klassifikation liefert
/// im aktuellen Stub auch keine passenden Rohdaten.
fileprivate struct HVEinwurfHinweisSheet: View {
    let felder: [String: String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "building.2.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(DesignTokens.accent)
                Text("HV-Abrechnung abgelegt")
                    .appFont(AppFont.Basis.bodySemi())
                    .foregroundStyle(DesignTokens.text)
                Text("Die automatische Positions-Extraktion (umlagefähig / Eigentümer / §35a) folgt in einem nächsten Task. Das Dokument ist in \u{201E}Belege\u{201C} archiviert.")
                    .appFont(AppFont.Basis.caption())
                    .foregroundStyle(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
                Button { dismiss() } label: {
                    Text("Fertig")
                        .appFont(AppFont.Basis.bodySemi())
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(DesignTokens.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignTokens.bgAppCompact)
        }
        .presentationDetents([.medium])
    }
}

/// Zaehlerfoto-Hinweis — OCR-Werterkennung + Auto-Zuordnung zu einem
/// Zaehler kommt in Phase 1.2. Bis dahin muss der User selbst in die
/// Zaehler-Sektion und dort manuell erfassen.
fileprivate struct ZaehlerfotoHinweisSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "gauge.medium")
                    .font(.system(size: 48, weight: .regular))
                    .foregroundStyle(DesignTokens.accent)
                Text("Foto abgelegt")
                    .appFont(AppFont.Basis.bodySemi())
                    .foregroundStyle(DesignTokens.text)
                Text("Die automatische Werterkennung folgt in einem nächsten Task. Bitte erfassen Sie den Zählerstand manuell über die Zähler-Sektion.")
                    .appFont(AppFont.Basis.caption())
                    .foregroundStyle(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
                Button { dismiss() } label: {
                    Text("Verstanden")
                        .appFont(AppFont.Basis.bodySemi())
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(DesignTokens.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignTokens.bgAppCompact)
        }
        .presentationDetents([.medium])
    }
}
