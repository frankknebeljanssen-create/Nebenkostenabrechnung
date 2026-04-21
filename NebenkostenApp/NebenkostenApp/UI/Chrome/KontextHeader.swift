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
        .padding(.bottom, 12)
        .background {
            DesignTokens.bgAppCompact
                .ignoresSafeArea(.container, edges: .top)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignTokens.separatorStrong)
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
                Text("Objekt:")
                    .appFont(AppFont.bodySemi())
                    .foregroundStyle(DesignTokens.textSecondary)
                Text(objektLabel)
                    .appFont(AppFont.bodySemi())
                    .foregroundStyle(DesignTokens.accent)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DesignTokens.accent)
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
                    .appFont(AppFont.bodyMedium())
                    .foregroundStyle(DesignTokens.textSecondary)
                Text(periodenLabel)
                    .appFont(AppFont.Basis.monoBody())
                    .foregroundStyle(DesignTokens.text)
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

/// "Gesamt" + eine Pill pro Wohneinheit. Zentriert, wenn alle
/// Pills in die Breite passen; sonst horizontal scrollbar (ohne
/// Indikator). Farbgebung folgt `ScopeFarbe` / `DesignTokens.
/// unitObjekt` — aktive Pill bekommt Soft-Hintergrund + 0.5 pt
/// farbigen Strich.
struct WohneinheitPillReihe: View {
    let immobilie: Immobilie
    @Environment(ScopeManager.self) private var scope

    private var einheiten: [Wohneinheit] {
        immobilie.wohneinheiten ?? []
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            pillenHStack
                .frame(maxWidth: .infinity)   // zentriert, wenn passt
            ScrollView(.horizontal, showsIndicators: false) {
                pillenHStack
                    .padding(.horizontal, 16)
            }
        }
    }

    private var pillenHStack: some View {
        HStack(spacing: 8) {
            pill(
                label: "Gesamt",
                icon: "square.stack.3d.up",
                farbe: DesignTokens.unitObjekt,
                soft: DesignTokens.unitObjektSoft,
                aktiv: scope.isObjekt
            ) {
                scope.scope = .objekt
            }
            ForEach(einheiten) { e in
                let farbe = ScopeFarbe.farbe(fuer: e)
                pill(
                    label: e.bezeichnung,
                    icon: ScopeFarbe.icon(fuer: e),
                    farbe: farbe,
                    soft: farbe.opacity(0.12),
                    aktiv: scope.einheitID == e.bezeichnung
                ) {
                    scope.scope = .einheit(id: e.bezeichnung)
                }
            }
        }
    }

    private func pill(
        label: String,
        icon: String,
        farbe: Color,
        soft: Color,
        aktiv: Bool,
        aktion: @escaping () -> Void
    ) -> some View {
        Button(action: aktion) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .appFont(AppFont.captionMedium())
            }
            .foregroundStyle(aktiv ? farbe : DesignTokens.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(aktiv ? soft : Color.clear)
            .overlay(
                Capsule().stroke(
                    aktiv ? farbe.opacity(0.5) : DesignTokens.separator,
                    lineWidth: 0.5
                )
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(aktiv ? .isSelected : [])
    }
}
