//
//  KontextHeader.swift
//  NebenkostenApp — UI/Chrome
//
//  Permanenter Kontext-Header fuer alle Haupt-Tabs. Drei Zeilen,
//  horizontal zentriert:
//    1. "Objekt: <Adresse>" (+ Chevron)
//    2. "Abrechnungszeitraum: <Zeitraum>" (+ Chevron)
//    3. Wohneinheit-Pills ("Gesamt" + eine Pill pro Einheit),
//       zentriert wenn alle reinpassen, sonst horizontal scrollbar.
//
//  Visuell als klar abgegrenzter Block: Hintergrund `bgAppCompact`
//  (eine Stufe dunkler als bgApp). Der Farbhintergrund extrahiert
//  sich via `.ignoresSafeArea(.container, edges: .top)` nach oben
//  in die Status-Bar / Dynamic-Island-Region — der Header liest
//  sich wie ein zusammenhaengender Block von oben bis zur
//  Trennlinie unten.
//
//  Der Header liest alle drei Achsen aus dem ScopeManager. Beim
//  Objekt-Wechsel setzt der ScopeManager den Scope automatisch auf
//  .objekt zurueck (siehe ScopeManager.aktuelleImmobilieID.didSet).
//

import SwiftUI
import SwiftData

struct KontextHeader: View {
    @Environment(ScopeManager.self) private var scope
    @Environment(AppShellRouter.self) private var router
    @Query(sort: \Immobilie.erstelltAm) private var immobilien: [Immobilie]

    @State private var zeigeObjektPicker = false
    @State private var zeigePeriodenPicker = false

