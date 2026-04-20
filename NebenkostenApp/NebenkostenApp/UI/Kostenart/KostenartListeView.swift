//
//  KostenartListeView.swift
//  NebenkostenApp — UI/Kostenart
//
//  Kostenarten gruppiert in thematischen Blöcken (Verbrauchs­kosten,
//  Fixkosten & Abgaben, Dienstleistungen, Sonstiges) — analog zur
//  gruppierten Rechnungs-Liste, aber ohne Ein/Ausklappen, weil
//  Kostenarten im MVP überschaubar sind.
//

import SwiftUI
import SwiftData

struct KostenartListeView: View {
    @Bindable var immobilie: Immobilie

    @State private var zeigeNeu = false
    @State private var auswahl: Kostenart?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if alleKostenarten.isEmpty {
                    leerZustand
                } else {
                    ForEach(gruppen, id: \.titel) { gruppe in
                        gruppenCard(gruppe)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Kostenarten")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    zeigeNeu = true
                } label: {
                    Label("Neue Kostenart", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $zeigeNeu) {
            KostenartEditView(modus: .neu(immobilie: immobilie))
        }
        .sheet(item: $auswahl) { ka in
            KostenartEditView(modus: .bearbeiten(ka))
        }
    }

    // MARK: - Daten

    private var alleKostenarten: [Kostenart] {
        immobilie.kostenarten ?? []
    }

    private struct Gruppe {
        let titel: String
        let untertitel: String
        let symbol: String
        let tint: Color
        let kostenarten: [Kostenart]
        let rang: Int
    }

    private var gruppen: [Gruppe] {
        let nachRang = Dictionary(grouping: alleKostenarten) { ka in
            Self.blockRang(fuer: ka)
        }
        return nachRang
            .map { (rang, liste) -> Gruppe in
                let meta = Self.blockMeta(rang)
                return Gruppe(
                    titel: meta.titel,
                    untertitel: meta.untertitel,
                    symbol: meta.symbol,
                    tint: meta.tint,
                    kostenarten: liste.sorted { lhs, rhs in
                        if lhs.sortierung != rhs.sortierung { return lhs.sortierung < rhs.sortierung }
                        return lhs.bezeichnung.localizedStandardCompare(rhs.bezeichnung) == .orderedAscending
                    },
                    rang: rang
                )
            }
            .sorted { $0.rang < $1.rang }
    }

    // MARK: - Block-Klassifikation

    private static func blockRang(fuer ka: Kostenart) -> Int {
        let n = ka.bezeichnung.lowercased()

        // Verbrauchs- und Wärmekosten (variabel, Kernkosten der NK-
        // Abrechnung): Heizung, Warmwasser, Wasser, Strom.
        switch ka.umlageschluessel {
        case .heizkosten3070, .heizkosten5050, .warmwasser3070, .verbrauch:
            return 1
        default: break
        }
        if n.contains("heiz") || n.contains("wasser")
           || n.contains("strom") || n.contains("gas") {
            return 1
        }

        // Dienstleistungen — typ. §35a-relevant.
        if n.contains("reinig") || n.contains("garten")
           || n.contains("schornstein") || n.contains("schnee")
           || n.contains("eis") || n.contains("hausmeister")
           || n.contains("wartung") {
            return 3
        }
        if ka.paragraph35a {
            return 3
        }

        // Fixkosten & Abgaben.
        if n.contains("grundsteuer") || n.contains("versicher")
           || n.contains("müll") || n.contains("bsr")
           || n.contains("stadtrein") || n.contains("abgab") {
            return 2
        }

        return 4
    }

    private static func blockMeta(_ rang: Int) -> (titel: String, untertitel: String, symbol: String, tint: Color) {
        switch rang {
        case 1: return ("Verbrauchskosten",   "Heizung, Wasser, Strom (verbrauchsabhängig)",   "flame.fill",              .orange)
        case 2: return ("Fixkosten & Abgaben","Grundsteuer, Versicherung, Müllabfuhr",          "building.columns.fill",   .blue)
        case 3: return ("Dienstleistungen",   "Reinigung, Garten, Schornstein — §35a-relevant", "sparkles",                .green)
        default: return ("Sonstige",          "Weitere Kostenarten",                            "folder.fill",             .gray)
        }
    }

    // MARK: - Card

    private func gruppenCard(_ gruppe: Gruppe) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: gruppe.symbol)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(gruppe.tint)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(gruppe.titel)
                        .font(.callout.weight(.semibold))
                    Text(gruppe.untertitel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(gruppe.kostenarten.count)")
                    .font(.caption.monospacedDigit())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider().padding(.leading, 14)

            VStack(spacing: 0) {
                ForEach(Array(gruppe.kostenarten.enumerated()), id: \.element.id) { idx, ka in
                    Button {
                        auswahl = ka
                    } label: {
                        zeile(ka)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    if idx < gruppe.kostenarten.count - 1 {
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Zeile

    private func zeile(_ ka: Kostenart) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ka.bezeichnung.isEmpty ? "Ohne Bezeichnung" : ka.bezeichnung)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(ka.aktiv ? .primary : .secondary)
                HStack(spacing: 8) {
                    if !ka.betrKvKategorie.isEmpty {
                        Text("BetrKV §2 Nr. \(ka.betrKvKategorie)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !ka.betrKvKategorie.isEmpty {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(ka.umlageschluessel.anzeigeName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            HStack(spacing: 6) {
                if ka.paragraph35a {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.tint)
                        .accessibilityLabel("§35a EStG relevant")
                }
                if !ka.aktiv {
                    Text("Inaktiv")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }

    // MARK: - Leerzustand

    private var leerZustand: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Noch keine Kostenarten angelegt.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                zeigeNeu = true
            } label: {
                Label("Erste Kostenart anlegen", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
