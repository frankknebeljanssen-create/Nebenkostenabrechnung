//
//  KontextDetailSheet.swift
//  NebenkostenApp — UI/Home
//
//  Detail-Sheet, das beim Tap auf eine Home-Card (Objekt bzw.
//  Wohneinheit) erscheint. Zeigt scope-abhaengig entweder die
//  Objekt-Uebersicht (Adresse + alle Einheiten mit Mieter + VZ)
//  oder das Detail einer einzelnen Wohneinheit (Mieter-Name,
//  Anschrift, Vorauszahlung) — genau der Einheit, die der User
//  antippt, ohne Daten der anderen Mieter.
//
//  Neu: Scan-Card "Neue Daten hinzufuegen / ergaenzen" ganz oben.
//  Fuehrt den User durch Scanner → Analyse → Uebernahme-Vorschau,
//  aktualisiert das Mietverhaeltnis der getroffenen Einheit bzw.
//  (im Objekt-Scope) die erste passende Einheit. Der M1-Stub
//  nutzt `MietvertragsExtraktionService.extrahiere`; M2 ersetzt
//  den Stub durch den echten Claude-Call.
//
//  Architektur-Regel (systemweit): Einstellungen erreicht man
//  AUSSCHLIESSLICH ueber das Zahnrad in `AppShellChrome`. Taps
//  auf Cards oeffnen stets Detail-Views ueber dem aktuellen
//  Kontext, NICHT das Einstellungen-Sheet.
//

import SwiftUI
import SwiftData
import UIKit

