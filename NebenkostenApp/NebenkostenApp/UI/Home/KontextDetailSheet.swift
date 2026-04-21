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
//  Scan-Flow (Dokumenten-Intelligenz):
//  Die Card „Neue Daten hinzufuegen / ergaenzen" startet eine
//  `AnalyseSitzung` fuer die getroffene Einheit. Nach jedem
//  Scan laeuft der `DokumentAnalyseService` und pusht den User
//  auf den `AnalyseBefundView`-Screen. Die Sitzung akkumuliert
//  alle Scans — jeder weitere Scan wird in denselben Kontext
//  gemergt, sodass ein Mietvertrag + ein spaeteres Erhoehungs-
//  schreiben als zusammengefuehrtes Bild landen und der alte
//  Wert als „vorher …" ausgewiesen wird.
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
    @State private var scanFehler: String? = nil
    /// Aktive Analyse-Sitzung — mit dem ersten Scan initialisiert,
    /// waechst mit jedem weiteren Scan. Auf nil setzen beendet die
    /// Sitzung (Uebernehmen oder Abbrechen).
    @State private var sitzung: AnalyseSitzung? = nil
    /// Steuert Navigation-Push zum AnalyseBefundView.
    @State private var zeigeAnalyseScreen: Bool = false

    /// Nur-HV-Pfad: wenn Claude das Dokument als HV-Abrechnung
    /// erkennt, laeuft es an der regulaeren Sitzung vorbei und
    /// landet im dedizierten `HVAnalyseBefundView`.
    @State private var hvRohdaten: HVAbrechnungsRohdaten? = nil
    @State private var zeigeHVAnalyse: Bool = false

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
            .navigationDestination(isPresented: $zeigeAnalyseScreen) {
                if let sitzung {
                    AnalyseBefundView(
                        sitzung: sitzung,
                        onWeiterScannen: { oeffneScannerErneut() },
                        onManuellEintragen: { manuellEintragen() },
                        onUebernehmen: { uebernehmeSitzung() },
                        onAbbrechen: { beendeSitzung() }
                    )
                }
            }
            .navigationDestination(isPresented: $zeigeHVAnalyse) {
                if let rohdaten = hvRohdaten {
                    HVAnalyseBefundView(
                        rohdaten: rohdaten,
                        kostenartenDerImmobilie: (immobilie.kostenarten ?? [])
                            .map { $0.bezeichnung },
                        onUebernehmen: { uebernehmeHVAbrechnung(rohdaten) },
                        onAbbrechen: { beendeHVFlow() }
                    )
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

    private func oeffneScannerErneut() {
        // User steht auf AnalyseBefundView, will weiter scannen.
        // Nav zurueck, dann Scanner oeffnen. `sitzung` bleibt am
        // Leben, damit der naechste Scan in denselben Kontext
        // gemergt wird.
        zeigeAnalyseScreen = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            zeigeScanner = true
        }
    }

    private func manuellEintragen() {
        // User will fehlende Felder selbst eintragen → Sitzung
        // verwerfen (kein DB-Schreiben), Analyse-Screen schliessen;
        // der User bleibt auf dem Detail-Sheet und tippt die
        // zu editierenden Zeilen direkt an (z.B. VZ).
        beendeSitzung()
    }

    private func beendeSitzung() {
        zeigeAnalyseScreen = false
        sitzung = nil
    }

    /// Startet die Analyse fuer einen frischen Scan-Stapel.
    /// Initialisiert die `AnalyseSitzung` beim allerersten Scan,
    /// anschliessend wird in die bestehende Sitzung gemergt.
    ///
    /// Special-Case: erkennt Claude das Dokument als HV-Abrechnung,
    /// laeuft es an der regulaeren Sitzung vorbei und wird im
    /// `HVAnalyseBefundView` praesentiert. Die Mietvertrags-
    /// Sitzung interessiert sich nicht fuer HV-Positionen.
    private func starteAnalyse(bilder: [UIImage]) {
        guard !bilder.isEmpty else { return }
        guard let zielEinheit = resolveZielEinheit() else {
            scanFehler = "Keine Wohneinheit zum Aktualisieren vorhanden."
            return
        }

        let aktuelle = sitzung ?? AnalyseSitzung(einheit: zielEinheit)
        sitzung = aktuelle

        zeigeAnalyse = true
        Task {
            do {
                let befund = try await DokumentAnalyseService.analysiere(
                    bilder: bilder,
                    sitzung: aktuelle,
                    einheit: zielEinheit
                )
                zeigeAnalyse = false

                // Zweig 1 — HV-Abrechnung: eigener Screen.
                if befund.erkannterTyp == .hvAbrechnung,
                   let hv = befund.hvDaten {
                    hvRohdaten = hv
                    // Laufende Sitzung (falls aus vorherigem Mietvertrags-
                    // Scan noch offen) NICHT zerstoeren — der User kann
                    // den HV-Flow abbrechen und landet dann wieder bei
                    // seiner Mietvertrags-Sitzung. Wenn keine Sitzung
                    // lief, wird sie hier auch nicht erzwungen.
                    if !zeigeHVAnalyse {
                        zeigeHVAnalyse = true
                    }
                    return
                }

                // Zweig 2 — regulaere Mietvertrags-/Nachtrags-Analyse.
                aktuelle.integriere(befund)
                // Nach dem ersten Scan pushen, bei Folge-Scans ist
                // der Screen bereits sichtbar und aktualisiert
                // sich ueber @Bindable automatisch.
                if !zeigeAnalyseScreen {
                    zeigeAnalyseScreen = true
                }
            } catch {
                zeigeAnalyse = false
                scanFehler = error.localizedDescription
            }
        }
    }

    // MARK: - HV-Flow

    /// Wandelt die `HVAbrechnungsRohdaten` in persistente Entities:
    ///
    ///   1. 1× `HVAbrechnung` (Container inkl. §35a-Summen,
    ///      Abrechnungsspitze, Vorauszahlungen).
    ///   2. Pro umlagefaehige Position je eine `HVPosition`
    ///      (Rohbeleg im Container) PLUS eine `Rechnung`-Entity
    ///      an der passenden BetrKV-Kostenart, damit der
    ///      Abrechnungs-Service sie ganz normal umlegen kann.
    ///   3. Pro nicht umlagefaehiger Position eine
    ///      `HVEigentuemerKosten`-Entity — bleibt beim Eigentuemer.
    ///
    /// Fehlgeschlagene Speicherung → Rollback + Fehler-Alert.
    private func uebernehmeHVAbrechnung(_ rohdaten: HVAbrechnungsRohdaten) {
        let container = HVAbrechnung()
        container.immobilie = immobilie
        container.hausverwaltungName = rohdaten.hausverwaltungName
        container.hausverwaltungAdresse = rohdaten.hausverwaltungAdresse
        container.wegName = rohdaten.wegName
        container.gebaeudeAdresse = rohdaten.gebaeudeAdresse
        container.meaAnteil = rohdaten.meaAnteil
        container.meaGesamt = max(rohdaten.meaGesamt, 1)
        if let v = rohdaten.abrechnungszeitraumVon {
            container.abrechnungszeitraumVon = v
        }
        if let b = rohdaten.abrechnungszeitraumBis {
            container.abrechnungszeitraumBis = b
        }
        container.abrechnungsspitzeEuro = rohdaten.abrechnungsspitzeEuro
        container.vorauszahlungenEuro = rohdaten.vorauszahlungenEuro
        container.erhaltungsruecklageAnteilEuro = rohdaten.erhaltungsruecklageAnteilEuro
        container.paragraph35aHandwerkerEuro = rohdaten.paragraph35aHandwerkerEuro
        container.paragraph35aHaushaltsnahEuro = rohdaten.paragraph35aHaushaltsnahEuro
        modelContext.insert(container)

        for positionRoh in rohdaten.umlagefaehigePositionen {
            // HVPosition als Rohbeleg im Container
            let position = HVPosition()
            position.bezeichnung = positionRoh.bezeichnung
            position.kontierung = positionRoh.kontierung
            position.gesamtkostenGebaeude = positionRoh.gesamtkostenGebaeude
            position.anteilEuro = positionRoh.anteilEuro
            position.betrkvKostenart = positionRoh.betrkvKostenart
            position.hvAbrechnung = container
            modelContext.insert(position)

            // Plus: eine echte Rechnung an die gemappte Kostenart.
            // Wenn kein Katalog-Match: Rechnung ohne Kostenart
            // — der User kann das spaeter zuordnen.
            let rechnung = Rechnung()
            rechnung.lieferant = positionRoh.bezeichnung.isEmpty
                ? rohdaten.hausverwaltungName
                : positionRoh.bezeichnung
            rechnung.betragBruttoEuro = positionRoh.anteilEuro
            if let bis = rohdaten.abrechnungszeitraumBis {
                rechnung.rechnungsdatum = bis
            }
            if let von = rohdaten.abrechnungszeitraumVon {
                rechnung.leistungVon = von
            }
            if let bis = rohdaten.abrechnungszeitraumBis {
                rechnung.leistungBis = bis
            }
            rechnung.immobilie = immobilie
            rechnung.kostenart = passendeKostenart(fuer: positionRoh.betrkvKostenart)
            rechnung.validierungsStatus = .validiert
            rechnung.extraktionsNotizen = "Aus HV-Abrechnung \(rohdaten.hausverwaltungName) "
                + "(\(rohdaten.abrechnungszeitraumVon.map(Self.kurzDatum) ?? "–") – "
                + "\(rohdaten.abrechnungszeitraumBis.map(Self.kurzDatum) ?? "–"))"
            modelContext.insert(rechnung)
        }

        for kostenRoh in rohdaten.eigentuemerKosten {
            let ek = HVEigentuemerKosten()
            ek.bezeichnung = kostenRoh.bezeichnung
            ek.kontierung = kostenRoh.kontierung
            ek.anteilEuro = kostenRoh.anteilEuro
            ek.hvAbrechnung = container
            modelContext.insert(ek)
        }

        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("[KontextDetail/HV] save fehlgeschlagen:", error.localizedDescription)
            #endif
            modelContext.rollback()
            scanFehler = "HV-Abrechnung konnte nicht gespeichert werden: \(error.localizedDescription)"
            return
        }

        beendeHVFlow()
    }

    /// Sucht im Kostenart-Katalog der Immobilie die beste Zuordnung
    /// fuer Claudes Mapping-Hinweis. Bewusst tolerant: case-insensitive
    /// Substring-Match in beide Richtungen, plus ein paar Aliase
    /// (Wasser → Be- und Entwaesserung, Hauswart → Reinigung etc.).
    private func passendeKostenart(fuer hinweis: String) -> Kostenart? {
        let katalog = (immobilie.kostenarten ?? []).filter { $0.aktiv }
        guard !katalog.isEmpty else { return nil }
        let h = hinweis.lowercased().trimmingCharacters(in: .whitespaces)
        guard !h.isEmpty else { return nil }

        // 1. Direktes Contains (beide Richtungen).
        if let direkt = katalog.first(where: {
            let name = $0.bezeichnung.lowercased()
            return name.contains(h) || h.contains(name.prefix(5))
        }) {
            return direkt
        }

        // 2. Alias-Tabelle — oberflaechliches Synonym-Matching.
        let aliase: [(hint: String, zielSubstring: String)] = [
            ("wasser",     "entwässer"),
            ("wasser",     "wasser"),
            ("müll",       "müll"),
            ("muell",      "müll"),
            ("strom",      "allgemeinstrom"),
            ("hauswart",   "reinig"),
            ("hausmeister","reinig"),
            ("garten",     "garten"),
            ("grundsteu",  "grundsteu"),
            ("versicher",  "versicher"),
            ("heiz",       "heizung")
        ]
        for (hint, ziel) in aliase where h.contains(hint) {
            if let treffer = katalog.first(where: {
                $0.bezeichnung.lowercased().contains(ziel)
            }) {
                return treffer
            }
        }

        // 3. Kein Match — die Fallback-„Sonstige"-Kostenart nehmen,
        // wenn es sie gibt.
        if let sonstige = katalog.first(where: {
            $0.bezeichnung.lowercased().contains("sonstige")
        }) {
            return sonstige
        }

        // 4. Ansonsten nil — der User muss manuell zuordnen.
        return nil
    }

    private static func kurzDatum(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "dd.MM.yyyy"
        return f.string(from: d)
    }

    private func beendeHVFlow() {
        zeigeHVAnalyse = false
        hvRohdaten = nil
    }

    /// Die Einheit, auf die die Sitzung schreibt. Im Einheit-Scope
    /// steht sie fest, im Objekt-Scope nehmen wir die erste Einheit
    /// nach Rang — das M1-Stub liefert ohnehin nur eine Einheit pro
    /// Mietvertrag, mehrere Einheiten auswaehlbar zu machen lohnt
    /// sich erst mit M2 (echter Claude-Call + Einheit-Match).
    private func resolveZielEinheit() -> Wohneinheit? {
        let alle = (immobilie.wohneinheiten ?? []).sorted {
            ScopeFilter.einheitRang($0.bezeichnung) < ScopeFilter.einheitRang($1.bezeichnung)
        }
        guard !alle.isEmpty else { return nil }
        switch scope {
        case .einheit(let id):
            return alle.first { $0.bezeichnung == id } ?? alle[0]
        case .objekt:
            return alle[0]
        }
    }

    /// „So uebernehmen" aus dem AnalyseBefundView: schreibt den
    /// in der Sitzung gemergten Stand in die Ziel-Einheit.
    private func uebernehmeSitzung() {
        guard let sitzung,
              let einheit = (immobilie.wohneinheiten ?? []).first(where: { $0.id == sitzung.einheitID })
        else {
            beendeSitzung()
            return
        }

        // Wir nutzen die letzte Roh-Extraktion als Grundlage —
        // die enthaelt die in der Sitzung gemergten Werte (VZ-
        // Update wird dort via `patch` gesetzt).
        if let roh = sitzung.letzterBefund?.rohExtraktion {
            schreibe(extraktion: roh, auf: einheit)
        }

        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("[KontextDetail] save fehlgeschlagen:", error.localizedDescription)
            #endif
            modelContext.rollback()
            scanFehler = "Speichern fehlgeschlagen: \(error.localizedDescription)"
            return
        }

        beendeSitzung()
    }

    /// Schreibt eine `MietvertragsExtraktion` in die Ziel-Einheit
    /// bzw. das aktive Mietverhaeltnis. Legt ein neues Miet-
    /// verhaeltnis an, falls noch keines existiert.
    private func schreibe(extraktion e: MietvertragsExtraktion, auf einheit: Wohneinheit) {
        if let bez = e.einheitBezeichnung.wert, !bez.isEmpty {
            einheit.bezeichnung = bez
        }
        if let flaeche = e.einheitFlaecheM2.wert, flaeche > 0 {
            einheit.flaecheM2 = flaeche
        }

        // Objekt-Felder — nur Bestand auffuellen, nie ueberschreiben.
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
