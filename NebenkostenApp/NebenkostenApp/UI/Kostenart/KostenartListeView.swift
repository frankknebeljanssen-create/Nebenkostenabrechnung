//
//  KostenartListeView.swift
//  NebenkostenApp — UI/Kostenart
//

import SwiftUI
import SwiftData

struct KostenartListeView: View {
    @Bindable var immobilie: Immobilie
    @State private var zeigeNeu = false
    @State private var auswahl: Kostenart?

    private var sortierte: [Kostenart] {
        (immobilie.kostenarten ?? []).sorted { lhs, rhs in
            if lhs.sortierung != rhs.sortierung { return lhs.sortierung < rhs.sortierung }
            return lhs.bezeichnung.localizedStandardCompare(rhs.bezeichnung) == .orderedAscending
        }
    }

    var body: some View {
        List {
            if sortierte.isEmpty {
                Section {
                    Text("Noch keine Kostenarten angelegt.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(sortierte) { ka in
                        Button {
                            auswahl = ka
                        } label: {
                            zeile(ka)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
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

    // MARK: - Zeile

    private func zeile(_ ka: Kostenart) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(ka.bezeichnung.isEmpty ? "Ohne Bezeichnung" : ka.bezeichnung)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(ka.aktiv ? .primary : .secondary)

                HStack(spacing: 8) {
                    if !ka.betrKvKategorie.isEmpty {
                        Text("BetrKV §2 Nr. \(ka.betrKvKategorie)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
            }
        }
        .contentShape(Rectangle())
    }
}
