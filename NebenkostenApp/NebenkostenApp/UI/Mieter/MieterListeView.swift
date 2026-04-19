//
//  MieterListeView.swift
//  NebenkostenApp — UI/Mieter
//
//  Liste aller Mietverhältnisse einer Immobilie, gruppiert nach
//  Wohneinheit. Tap öffnet das Edit-Sheet; "+" legt ein neues
//  Mietverhältnis an (Wohneinheit im Sheet wählbar).
//

import SwiftUI
import SwiftData

struct MieterListeView: View {
    @Bindable var immobilie: Immobilie
    @State private var zeigeNeu = false
    @State private var auswahl: Mietverhaeltnis?

    private var einheiten: [Wohneinheit] {
        (immobilie.wohneinheiten ?? []).sorted { lhs, rhs in
            let rL = sortierrang(lhs.bezeichnung)
            let rR = sortierrang(rhs.bezeichnung)
            if rL != rR { return rL < rR }
            return lhs.bezeichnung.localizedStandardCompare(rhs.bezeichnung) == .orderedAscending
        }
    }

    var body: some View {
        List {
            if einheiten.isEmpty {
                Section {
                    Text("Keine Wohneinheiten vorhanden. Lege zuerst Einheiten an.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(einheiten) { einheit in
                Section(einheitTitel(einheit)) {
                    let liste = sortiert(einheit.mietverhaeltnisse ?? [])
                    if liste.isEmpty {
                        Text("Kein Mietverhältnis")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(liste) { mv in
                            Button {
                                auswahl = mv
                            } label: {
                                zeile(mv)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationTitle("Mieter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    zeigeNeu = true
                } label: {
                    Label("Neues Mietverhältnis", systemImage: "plus")
                }
                .disabled(einheiten.isEmpty)
            }
        }
        .sheet(isPresented: $zeigeNeu) {
            MieterEditView(modus: .neu(immobilie: immobilie, vorauswahl: nil))
        }
        .sheet(item: $auswahl) { mv in
            MieterEditView(modus: .bearbeiten(mv))
        }
    }

    // MARK: - Zeile

    private func zeile(_ mv: Mietverhaeltnis) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(mv.mieterName.isEmpty ? "Ohne Namen" : mv.mieterName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(mv.auszugAm == nil ? .primary : .secondary)
                HStack(spacing: 6) {
                    Text(mv.mieterTyp.rawValue)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundStyle(.tint)
                        .clipShape(Capsule())
                    if mv.anzahlPersonen > 1 {
                        Text("\(mv.anzahlPersonen) Personen")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            if mv.auszugAm != nil {
                Text("Ausgezogen")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Capsule())
            }
        }
        .contentShape(Rectangle())
    }

    // MARK: - Helfer

    private func sortiert(_ mvs: [Mietverhaeltnis]) -> [Mietverhaeltnis] {
        mvs.sorted { lhs, rhs in
            // Aktive (auszugAm == nil) zuerst, dann nach Einzug absteigend
            if (lhs.auszugAm == nil) != (rhs.auszugAm == nil) {
                return lhs.auszugAm == nil
            }
            return lhs.einzugAm > rhs.einzugAm
        }
    }

    private func einheitTitel(_ einheit: Wohneinheit) -> String {
        let bez = einheit.bezeichnung.isEmpty ? "Unbenannt" : einheit.bezeichnung
        let nutzung = einheit.nutzungsart.rawValue.capitalized
        return "\(bez) · \(nutzung)"
    }

    private func sortierrang(_ bezeichnung: String) -> Int {
        let key = bezeichnung.uppercased().trimmingCharacters(in: .whitespaces)
        switch key {
        case "KG", "UG":                 return 0
        case "EG":                       return 1
        case "OG", "1. OG", "1.OG":      return 2
        case "2. OG", "2.OG":            return 3
        case "DG":                       return 4
        default:                         return 99
        }
    }
}
