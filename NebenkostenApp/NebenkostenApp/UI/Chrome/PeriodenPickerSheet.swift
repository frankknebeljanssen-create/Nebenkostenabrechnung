//
//  PeriodenPickerSheet.swift
//  NebenkostenApp — UI/Chrome
//
//  Modales Sheet fuer den Perioden-Wechsel einer Immobilie. Perioden
//  kommen aus der Relationship `Immobilie.perioden` und werden
//  absteigend nach Startdatum sortiert (neueste zuerst). "Neue
//  Periode anlegen" ist ein disabled Stub — die Erstellungs-UI
//  kommt in Phase 1 zusammen mit dem Perioden-Editor.
//

import SwiftUI
import SwiftData

struct PeriodenPickerSheet: View {
    let immobilie: Immobilie

    @Environment(ScopeManager.self) private var scope
    @Environment(\.dismiss) private var dismiss

    private var perioden: [Abrechnungsperiode] {
        (immobilie.perioden ?? []).sorted { $0.von > $1.von }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if perioden.isEmpty {
                        Text("Keine Perioden vorhanden")
                            .appFont(AppFont.bodyMedium())
                            .foregroundStyle(DesignTokens.textSecondary)
                    } else {
                        ForEach(perioden) { p in
                            Button {
                                scope.aktuellePeriodeID = p.id
                                dismiss()
                            } label: {
                                zeile(fuer: p)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Section {
                    Button {
                        // Stub — Perioden-Erstellung kommt in Phase 1.
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(DesignTokens.textTertiary)
                            Text("Neue Periode anlegen")
                                .appFont(AppFont.bodyMedium())
                                .foregroundStyle(DesignTokens.textTertiary)
                            Spacer()
                            Text("bald")
                                .appFont(AppFont.caption())
                                .foregroundStyle(DesignTokens.textQuaternary)
                        }
                    }
                    .disabled(true)
                }
            }
            .navigationTitle("Periode wählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetToolbar.abbrechen(titel: "Fertig") { dismiss() }
                }
            }
        }
    }

    private func zeile(fuer p: Abrechnungsperiode) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(KontextHeader.periodenKurzform(p))
                    .appFont(AppFont.bodyMedium())
                    .foregroundStyle(DesignTokens.text)
                Text(Formatting.periode(p.von, p.bis))
                    .appFont(AppFont.Basis.monoSmall())
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            Spacer()
            if p.abgeschlossen {
                Text("Abgeschlossen")
                    .appFont(AppFont.caption())
                    .foregroundStyle(DesignTokens.statusOk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(DesignTokens.statusOkSoft)
                    .clipShape(Capsule())
            }
            if scope.aktuellePeriodeID == p.id {
                Image(systemName: "checkmark")
                    .foregroundStyle(DesignTokens.accent)
            }
        }
        .contentShape(Rectangle())
    }
}
