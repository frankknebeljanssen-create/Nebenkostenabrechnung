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

/// „Gesamt" + eine Pill pro Wohneinheit. Pro Pill-Breite: 72 %
/// der Container-Breite (via `.containerRelativeFrame`) — damit
/// ist die aktive Pill komplett sichtbar, die naechste Pill
/// peekt rechts ein Stueck rein als Scroll-Hinweis. Die Reihe
/// snap-scrollt zwischen den Pills.
///
/// Label-Format:
/// - „Gesamt" fuer den Objekt-Scope.
/// - „<EinheitID> · <Mieter-Abkuerzung>" fuer Einheit-Scopes,
///   wenn ein aktives Mietverhaeltnis existiert. Mit 72 % Pill-
///   Breite passt der komplette Mieter-Name („Fam. Pfaffenbach")
///   ohne Truncation.
/// - Nur „<EinheitID>" wenn kein aktiver Mieter (Leerstand).
///
/// Layout:
/// - Pill-Hoehe ~36 pt (Icon + Text + vertical Padding 10).
/// - Unselected: textPrimary auf transparentem Grund.
/// - Selected: weiss auf Accent-Pill (#3A5578).
struct WohneinheitPillReihe: View {
    let immobilie: Immobilie
    @Environment(ScopeManager.self) private var scope

    private var einheiten: [Wohneinheit] {
        immobilie.wohneinheiten ?? []
    }

    /// Relative Pill-Breite in Bruchteilen der Container-Breite.
    /// 0.72 = 72 % — aktive Pill voll sichtbar, die naechste
    /// peekt mit ~20 % rein.
    private let pillBreiteAnteil: CGFloat = 0.72

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                pill(
                    label: "Gesamt",
                    icon: "square.stack.3d.up",
                    aktiv: scope.isObjekt
                ) {
                    scope.scope = .objekt
                }
                .containerRelativeFrame(.horizontal) { laenge, _ in
                    laenge * pillBreiteAnteil
                }

                ForEach(einheiten) { e in
                    pill(
                        label: pillLabel(fuer: e),
                        icon: ScopeFarbe.icon(fuer: e),
                        aktiv: scope.einheitID == e.bezeichnung
                    ) {
                        scope.scope = .einheit(id: e.bezeichnung)
                    }
                    .containerRelativeFrame(.horizontal) { laenge, _ in
                        laenge * pillBreiteAnteil
                    }
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 16)
        }
        .scrollTargetBehavior(.viewAligned)
    }

    /// Label-Builder fuer Einheit-Pills. „OG · Fam. Pfaffenbach"
    /// wenn aktives Mietverhaeltnis da ist, sonst nur die
    /// Bezeichnung (z.B. bei Leerstand).
    private func pillLabel(fuer e: Wohneinheit) -> String {
        let aktiv = (e.mietverhaeltnisse ?? []).first(where: { $0.auszugAm == nil })
        guard let mv = aktiv else { return e.bezeichnung }
        let kurz = ScopeTexte.abkuerzungName(mv.mieterName)
        guard !kurz.isEmpty else { return e.bezeichnung }
        return "\(e.bezeichnung) · \(kurz)"
    }

    private func pill(
        label: String,
        icon: String,
        aktiv: Bool,
        aktion: @escaping () -> Void
    ) -> some View {
        Button(action: aktion) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .appFont(Self.pillLabelStyle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .truncationMode(.tail)
            }
            .foregroundStyle(aktiv ? Color.white : DesignTokens.text)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(aktiv ? DesignTokens.accent : Color.clear)
            .overlay(
                Capsule().stroke(
                    aktiv ? DesignTokens.accent : DesignTokens.separatorStrong,
                    lineWidth: 0.5
                )
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(aktiv ? .isSelected : [])
    }

    /// Plex Sans semibold 13 pt — die Pill-Label sollen klar lesbar
    /// und kraeftig wirken; 600 ist das maximale verfuegbare Gewicht
    /// in der App (Plex Sans 700 ist nicht gebundelt).
    private static let pillLabelStyle = AppFontStyle(
        font: AppFont.plexSans(.semibold, 13),
        tracking: 0.1,
        uppercase: false
    )
}