struct KontextDetailSheet: View {
    let immobilie: Immobilie
    let scope: AppScope

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppShellRouter.self) private var router

    // MARK: - Scan-State

    @State private var zeigeScanner: Bool = false
    @State private var zeigeAnalyse: Bool = false
    @State private var uebernahme: UebernahmeKontext? = nil
    @State private var scanFehler: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    scanAktionsCard

                    switch scope {
                    case .objekt:
                        ObjektDetailInhalt(
                            immobilie: immobilie,
                            onVzFuer: { id in
                                router.oeffneVorauszahlungSheet(einheitID: id)
                            }
                        )
                    case .einheit(let id):
                        if let we = (immobilie.wohneinheiten ?? []).first(where: { $0.bezeichnung == id }) {
                            EinheitDetailInhalt(
                                immobilie: immobilie,
                                einheit: we,
                                onVzBearbeiten: {
                                    router.oeffneVorauszahlungSheet(einheitID: id)
                                }
                            )
                        } else {
                            Text("Wohneinheit \(id) nicht gefunden.")
                                .appFont(AppFont.bodyMedium())
                                .foregroundStyle(DesignTokens.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(DesignTokens.bgApp)
            .navigationTitle(navTitel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetToolbar.abbrechen(titel: "Fertig") { dismiss() }
                }
            }
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
        .sheet(item: $uebernahme) { kontext in
            MietvertragUebernahmeSheet(
                kontext: kontext,
                onUebernehmen: { ziel in uebernehme(extraktion: kontext.extraktion, auf: ziel) },
                onAbbrechen: { uebernahme = nil }
            )
        }
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

    private var navTitel: String {
        switch scope {
        case .objekt:
            return "Objekt"
        case .einheit(let id):
            return "\(id)"
        }
    }

    // MARK: - Scan-Aktionscard

    @ViewBuilder
    private var scanAktionsCard: some View {
        Button(action: starteScan) {
            Card(tiefe: .erhoben, balkenFarbe: DesignTokens.accent) {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(DesignTokens.accent)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Neue Daten hinzufügen / ergänzen")
                            .appFont(AppFont.bodySemi())
                            .foregroundStyle(DesignTokens.accent)
                        Text("Mietvertrag, Rechnung oder Bescheid scannen — passende Felder werden vorgeschlagen.")
                            .appFont(AppFont.caption())
                            .foregroundStyle(DesignTokens.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.textTertiary)
                }
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .disabled(!ScanService.istKameraVerfuegbar)
        .opacity(ScanService.istKameraVerfuegbar ? 1 : 0.5)
    }

    @ViewBuilder
    private var analyseOverlay: some View {
        if zeigeAnalyse {
            ZStack {
                Color.black.opacity(0.35).ignoresSafeArea()
                VStack(spacing: 14) {
                    ProgressView()
                        .scaleEffect(1.3)
                        .tint(DesignTokens.accent)
                    Text("Dokument wird analysiert …")
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

    // MARK: - Flow

    private func starteScan() {
        scanFehler = nil
        zeigeScanner = true
    }

    private func starteAnalyse(bilder: [UIImage]) {
        guard !bilder.isEmpty else { return }
        zeigeAnalyse = true
        Task {
            do {
                let ergebnis = try await MietvertragsExtraktionService.extrahiere(ausBildern: bilder)
                zeigeAnalyse = false
                praesentiereUebernahme(ergebnis)
            } catch {
                zeigeAnalyse = false
                scanFehler = error.localizedDescription
            }
        }
    }

    /// Nach erfolgreicher Extraktion: Ziel-Einheit resolven und
    /// Uebernahme-Sheet oeffnen.
    private func praesentiereUebernahme(_ e: MietvertragsExtraktion) {
        let alle = (immobilie.wohneinheiten ?? []).sorted {
            ScopeFilter.einheitRang($0.bezeichnung) < ScopeFilter.einheitRang($1.bezeichnung)
        }
        guard !alle.isEmpty else {
            scanFehler = "Keine Wohneinheit zum Aktualisieren vorhanden."
            return
        }
        let vorgewaehlt: Wohneinheit = {
            switch scope {
            case .einheit(let id):
                return alle.first { $0.bezeichnung == id } ?? alle[0]
            case .objekt:
                if let kandidat = e.einheitBezeichnung.wert,
                   let treffer = alle.first(where: { $0.bezeichnung.caseInsensitiveCompare(kandidat) == .orderedSame }) {
                    return treffer
                }
                return alle[0]
            }
        }()
        uebernahme = UebernahmeKontext(
            extraktion: e,
            alleEinheiten: alle,
            zielEinheit: vorgewaehlt,
            scope: scope
        )
    }

    /// Schreibt die Extraktion in die Ziel-Einheit bzw. das aktive
    /// Mietverhaeltnis. Legt ein neues Mietverhaeltnis an, falls
    /// noch keines existiert (Leerstand → Vermietet).
    private func uebernehme(extraktion e: MietvertragsExtraktion, auf einheit: Wohneinheit) {
        // Einheit-Felder
        if let bez = e.einheitBezeichnung.wert, !bez.isEmpty {
            einheit.bezeichnung = bez
        }
        if let flaeche = e.einheitFlaecheM2.wert, flaeche > 0 {
            einheit.flaecheM2 = flaeche
        }

        // Objekt-Felder — Gesamtflaeche nur wenn aktuell 0 (Bestand nicht
        // ueberschreiben, waere zu ueberraschend).
        if let adr = e.adresse.wert, immobilie.adresse.isEmpty {
            immobilie.adresse = adr
        }
        let mergedOrt = [e.plz.wert, e.stadt.wert]
            .compactMap { $0 }
            .joined(separator: " ")
        if !mergedOrt.isEmpty, immobilie.ort.isEmpty {
            immobilie.ort = mergedOrt
        }
        if let gesamt = e.gesamtflaecheM2.wert, immobilie.gesamtflaecheM2 == 0 {
            immobilie.gesamtflaecheM2 = gesamt
        }

        // Mietverhaeltnis resolven (oder anlegen)
        let aktiv = (einheit.mietverhaeltnisse ?? []).first { $0.auszugAm == nil }
        let mv = aktiv ?? {
            let neu = Mietverhaeltnis()
            neu.wohneinheit = einheit
            modelContext.insert(neu)
            return neu
        }()

        if let name = e.mieterName.wert, !name.isEmpty {
            mv.mieterName = name
        }
        if let anschrift = e.mieterAnschrift.wert, !anschrift.isEmpty {
            mv.mieterAnschrift = anschrift
        }
        if let einzug = e.einzugAm.wert {
            mv.einzugAm = einzug
        }
        if let vz = e.vorauszahlungMonatEuro.wert, vz > 0 {
            mv.vorauszahlungMonatEuro = vz
            mv.vorauszahlungErfasst = true
            if mv.vorauszahlungGueltigAb == nil {
                mv.vorauszahlungGueltigAb = mv.einzugAm
            }
        }

        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("[KontextDetail] save fehlgeschlagen:", error.localizedDescription)
            #endif
            modelContext.rollback()
            scanFehler = "Speichern fehlgeschlagen: \(error.localizedDescription)"
        }

        uebernahme = nil
    }
}

// MARK: - Uebernahme-Kontext

struct UebernahmeKontext: Identifiable {
    let id: UUID = UUID()
    let extraktion: MietvertragsExtraktion
    let alleEinheiten: [Wohneinheit]
    var zielEinheit: Wohneinheit
    let scope: AppScope
}

// MARK: - Uebernahme-Vorschau-Sheet

private struct MietvertragUebernahmeSheet: View {
    @State var kontext: UebernahmeKontext
    let onUebernehmen: (Wohneinheit) -> Void
    let onAbbrechen: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if kontext.alleEinheiten.count > 1 {
                        zielEinheitCard
                    }
                    deltaCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(DesignTokens.bgApp)
            .navigationTitle("Neue Daten übernehmen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetToolbar.abbrechen {
                        onAbbrechen()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    SheetToolbar.primaer(titel: "Übernehmen") {
                        onUebernehmen(kontext.zielEinheit)
                        dismiss()
                    }
                }
            }
        }
        .tint(DesignTokens.accent)
    }

    @ViewBuilder
    private var zielEinheitCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("ZIEL-EINHEIT")
                    .appFont(AppFont.Dashboard.kartenKicker())
                    .foregroundStyle(DesignTokens.textTertiary)
                Picker("Einheit", selection: $kontext.zielEinheit) {
                    ForEach(kontext.alleEinheiten) { e in
                        Text(e.bezeichnung).tag(e)
                    }
                }
                .pickerStyle(.menu)
                .tint(DesignTokens.accent)
            }
        }
    }

    @ViewBuilder
    private var deltaCard: some View {
        Card(tiefe: .flach, balkenFarbe: ScopeFarbe.farbe(fuer: kontext.zielEinheit)) {
            VStack(alignment: .leading, spacing: 10) {
                Text("ERKANNTE ÄNDERUNGEN")
                    .appFont(AppFont.Dashboard.kartenKicker())
                    .foregroundStyle(DesignTokens.textTertiary)

                let zeilen = deltaZeilen
                if zeilen.isEmpty {
                    Text("Der Scan enthält keine neuen Werte, die hier Platz finden.")
                        .appFont(AppFont.bodyMedium())
                        .foregroundStyle(DesignTokens.textSecondary)
                } else {
                    ForEach(zeilen.indices, id: \.self) { idx in
                        let z = zeilen[idx]
                        UebernahmeZeile(
                            label: z.label,
                            alt: z.alt,
                            neu: z.neu,
                            konfidenz: z.konfidenz
                        )
                        if idx < zeilen.count - 1 {
                            DividerLine()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Delta-Berechnung

    private struct DeltaZeile {
        let label: String
        let alt: String
        let neu: String
        let konfidenz: Double
    }

    private var deltaZeilen: [DeltaZeile] {
        let e = kontext.extraktion
        let einheit = kontext.zielEinheit
        let mv = (einheit.mietverhaeltnisse ?? []).first { $0.auszugAm == nil }

        var out: [DeltaZeile] = []

        if let wert = e.mieterName.wert, !wert.isEmpty {
            out.append(.init(
                label: "Mieter",
                alt: mv?.mieterName.isEmpty == false ? mv!.mieterName : "—",
                neu: wert,
                konfidenz: e.mieterName.konfidenz
            ))
        }
        if let wert = e.mieterAnschrift.wert, !wert.isEmpty {
            out.append(.init(
                label: "Anschrift",
                alt: mv?.mieterAnschrift.isEmpty == false ? mv!.mieterAnschrift : "—",
                neu: wert,
                konfidenz: e.mieterAnschrift.konfidenz
            ))
        }
        if let wert = e.einzugAm.wert {
            out.append(.init(
                label: "Einzug",
                alt: mv.map { Self.datum($0.einzugAm) } ?? "—",
                neu: Self.datum(wert),
                konfidenz: e.einzugAm.konfidenz
            ))
        }
        if let wert = e.vorauszahlungMonatEuro.wert, wert > 0 {
            out.append(.init(
                label: "Vorauszahlung",
                alt: (mv?.vorauszahlungErfasst == true) ? Formatting.euro(mv!.vorauszahlungMonatEuro) : "—",
                neu: Formatting.euro(wert),
                konfidenz: e.vorauszahlungMonatEuro.konfidenz
            ))
        }
        if let wert = e.einheitFlaecheM2.wert, wert > 0, wert != einheit.flaecheM2 {
            out.append(.init(
                label: "Fläche",
                alt: einheit.flaecheM2 > 0 ? Formatting.m2(einheit.flaecheM2) : "—",
                neu: Formatting.m2(wert),
                konfidenz: e.einheitFlaecheM2.konfidenz
            ))
        }
        return out
    }

    private static func datum(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "dd.MM.yyyy"
        return f.string(from: d)
    }
}

private struct UebernahmeZeile: View {
    let label: String
    let alt: String
    let neu: String
    let konfidenz: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(label)
                    .appFont(AppFont.caption())
                    .foregroundStyle(DesignTokens.textSecondary)
                Spacer()
                Circle()
                    .fill(konfidenzFarbe)
                    .frame(width: 8, height: 8)
            }
            HStack(alignment: .top, spacing: 10) {
                Text(alt)
                    .appFont(AppFont.bodyMedium())
                    .foregroundStyle(DesignTokens.textTertiary)
                    .strikethrough(alt != "—", color: DesignTokens.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.textTertiary)
                Text(neu)
                    .appFont(AppFont.bodySemi())
                    .foregroundStyle(DesignTokens.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var konfidenzFarbe: Color {
        if konfidenz >= 0.8 { return DesignTokens.statusOk }
        if konfidenz >= 0.5 { return DesignTokens.statusWarn }
        return DesignTokens.statusError
    }
}

// MARK: - Objekt-Detail

private struct ObjektDetailInhalt: View {
    let immobilie: Immobilie
    let onVzFuer: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Card(tiefe: .erhoben, balkenFarbe: DesignTokens.unitObjekt) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("OBJEKT")
                        .appFont(AppFont.Dashboard.kartenKicker())
                        .foregroundStyle(DesignTokens.textTertiary)
                    Text(immobilie.adresse.isEmpty ? "Ohne Adresse" : immobilie.adresse)
                        .appFont(AppFont.bodySemi())
                        .foregroundStyle(DesignTokens.text)
                    if !immobilie.ort.isEmpty {
                        Text(immobilie.ort)
                            .appFont(AppFont.caption())
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                    if immobilie.gesamtflaecheM2 > 0 {
                        Text(Formatting.m2(immobilie.gesamtflaecheM2))
                            .appFont(AppFont.monoCaption())
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                }
            }

            let sortiert = (immobilie.wohneinheiten ?? []).sorted {
                ScopeFilter.einheitRang($0.bezeichnung) < ScopeFilter.einheitRang($1.bezeichnung)
            }

            if sortiert.isEmpty {
                Card {
                    Text("Noch keine Einheiten erfasst.")
                        .appFont(AppFont.bodyMedium())
                        .foregroundStyle(DesignTokens.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ForEach(sortiert) { einheit in
                    MieterCard(
                        einheit: einheit,
                        onVzBearbeiten: { onVzFuer(einheit.bezeichnung) }
                    )
                }
            }
        }
    }
}

// MARK: - Einheit-Detail

private struct EinheitDetailInhalt: View {
    let immobilie: Immobilie
    let einheit: Wohneinheit
    let onVzBearbeiten: () -> Void

    private var aktivesMv: Mietverhaeltnis? {
        (einheit.mietverhaeltnisse ?? []).first { $0.auszugAm == nil }
    }

    private var scopeFarbe: Color { ScopeFarbe.farbe(fuer: einheit) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Einheit-Kopfzeile
            Card(tiefe: .erhoben, balkenFarbe: scopeFarbe) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("WOHNEINHEIT")
                        .appFont(AppFont.Dashboard.kartenKicker())
                        .foregroundStyle(DesignTokens.textTertiary)
                    Text(einheit.bezeichnung)
                        .appFont(AppFont.bodySemi())
                        .foregroundStyle(DesignTokens.text)
                    HStack(spacing: 10) {
                        if einheit.flaecheM2 > 0 {
                            Text(Formatting.m2(einheit.flaecheM2))
                                .appFont(AppFont.monoCaption())
                                .foregroundStyle(DesignTokens.textSecondary)
                        }
                        Text(einheit.nutzungsart.rawValue.capitalized)
                            .appFont(AppFont.caption())
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                    if !immobilie.adresse.isEmpty {
                        Text(immobilie.adresse + (immobilie.ort.isEmpty ? "" : ", \(immobilie.ort)"))
                            .appFont(AppFont.caption())
                            .foregroundStyle(DesignTokens.textTertiary)
                            .lineLimit(2)
                    }
                }
            }

            MieterCard(einheit: einheit, onVzBearbeiten: onVzBearbeiten)
        }
    }
}

// MARK: - Mieter-Card (wiederverwendet in Objekt- und Einheit-Detail)

private struct MieterCard: View {
    let einheit: Wohneinheit
    let onVzBearbeiten: () -> Void

    private var aktivesMv: Mietverhaeltnis? {
        (einheit.mietverhaeltnisse ?? []).first { $0.auszugAm == nil }
    }

    private var scopeFarbe: Color { ScopeFarbe.farbe(fuer: einheit) }

    var body: some View {
        Card(tiefe: .flach, balkenFarbe: scopeFarbe) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(einheit.bezeichnung)
                        .appFont(AppFont.bodySemi())
                        .foregroundStyle(DesignTokens.text)
                    Spacer()
                    if einheit.flaecheM2 > 0 {
                        Text(Formatting.m2(einheit.flaecheM2))
                            .appFont(AppFont.monoCaption())
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                }

                if let mv = aktivesMv {
                    feldZeile(label: "Mieter", wert: mv.mieterName.isEmpty ? "—" : mv.mieterName)
                    if !mv.mieterAnschrift.isEmpty {
                        feldZeile(label: "Anschrift", wert: mv.mieterAnschrift, mehrzeilig: true)
                    }
                    if !mv.mieterEmail.isEmpty {
                        feldZeile(label: "E-Mail", wert: mv.mieterEmail)
                    }
                    DividerLine()
                    Button(action: onVzBearbeiten) {
                        HStack(alignment: .center, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Vorauszahlung / Monat")
                                    .appFont(AppFont.caption())
                                    .foregroundStyle(DesignTokens.textSecondary)
                                if mv.vorauszahlungErfasst {
                                    Text(Formatting.euro(mv.vorauszahlungMonatEuro))
                                        .appFont(AppFont.monoBetrag17())
                                        .foregroundStyle(DesignTokens.text)
                                } else {
                                    Text("Noch nicht erfasst")
                                        .appFont(AppFont.bodyMedium())
                                        .foregroundStyle(DesignTokens.textTertiary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(DesignTokens.textTertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Leerstand · kein aktives Mietverhältnis")
                        .appFont(AppFont.bodyMedium())
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }
        }
    }

    @ViewBuilder
    private func feldZeile(label: String, wert: String, mehrzeilig: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .appFont(AppFont.caption())
                .foregroundStyle(DesignTokens.textSecondary)
                .frame(width: 92, alignment: .leading)
            Text(wert)
                .appFont(AppFont.bodyMedium())
                .foregroundStyle(DesignTokens.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .lineLimit(mehrzeilig ? nil : 1)
        }
    }
}
