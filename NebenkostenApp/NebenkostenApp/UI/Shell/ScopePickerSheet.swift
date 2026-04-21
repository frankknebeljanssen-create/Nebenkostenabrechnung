//
//  ScopePickerSheet.swift
//  NebenkostenApp — UI/Shell
//
//  Platzhalter-Sheet für den Scope-Wechsel. In UI-0 nur rudimentäre
//  Liste; volle Integration (Wohneinheit-spezifische Icons, Mieter-
//  Namen, Farben) folgt in UI-1.
//

import SwiftUI
import SwiftData

struct ScopePickerSheet: View {
    @Environment(ScopeManager.self) private var scope
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Immobilie.erstelltAm) private var immobilien: [Immobilie]

    private var einheiten: [Wohneinheit] {
        immobilien.first?.wohneinheiten ?? []
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        scope.current = .objekt
                        dismiss()
                    } label: {
                        HStack {
                            Rectangle()
                                .fill(DesignTokens.unitObjekt)
                                .frame(width: 12, height: 12)
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                            Text("Gesamtes Objekt")
                                .appFont(AppFont.bodyMedium())
                            Spacer()
                            if scope.isObjekt {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(DesignTokens.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                Section("Einzelne Einheit") {
                    ForEach(einheiten) { e in
                        Button {
                            scope.current = .einheit(id: e.bezeichnung)
                            dismiss()
                        } label: {
                            HStack {
                                Rectangle()
                                    .fill(ScopeFarbe.farbe(fuer: e))
                                    .frame(width: 12, height: 12)
                                    .clipShape(RoundedRectangle(cornerRadius: 2))
                                VStack(alignment: .leading) {
                                    Text(e.bezeichnung)
                                        .appFont(AppFont.bodyMedium())
                                    if let mv = (e.mietverhaeltnisse ?? [])
                                        .first(where: { $0.auszugAm == nil }) {
                                        Text(ScopeTexte.abkuerzungName(mv.mieterName))
                                            .appFont(AppFont.caption())
                                            .foregroundStyle(DesignTokens.textSecondary)
                                    }
                                }
                                Spacer()
                                if scope.einheitID == e.bezeichnung {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(DesignTokens.accent)
                                }
                            }
                        }
                        .buttonStyle(.plain)
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
}
