import SwiftUI
import SwiftData

/// v4-Tab „Prüfungen" — Übersicht aller bereits geprüften Abrechnungen.
///
/// Aufbau:
///   • SearchField über Adresse / Bezeichnung
///   • Liste der GespeicherteAbrechnung, sortiert nach Datum absteigend
///   • Status-Badge je Eintrag (grün: keine Fehler, amber: Ergebnisse gefunden)
///   • Swipe-to-Delete entfernt eine Abrechnung
///   • Leerer Zustand: dezenter Hinweis-Text mit Verweis auf Start-Tab
///
/// Tap → NavigationLink zu `PruefberichtDetailView`.
struct PruefungenListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \GespeicherteAbrechnung.pruefDatum, order: .reverse)
    private var alleAbrechnungen: [GespeicherteAbrechnung]

    @Query(sort: \Mietobjekt.erstelltAm, order: .reverse)
    private var mietobjekte: [Mietobjekt]

    @State private var suchText: String = ""

    var body: some View {
        Group {
            if alleAbrechnungen.isEmpty {
                leererZustand
            } else {
                liste
            }
        }
        .background(AppTheme.screenBg.ignoresSafeArea())
        .navigationTitle("Prüfungen")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $suchText, prompt: "Adresse oder Jahr suchen")
    }

    // MARK: - Liste

    private var liste: some View {
        List {
            ForEach(gefilterte, id: \.0.id) { paar in
                let (abrechnung, mietobjekt) = paar
                NavigationLink {
                    if let mietobjekt {
                        PruefberichtDetailView(abrechnung: abrechnung, mietobjekt: mietobjekt)
                    }
                } label: {
                    ZeileView(abrechnung: abrechnung, mietobjekt: mietobjekt)
                }
                .listRowBackground(AppTheme.cardBg)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(
                    top: AppSpacing.xs,
                    leading: AppSpacing.contentPadding,
                    bottom: AppSpacing.xs,
                    trailing: AppSpacing.contentPadding
                ))
            }
            .onDelete(perform: loesche)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppTheme.screenBg)
    }

    // MARK: - Leerer Zustand

    private var leererZustand: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.textTertiary)

            Text("Noch keine Prüfungen")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Starte deine erste Prüfung\nauf dem Start-Tab.")
                .font(AppTypography.body)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.xl)
    }

    // MARK: - Filter

    /// Liefert Paare (Abrechnung, optional Mietobjekt) — gefiltert nach Suchtext.
    private var gefilterte: [(GespeicherteAbrechnung, Mietobjekt?)] {
        let q = suchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let paare = alleAbrechnungen.map { abr -> (GespeicherteAbrechnung, Mietobjekt?) in
            let obj = mietobjekte.first(where: { $0.abrechnungen.contains(where: { $0.id == abr.id }) })
            return (abr, obj)
        }
        guard !q.isEmpty else { return paare }
        return paare.filter { paar in
            let (abr, obj) = paar
            if let obj {
                if obj.adresse.lowercased().contains(q) { return true }
                if let bez = obj.bezeichnung?.lowercased(), bez.contains(q) { return true }
            }
            // Jahr aus dem Prüfdatum für Filter
            let jahr = Calendar.current.component(.year, from: abr.pruefDatum)
            return String(jahr).contains(q)
        }
    }

    // MARK: - Löschen

    private func loesche(at offsets: IndexSet) {
        let ziele = offsets.compactMap { idx -> GespeicherteAbrechnung? in
            guard idx < gefilterte.count else { return nil }
            return gefilterte[idx].0
        }
        for ziel in ziele {
            // Aus dem Mietobjekt-Array entfernen, dann aus SwiftData löschen.
            if let mo = mietobjekte.first(where: { $0.abrechnungen.contains(where: { $0.id == ziel.id }) }) {
                mo.abrechnungen.removeAll(where: { $0.id == ziel.id })
            }
            modelContext.delete(ziel)
        }
        NKHaptic.warning()
    }
}

// MARK: - Zeilen-View

private struct ZeileView: View {
    let abrechnung: GespeicherteAbrechnung
    let mietobjekt: Mietobjekt?

    var body: some View {
        NKCard {
            HStack(alignment: .center, spacing: AppSpacing.md) {
                Image(systemName: "doc.text")
                    .font(.system(size: 22))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(headline)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)

                    Text(subline)
                        .font(AppTypography.hint)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: AppSpacing.sm)

                statusBadge
            }
        }
    }

    private var headline: String {
        if let bez = mietobjekt?.bezeichnung?.trimmingCharacters(in: .whitespaces), !bez.isEmpty {
            return bez
        }
        return mietobjekt?.adresse ?? "Abrechnung"
    }

    private var subline: String {
        let datum = abrechnung.pruefDatumFormatiert
        let anzahl = (abrechnung.ladeBericht()?.findings.count) ?? 0
        let label = anzahl == 1 ? "Ergebnis" : "Ergebnisse"
        return "\(datum) · \(anzahl) \(label)"
    }

    /// Grünes Badge bei null Findings („Alles OK"), amber bei mindestens einem.
    @ViewBuilder
    private var statusBadge: some View {
        let anzahl = (abrechnung.ladeBericht()?.findings.count) ?? 0
        if anzahl == 0 {
            NKBadge(text: "Alles OK", color: AppTheme.success)
        } else {
            NKBadge(text: "Fehler", color: AppTheme.warning)
        }
    }
}

#Preview {
    NavigationStack { PruefungenListView() }
        .modelContainer(for: [Mietobjekt.self, GespeicherteAbrechnung.self], inMemory: true)
}
