//
//  ObjektPickerSheet.swift
//  NebenkostenApp — UI/Chrome
//
//  Modales Sheet fuer den Objekt-Wechsel. Analoges Muster zum
//  bestehenden `ScopePickerSheet`: NavigationStack + List + Checkmark
//  bei aktivem Eintrag. Tap setzt `ScopeManager.aktuelleImmobilieID`
//  und dismisst. Der Setter im ScopeManager ruft beim tatsaechlichen
//  Wechsel automatisch `scope = .objekt` auf — der User landet auf
//  "Gesamt" und wuerde sonst auf einer Einheit-ID stehen, die im
//  neuen Objekt gar nicht existiert.
//

import SwiftUI
import SwiftData

struct ObjektPickerSheet: View {
    @Environment(ScopeManager.self) private var scope
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Immobilie.erstelltAm) private var immobilien: [Immobilie]

    var body: some View {
        NavigationStack {
            List {
                if immobilien.isEmpty {
                    Text("Keine Objekte vorhanden")
                        .appFont(AppFont.bodyMedium())
                        .foregroundStyle(DesignTokens.textSecondary)
                } else {
                    ForEach(immobilien) { immo in
                        Button {
                            scope.aktuelleImmobilieID = immo.id
                            dismiss()
                        } label: {
                            zeile(fuer: immo)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Objekt wählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetToolbar.abbrechen(titel: "Fertig") { dismiss() }
                }
            }
        }
    }

    private func zeile(fuer immo: Immobilie) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "building.2")
                .font(.system(size: 15))
                .foregroundStyle(DesignTokens.textSecondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(immo.adresse.isEmpty ? "Ohne Adresse" : immo.adresse)
                    .appFont(AppFont.bodyMedium())
                    .foregroundStyle(DesignTokens.text)
                    .lineLimit(1)
                if !immo.ort.isEmpty {
                    Text(immo.ort)
                        .appFont(AppFont.caption())
                        .foregroundStyle(DesignTokens.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if scope.aktuelleImmobilieID == immo.id {
                Image(systemName: "checkmark")
                    .foregroundStyle(DesignTokens.accent)
            }
        }
        .contentShape(Rectangle())
    }
}
