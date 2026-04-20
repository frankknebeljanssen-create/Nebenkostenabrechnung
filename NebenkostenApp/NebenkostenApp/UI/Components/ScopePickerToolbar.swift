//
//  ScopePickerToolbar.swift
//  NebenkostenApp — UI/Components
//
//  ToolbarContent, das den Navigation-Title durch einen tappbaren Scope-
//  Picker ersetzt: oben Objekt-Name oder Einheit-Name + Chevron, Tap
//  öffnet Menu mit "Gesamtes Objekt" und den einzelnen Einheiten.
//
//  Bei Objekten mit weniger als 2 Einheiten wird der Picker ausgeblendet
//  (fester Titel) — es gibt dann nichts zu schalten.
//

import SwiftUI

struct ScopePickerToolbar: ToolbarContent {
    let immobilie: Immobilie
    @Environment(ScopeManager.self) private var scopeManager

    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            if einheiten.count < 2 {
                Text(festerTitel)
                    .font(.headline)
                    .lineLimit(1)
            } else {
                Menu {
                    Section {
                        Button {
                            scopeManager.scope = .objekt
                        } label: {
                            HStack {
                                Label(ScopeTexte.gesamtLabel,
                                      systemImage: "building.2.fill")
                                if scopeManager.isObjekt {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    Section("Einzelne Wohneinheit") {
                        ForEach(einheiten) { e in
                            Button {
                                scopeManager.scope = .einheit(id: e.bezeichnung)
                            } label: {
                                HStack {
                                    Label(eintragsTitel(e),
                                          systemImage: ScopeFarbe.icon(fuer: e))
                                    if scopeManager.einheitID == e.bezeichnung {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(aktuellerTitel)
                            .font(.headline)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                }
                .accessibilityLabel("Scope wechseln, aktuell \(aktuellerTitel)")
            }
        }
    }

    // MARK: - Abgeleitet

    private var einheiten: [Wohneinheit] {
        (immobilie.wohneinheiten ?? []).sorted { lhs, rhs in
            let l = sortierrang(lhs.bezeichnung)
            let r = sortierrang(rhs.bezeichnung)
            if l != r { return l < r }
            return lhs.bezeichnung.localizedStandardCompare(rhs.bezeichnung) == .orderedAscending
        }
    }

    private var festerTitel: String {
        if immobilie.adresse.isEmpty {
            return "Objekt"
        }
        return immobilie.adresse
    }

    private var aktuellerTitel: String {
        switch scopeManager.scope {
        case .objekt:
            return ScopeTexte.gesamtLabel
        case .einheit(let id):
            let e = einheiten.first(where: { $0.bezeichnung == id })
            let name = (e?.mietverhaeltnisse ?? [])
                .first(where: { $0.auszugAm == nil })?.mieterName ?? ""
            return ScopeTexte.scopeTitel(einheitID: id, mieterName: name)
        }
    }

    private func eintragsTitel(_ e: Wohneinheit) -> String {
        let aktiverMieter = (e.mietverhaeltnisse ?? [])
            .first { $0.auszugAm == nil }
        return ScopeTexte.scopeTitel(
            einheitID: e.bezeichnung,
            mieterName: aktiverMieter?.mieterName ?? ""
        )
    }

    private func sortierrang(_ bezeichnung: String) -> Int {
        let key = bezeichnung.uppercased().trimmingCharacters(in: .whitespaces)
        switch key {
        case "KG", "UG", "KELLER", "KELLERGESCHOSS", "UNTERGESCHOSS": return 0
        case "EG", "ERDGESCHOSS":                                   return 1
        case "OG", "1. OG", "1.OG", "OBERGESCHOSS",
             "1. OBERGESCHOSS":                                     return 2
        case "2. OG", "2.OG", "2. OBERGESCHOSS":                    return 3
        case "DG", "DACHGESCHOSS":                                  return 4
        default:                                                    return 99
        }
    }
}
