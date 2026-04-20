//
//  WarnungsSheet.swift
//  NebenkostenApp — UI/Abrechnungen
//
//  Sheet, das vor PDF-Erzeugung die Validierungs-Warnungen anzeigt.
//  User kann "Trotzdem fortfahren" (wird ins Audit-Log geschrieben)
//  oder abbrechen.
//

import SwiftUI

struct WarnungsSheet: View {
    let warnungen: [Warnung]
    let onFortfahren: () -> Void
    let onAbbrechen: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var sortiert: [Warnung] {
        warnungen.sorted { lhs, rhs in
            stufenRang(lhs.stufe) < stufenRang(rhs.stufe)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    zusammenfassung
                }

                Section("Gefundene Warnungen") {
                    ForEach(sortiert) { w in
                        zeile(w)
                    }
                }
            }
            .navigationTitle("Plausibilitätsprüfung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        onAbbrechen()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Trotzdem fortfahren") {
                        onFortfahren()
                        dismiss()
                    }
                    .disabled(enthaelFehler)
                }
            }
        }
    }

    private var zusammenfassung: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: ikon)
                    .foregroundStyle(ikonFarbe)
                    .font(.title2)
                Text(titel)
                    .font(.headline)
            }
            Text(beschreibung)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func zeile(_ w: Warnung) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: stufenIkon(w.stufe))
                .foregroundStyle(stufenFarbe(w.stufe))
                .font(.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(stufenLabel(w.stufe))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(stufenFarbe(w.stufe))
                Text(w.nachricht)
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helfer

    private var enthaelFehler: Bool {
        warnungen.contains { $0.stufe == .fehler }
    }

    private var ikon: String {
        if enthaelFehler               { return "xmark.octagon.fill" }
        if warnungen.contains(where: { $0.stufe == .warnung }) { return "exclamationmark.triangle.fill" }
        return "info.circle.fill"
    }

    private var ikonFarbe: Color {
        if enthaelFehler               { return .red }
        if warnungen.contains(where: { $0.stufe == .warnung }) { return .orange }
        return .blue
    }

    private var titel: String {
        if enthaelFehler { return "Fehler gefunden" }
        if warnungen.contains(where: { $0.stufe == .warnung }) { return "Warnungen gefunden" }
        return "Hinweise zur Abrechnung"
    }

    private var beschreibung: String {
        if enthaelFehler {
            return "Bei mindestens einem Fehler ist das Erstellen der Abrechnung blockiert. Bitte die Daten korrigieren und erneut versuchen."
        }
        let zahl = warnungen.count
        return "\(zahl) Eintrag\(zahl == 1 ? "" : "e") — Sie können die Abrechnung trotzdem erstellen. Ihre Entscheidung wird im Audit-Log mitgeschrieben."
    }

    private func stufenRang(_ s: WarnungsStufe) -> Int {
        switch s {
        case .fehler:  return 0
        case .warnung: return 1
        case .hinweis: return 2
        }
    }

    private func stufenIkon(_ s: WarnungsStufe) -> String {
        switch s {
        case .fehler:  return "xmark.octagon.fill"
        case .warnung: return "exclamationmark.triangle.fill"
        case .hinweis: return "info.circle.fill"
        }
    }

    private func stufenFarbe(_ s: WarnungsStufe) -> Color {
        switch s {
        case .fehler:  return .red
        case .warnung: return .orange
        case .hinweis: return .blue
        }
    }

    private func stufenLabel(_ s: WarnungsStufe) -> String {
        switch s {
        case .fehler:  return "FEHLER"
        case .warnung: return "WARNUNG"
        case .hinweis: return "HINWEIS"
        }
    }
}
