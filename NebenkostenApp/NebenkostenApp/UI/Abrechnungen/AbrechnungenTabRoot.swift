//
//  AbrechnungenTabRoot.swift
//  NebenkostenApp — UI/Abrechnungen
//

import SwiftUI
import SwiftData

struct AbrechnungenTabRoot: View {
    @Query(sort: \Immobilie.erstelltAm) private var immobilien: [Immobilie]
    @Environment(ObjektWahl.self) private var objektWahl

    private var aktiveImmobilie: Immobilie? {
        if let id = objektWahl.aktiveID,
           let match = immobilien.first(where: { $0.id == id }) {
            return match
        }
        return immobilien.first
    }

    var body: some View {
        NavigationStack {
            if let immobilie = aktiveImmobilie {
                PeriodenListe(immobilie: immobilie)
                    .navigationTitle("Abrechnungen")
                    .navigationDestination(for: Abrechnungsperiode.self) { p in
                        AbrechnungVorschauView(periode: p, immobilie: immobilie)
                    }
            } else {
                TabPlatzhalterView(titel: "Abrechnungen",
                                   symbol: "doc.text.magnifyingglass")
                    .navigationTitle("Abrechnungen")
            }
        }
    }
}

private struct PeriodenListe: View {
    @Bindable var immobilie: Immobilie

    private var perioden: [Abrechnungsperiode] {
        (immobilie.perioden ?? []).sorted(by: { $0.bis > $1.bis })
    }

    var body: some View {
        List {
            if perioden.isEmpty {
                Section {
                    Text("Noch keine Abrechnungsperiode angelegt.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(perioden) { p in
                        NavigationLink(value: p) {
                            zeile(p)
                        }
                    }
                } footer: {
                    Text("Tipp: Tippe eine Periode an, um die Abrechnung für alle aktiven Mieter zu erstellen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func zeile(_ p: Abrechnungsperiode) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formatiere(p))
                .font(.body.weight(.semibold))
            HStack(spacing: 8) {
                Text(p.abgeschlossen ? "Abgeschlossen" : "Laufend")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let versandt = p.versandtAm {
                    Text("· Versandt \(versandt.formatted(date: .numeric, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatiere(_ p: Abrechnungsperiode) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "de_DE")
        return "\(f.string(from: p.von)) – \(f.string(from: p.bis))"
    }
}
