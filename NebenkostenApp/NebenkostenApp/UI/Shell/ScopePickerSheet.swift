//
//  ScopePickerSheet.swift
//  NebenkostenApp — UI/Shell
//
//  Full-Implementation des Scope-Wechsel-Sheets. Wird vom
//  `AppShellChrome`-Adress-Button (`onAdresse`-Callback) in jedem
//  Tab geoeffnet und bietet zwei Ebenen:
//
//    - „Gesamtes Objekt" — Sammelsicht aller Einheiten.
//    - Einzelne Einheit — nach Geschoss-Rang sortiert, mit Farb-
//      Swatch, Mieter- oder Nutzungsart-Sub-Label.
//
//  Die Immobilie wird aus `ScopeManager.aktuelleImmobilieID`
//  abgeleitet — im MVP gibt es pro User nur eine, der Code ist aber
//  schon Multi-Immobilie-fest. Fallback: erste Immobilie im Store.
//  Die Einheiten-Sortierung ist die gleiche wie ueberall sonst
//  (`ScopeFilter.sichtbareEinheiten`), damit der User bei Scope-
//  Wechseln keine unterschiedliche Reihenfolge erlebt.
//

import SwiftUI
import SwiftData

struct ScopePickerSheet: View {
    @Environment(ScopeManager.self) private var scope
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Immobilie.erstelltAm) private var immobilien: [Immobilie]

    // MARK: - Abgeleitet

    private var aktuelleImmobilie: Immobilie? {
        if let id = scope.aktuelleImmobilieID,
           let match = immobilien.first(where: { $0.id == id }) {
            return match
        }
        return immobilien.first
    }

    private var einheiten: [Wohneinheit] {
        let alle = aktuelleImmobilie?.wohneinheiten ?? []
        return ScopeFilter.sichtbareEinheiten(alle: alle, scope: .objekt)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                Section {
                    objektRow
                }
                if !einheiten.isEmpty {
                    Section("Einzelne Einheit") {
                        ForEach(einheiten) { einheit in
                            einheitRow(einheit)
                        }
                    }
                }
            }
            .navigationTitle("Scope wechseln")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetToolbar.abbrechen(titel: "Fertig") { dismiss() }
                }
            }
        }
    }

    // MARK: - Rows

    private var objektRow: some View {
        Button {
            scope.current = .objekt
            dismiss()
        } label: {
            HStack(spacing: 12) {
                farbSwatch(DesignTokens.unitObjekt)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ScopeTexte.gesamtLabel)
                        .appFont(AppFont.Basis.bodyMedium())
                        .foregroundStyle(DesignTokens.text)
                    if let sub = objektSubLabel {
                        Text(sub)
                            .appFont(AppFont.Basis.caption())
                            .foregroundStyle(DesignTokens.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if scope.isObjekt {
                    Image(systemName: "checkmark")
                        .foregroundStyle(DesignTokens.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func einheitRow(_ einheit: Wohneinheit) -> some View {
        Button {
            scope.current = .einheit(id: einheit.bezeichnung)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                farbSwatch(ScopeFarbe.farbe(fuer: einheit))
                VStack(alignment: .leading, spacing: 2) {
                    Text(einheit.bezeichnung)
                        .appFont(AppFont.Basis.bodyMedium())
                        .foregroundStyle(DesignTokens.text)
                    Text(einheitSubLabel(einheit))
                        .appFont(AppFont.Basis.caption())
                        .foregroundStyle(DesignTokens.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                if scope.einheitID == einheit.bezeichnung {
                    Image(systemName: "checkmark")
                        .foregroundStyle(DesignTokens.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func farbSwatch(_ farbe: Color) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(farbe)
            .frame(width: 12, height: 12)
    }

    // MARK: - Labels

    /// Sub-Label für die Objekt-Row: Adresse + Anzahl Einheiten, z.B.
    /// „Bahnhofstr. 37 · 3 Einheiten". Fehlt die Adresse, bleibt nur
    /// die Einheitenzahl. Dient als Identifier fuer User mit mehreren
    /// Objekten.
    private var objektSubLabel: String? {
        let adresse = aktuelleImmobilie?.adresse.trimmingCharacters(in: .whitespaces) ?? ""
        let n = einheiten.count
        let einheitenTxt = n == 0
            ? "Keine Einheiten"
            : "\(n) Einheit\(n == 1 ? "" : "en")"
        guard !adresse.isEmpty else { return einheitenTxt }
        return "\(adresse) · \(einheitenTxt)"
    }

    /// Sub-Label einer Einheit-Row: Mieter-Abkürzung wenn aktiver
    /// Vertrag, sonst Nutzungsart-Hinweis („Gewerbe", „Leerstand").
    /// „Ohne Mieter" für Wohn-Einheiten ohne Vertrag signalisiert
    /// fehlende Stammdaten, nicht Leerstand.
    private func einheitSubLabel(_ einheit: Wohneinheit) -> String {
        let mieter = (einheit.mietverhaeltnisse ?? [])
            .first(where: { $0.auszugAm == nil })?.mieterName ?? ""
        if !mieter.isEmpty {
            return ScopeTexte.abkuerzungName(mieter)
        }
        switch einheit.nutzungsart {
        case .wohnung, .einliegerwohnung: return "Ohne aktiven Mieter"
        case .gewerbe:                    return "Gewerbe"
        case .leerstand:                  return "Leerstand"
        }
    }
}