    var body: some View {
        VStack(spacing: 8) {
            objektZeile
            periodenZeile
            if let immo = aktuelleImmobilie {
                WohneinheitPillReihe(immobilie: immo)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background {
            // Gemeinsame Braun-Stufe fuer Header + Footer
            // (`DesignTokens.bgHeaderFooter` = #E4DFD3). Eine Stufe
            // dunkler als bgAppCompact — die beiden Chrome-Raender
            // oben + unten gehoeren visuell zusammen und heben sich
            // deutlich vom Content ab.
            DesignTokens.bgHeaderFooter
                .ignoresSafeArea(.container, edges: .top)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignTokens.separator)
                .frame(height: 0.5)
        }
        .overlay(alignment: .bottomTrailing) {
            // „?" + Zahnrad immer unten rechts im Header sichtbar,
            // unabhaengig vom aktiven Tab. Die Icons sitzen ueber
            // der Pill-Reihe auf dem rechten Spacer-Bereich — die
            // aktive Pill ist zentriert und intrinsisch breit, die
            // Icons liegen daneben im leeren Bereich.
            HStack(spacing: 14) {
                Button { router.zeigeInspektor = true } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.title3)
                        .foregroundStyle(DesignTokens.textSecondary)
                }
                .accessibilityLabel("Was fehlt noch?")
                Button { router.zeigeEinstellungen = true } label: {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundStyle(DesignTokens.textSecondary)
                }
                .accessibilityLabel("Einstellungen")
            }
            .padding(.trailing, 20)
            .padding(.bottom, 10)
        }
        .sheet(isPresented: $zeigeObjektPicker) {
            ObjektPickerSheet()
        }
        .sheet(isPresented: $zeigePeriodenPicker) {
            if let immo = aktuelleImmobilie {
                PeriodenPickerSheet(immobilie: immo)
            }
        }
        .task { synchronisiere() }
        .onChange(of: immobilien.map(\.id)) { _, _ in
            synchronisiere()
        }
        .onChange(of: scope.aktuelleImmobilieID) { _, _ in
            synchronisiere()
        }
    }

    // MARK: - Zeilen (zentriert)

    private var objektZeile: some View {
        Button { zeigeObjektPicker = true } label: {
            HStack(spacing: 6) {
                // Label + Wert gleiche Groesse + gleiches Gewicht
                // (Plex Sans semibold 16 pt). Der Task-Brief nennt
                // „bold 700" — Plex Sans 700 ist in der App nicht
                // gebundelt (siehe CLAUDE.md Typografie-Policy), 600
                // ist das maximale verfuegbare Gewicht.
                Text("Objekt:")
                    .appFont(Self.objektStyle)
                    .foregroundStyle(DesignTokens.text)
                Text(objektLabel)
                    .appFont(Self.objektStyle)
                    .foregroundStyle(DesignTokens.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignTokens.text)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Objekt waehlen, aktuell \(objektLabel)")
    }

    private var periodenZeile: some View {
        Button {
            if aktuelleImmobilie != nil {
                zeigePeriodenPicker = true
            }
        } label: {
            HStack(spacing: 6) {
                Text("Abrechnungszeitraum:")
                    .appFont(Self.periodenLabelStyle)
                    .foregroundStyle(DesignTokens.textSecondary)
                Text(periodenLabel)
                    .appFont(Self.periodenWertStyle)
                    .foregroundStyle(DesignTokens.textSecondary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(aktuelleImmobilie == nil)
        .accessibilityLabel("Abrechnungsperiode waehlen, aktuell \(periodenLabel)")
    }

    // MARK: - Header-spezifische Typografie

    /// Plex Sans semibold 17 pt — Objekt-Zeile. +2 pt gegenueber
    /// dem urspruenglichen 15er Body, +1 pt gegenueber der ersten
    /// Header-Iteration. Damit ist der Objekt-Name deutlich das
    /// dominante Element im Header.
    ///
    /// Plex Sans 700 (bold) ist in der App nicht gebundelt (siehe
    /// CLAUDE.md Typografie-Policy), `600` ist das maximale
    /// verfuegbare Gewicht; das groessere Size-Plus kompensiert
    /// den fehlenden Weight-Sprung.
    private static let objektStyle = AppFontStyle(
        font: AppFont.plexSans(.semibold, 17),
        tracking: 0,
        uppercase: false
    )

    /// Plex Sans medium 14 pt — Perioden-Label (-1 pt).
    private static let periodenLabelStyle = AppFontStyle(
        font: AppFont.plexSans(.medium, 14),
        tracking: 0,
        uppercase: false
    )

    /// Plex Mono regular 14 pt — Perioden-Wert (-1 pt), weiter
    /// Mono, weil Datum ein numerischer Wert ist.
    private static let periodenWertStyle = AppFontStyle(
        font: AppFont.plexMono(.regular, 14),
        tracking: 0,
        uppercase: false
    )

    // MARK: - Ableitungen

    private var aktuelleImmobilie: Immobilie? {
        if let id = scope.aktuelleImmobilieID,
           let treffer = immobilien.first(where: { $0.id == id }) {
            return treffer
        }
        return immobilien.first
    }

    private var objektLabel: String {
        if let i = aktuelleImmobilie {
            let a = i.adresse.trimmingCharacters(in: .whitespaces)
            return a.isEmpty ? "Ohne Adresse" : a
        }
        return "Kein Objekt"
    }

    private var periodenLabel: String {
        guard let immo = aktuelleImmobilie else { return "Keine Periode" }
        let perioden = (immo.perioden ?? []).sorted { $0.von > $1.von }
        guard let wahl = aktivePeriode(aus: perioden) else {
            return "Keine Periode"
        }
        return Self.periodenKurzform(wahl)
    }

    private func aktivePeriode(aus perioden: [Abrechnungsperiode]) -> Abrechnungsperiode? {
        if let id = scope.aktuellePeriodeID,
           let treffer = perioden.first(where: { $0.id == id }) {
            return treffer
        }
        return perioden.first
    }

    /// Kurze Darstellung "MMM yyyy – MMM yyyy" mit en-dash.
    /// Beispiel: "Nov 2024 – Okt 2025".
    static func periodenKurzform(_ p: Abrechnungsperiode) -> String {
        let start = monatsKurz.string(from: p.von)
        let ende  = monatsKurz.string(from: p.bis)
        return "\(start) \u{2013} \(ende)"
    }

    private static let monatsKurz: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "MMM yyyy"
        return f
    }()

    // MARK: - Sync

    /// Setzt beim App-Start / Store-Update die Achsen konsistent:
    /// - aktuelleImmobilieID bereinigen / Fallback auf erstes Objekt
    /// - aktuellePeriodeID bereinigen gegen die vorhandenen Perioden
    /// - Scope (.einheit) bereinigen gegen die Einheiten des Objekts
    private func synchronisiere() {
        let verfuegbar = Set(immobilien.map(\.id))
        scope.bereinigeImmobilie(verfuegbareIDs: verfuegbar)
        if scope.aktuelleImmobilieID == nil, let erste = immobilien.first {
            scope.aktuelleImmobilieID = erste.id
        }
        if let immo = aktuelleImmobilie {
            let periodenIDs = Set((immo.perioden ?? []).map(\.id))
            scope.bereinigePeriode(verfuegbareIDs: periodenIDs)
            if scope.aktuellePeriodeID == nil {
                let sortiert = (immo.perioden ?? []).sorted { $0.von > $1.von }
                if let neueste = sortiert.first {
                    scope.aktuellePeriodeID = neueste.id
                }
            }
            let einheitIDs = Set((immo.wohneinheiten ?? []).map(\.bezeichnung))
            scope.bereinige(verfuegbareEinheitIDs: einheitIDs)
        }
    }
}

// MARK: - WohneinheitPillReihe

/// Zeigt den aktuellen Scope als **eine** mittig zentrierte,
/// breite Pill — reine Anzeige, nicht interaktiv. Die tatsaechliche
/// Scope-Auswahl laeuft weiter unten im `WohneinheitCarousel` auf
/// dem HomeScreen. Zweck hier: Orientierung im permanenten
/// Header, egal auf welchem Tab sich der User gerade befindet.
///
/// Label-Format:
/// - „Gesamt" fuer Objekt-Scope.
/// - „<EinheitID> · <Mieter-Abkuerzung>" fuer Einheit-Scopes mit
///   aktivem Mietverhaeltnis.
/// - Nur „<EinheitID>" bei Leerstand.
///
/// Kommt evtl. spaeter wieder als Auswahl-Reihe zurueck — daher
/// kein groesseres Refactoring als noetig.
struct WohneinheitPillReihe: View {
    let immobilie: Immobilie
    @Environment(ScopeManager.self) private var scope

    private var einheiten: [Wohneinheit] {
        immobilie.wohneinheiten ?? []
    }

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            aktivePill
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }

    private var aktivePill: some View {
        HStack(spacing: 6) {
            Image(systemName: aktiverIcon)
                .font(.system(size: 11, weight: .semibold))
            Text(aktiverLabel)
                .appFont(Self.pillLabelStyle)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        // Pill-Farbe matched mit dem vertikalen UnitBalken der
        // HomeScreen-Cards — Scope-Farbe aus ScopeFarbe bzw.
        // unitObjekt im Gesamt-Scope. Damit ist die aktive
        // Wahl ueber den gesamten Shell-Chrome in derselben
        // Farbe markiert.
        .background(Capsule().fill(aktiveFarbe))
        .accessibilityLabel("Aktive Auswahl: \(aktiverLabel)")
    }

    // MARK: - Scope-Ableitungen

    private var aktiverLabel: String {
        switch scope.scope {
        case .objekt:
            return "Gesamt"
        case .einheit(let id):
            guard let e = einheiten.first(where: { $0.bezeichnung == id }) else {
                return id
            }
            return pillLabel(fuer: e)
        }
    }

    private var aktiverIcon: String {
        switch scope.scope {
        case .objekt:
            return "square.stack.3d.up"
        case .einheit(let id):
            guard let e = einheiten.first(where: { $0.bezeichnung == id }) else {
                return "square.stack.3d.up"
            }
            return ScopeFarbe.icon(fuer: e)
        }
    }

    /// Aktive Scope-Farbe — identisch zur UnitBalken-Logik in
    /// den Home-Cards. Gesamt-Scope nutzt `unitObjekt`, Einheit-
    /// Scope die ScopeFarbe der jeweiligen WE.
    private var aktiveFarbe: Color {
        switch scope.scope {
        case .objekt:
            return DesignTokens.unitObjekt
        case .einheit(let id):
            guard let e = einheiten.first(where: { $0.bezeichnung == id }) else {
                return DesignTokens.unitObjekt
            }
            return ScopeFarbe.farbe(fuer: e)
        }
    }

    private func pillLabel(fuer e: Wohneinheit) -> String {
        let aktiv = (e.mietverhaeltnisse ?? []).first(where: { $0.auszugAm == nil })
        guard let mv = aktiv else { return e.bezeichnung }
        let kurz = ScopeTexte.abkuerzungName(mv.mieterName)
        guard !kurz.isEmpty else { return e.bezeichnung }
        return "\(e.bezeichnung) · \(kurz)"
    }

    /// Plex Sans semibold 13 pt — klar lesbar im Header-Band.
    private static let pillLabelStyle = AppFontStyle(
        font: AppFont.plexSans(.semibold, 13),
        tracking: 0.1,
        uppercase: false
    )
}
