//
//  EinstellungenSheet.swift
//  NebenkostenApp — UI/Shell
//
//  Vollständiges Einstellungen-Sheet nach UI-Fix-2 · 7.
//  Acht Sections (Reihenfolge fix):
//    1. OBJEKT                (readonly Stammdaten)
//    2. MIETER & VORAUSZAHLUNGEN
//    3. UMLAGESCHLÜSSEL
//    4. VERMIETER             (AppUser-Stammdaten)
//    5. DATEN                 (Export / Import / Löschen zweistufig)
//    6. RECHTLICHES           (4 Markdown-Sheets)
//    7. ÜBER DIE APP          (Version / Build / Device)
//    8. DEBUG                 (nur #if DEBUG)
//
//  Die Form nutzt System-Styling, weil Exports/Alerts/Navigation-
//  Links davon stärker profitieren als eigene Cards. Der Handoff-
//  Look kommt über die Kopf-Karte und AppFont auf Footer-Texten rein.
//

import SwiftUI
import SwiftData

struct EinstellungenSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ScopeManager.self) private var scope

    @Query(sort: \Immobilie.erstelltAm) private var immobilien: [Immobilie]

    private var immobilie: Immobilie? { immobilien.first }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    kopfZeile
                }
                .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))

                ObjektSection(immobilie: immobilie)
                MieterSection(immobilie: immobilie)
                UmlageSection(immobilie: immobilie)
                VermieterSection()
                DatenSection()
                RechtlichesSection()
                UeberSection()

                #if DEBUG
                debugSection
                #endif
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    // MARK: - Kopfzeile

    private var kopfZeile: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DesignTokens.accent)
                Image(systemName: "house.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(DesignTokens.accentText)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text("Nebenkostenabrechnung")
                    .appFont(AppFont.bodySemi())
                    .foregroundStyle(DesignTokens.text)
                Text(versionZeile)
                    .appFont(AppFont.monoCaption())
                    .foregroundStyle(DesignTokens.textSecondary)
                HStack(spacing: 6) {
                    Circle()
                        .fill(scope.farbe())
                        .frame(width: 6, height: 6)
                    Text(scope.beschriftung())
                        .appFont(AppFont.caption())
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }
            Spacer()
        }
    }

    private var versionZeile: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "Version \(version) · Build \(build)"
    }

    // MARK: - Debug (nur DEBUG)

    #if DEBUG
    @ViewBuilder
    private var debugSection: some View {
        Section {
            NavigationLink("Design-Tokens") {
                TokenProbeView()
            }
            NavigationLink("Font-Probe (Plex)") {
                FontProbeView()
            }
            NavigationLink("Altes Objekt-Dashboard") {
                Phase0RootWrapper()
            }
        } header: {
            Text("Debug")
        } footer: {
            Text("Nur in DEBUG-Builds sichtbar. Wird nach UI-3 komplett entfernt.")
                .appFont(AppFont.smallCaption())
                .foregroundStyle(DesignTokens.textTertiary)
        }
    }
    #endif
}

// MARK: - Objekt-Section (readonly)

private struct ObjektSection: View {
    let immobilie: Immobilie?

    var body: some View {
        Section {
            if let i = immobilie {
                zeile("Adresse", wert: i.adresse, mehrfachzeilig: true)
                zeile("Ort", wert: i.ort)
                zeile("Gesamtfläche", wert: Formatting.m2(i.gesamtflaecheM2), mono: true)
                zeile("Einheiten", wert: "\(i.wohneinheiten?.count ?? 0)")
                zeile("Abrechnungsstart", wert: startDatum(i))
            } else {
                Text("Noch kein Objekt angelegt.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Objekt")
        }
    }

    private func startDatum(_ i: Immobilie) -> String {
        "\(String(format: "%02d", i.abrechnungsstartTag)).\(String(format: "%02d", i.abrechnungsstartMonat)). (jährlich)"
    }

    private func zeile(_ label: String, wert: String, mehrfachzeilig: Bool = false, mono: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            Text(wert)
                .appFont(mono ? AppFont.monoCaption() : AppFont.body())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(mehrfachzeilig ? nil : 1)
        }
    }
}

// MARK: - Mieter-Section

/// Tappbare Liste der aktiven Mietverhaeltnisse. Tap auf eine
/// Zeile oeffnet das VorauszahlungEingabeSheet (fokussiert auf
/// die getappte Einheit) ueber den AppShellRouter — damit ist
/// derselbe Eingabe-Flow erreichbar wie aus der Nachster-
/// Schritt-Card auf der Home-View.
private struct MieterSection: View {
    let immobilie: Immobilie?

    @Environment(AppShellRouter.self) private var router

    var body: some View {
        Section {
            if let einheiten = immobilie?.wohneinheiten, !einheiten.isEmpty {
                ForEach(sortiert(einheiten)) { e in
                    Button {
                        router.oeffneVorauszahlungSheet(einheitID: e.bezeichnung)
                    } label: {
                        mieterZeile(e)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("Noch keine Einheiten erfasst.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Mieter & Vorauszahlungen")
        } footer: {
            Text("Tippe auf eine Zeile, um die Vorauszahlung anzupassen.")
                .foregroundStyle(.secondary)
        }
    }

    private func sortiert(_ einheiten: [Wohneinheit]) -> [Wohneinheit] {
        einheiten.sorted { ScopeFilter.einheitRang($0.bezeichnung) < ScopeFilter.einheitRang($1.bezeichnung) }
    }

    private func mieterZeile(_ e: Wohneinheit) -> some View {
        let mv = (e.mietverhaeltnisse ?? []).first { $0.auszugAm == nil }
        return HStack(alignment: .center, spacing: 10) {
            UnitBalken(farbe: ScopeFarbe.farbe(fuer: e))
                .frame(height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(e.bezeichnung)
                    .appFont(AppFont.bodySemi())
                    .foregroundStyle(DesignTokens.text)
                if let mv {
                    Text(ScopeTexte.abkuerzungName(mv.mieterName))
                        .appFont(AppFont.caption())
                        .foregroundStyle(DesignTokens.textSecondary)
                } else {
                    Text("Leerstand")
                        .appFont(AppFont.caption())
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }
            Spacer(minLength: 8)
            if let mv {
                Text(Formatting.euro(mv.vorauszahlungMonatEuro))
                    .appFont(AppFont.monoCaption())
                    .foregroundStyle(DesignTokens.text)
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(DesignTokens.textTertiary)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Umlage-Section (readonly)

private struct UmlageSection: View {
    let immobilie: Immobilie?

    var body: some View {
        Section {
            if let kostenarten = immobilie?.kostenarten, !kostenarten.isEmpty {
                ForEach(kostenarten.sorted { $0.sortierung < $1.sortierung }) { ka in
                    HStack {
                        Text(ka.bezeichnung)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(ka.umlageschluessel.anzeigeName)
                            .appFont(AppFont.caption())
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Noch keine Kostenarten definiert.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Umlageschlüssel (BetrKV)")
        }
    }
}

/// Kapselt die Phase-0-`RootTabView` damit sie als NavigationLink-
/// Destination benutzbar bleibt. Wird zusammen mit dem Debug-Menü
/// in UI-3 entfernt.
private struct Phase0RootWrapper: View {
    var body: some View {
        RootTabView()
            .navigationTitle("Phase-0-App")
            .navigationBarTitleDisplayMode(.inline)
    }
}
