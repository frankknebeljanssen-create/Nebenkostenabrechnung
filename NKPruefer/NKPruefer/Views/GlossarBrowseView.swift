import SwiftUI

/// v4-19 Fix 3: Durchsuchbare Vollansicht aller Glossar-Begriffe.
/// Wird aus dem Hilfe-Tab aufgerufen. Tap auf einen Eintrag öffnet
/// den bestehenden `NKGlossarSheet` mit der Erklärung.
struct GlossarBrowseView: View {
    @State private var suchtext: String = ""
    @State private var ausgewaehlterEintrag: GlossarEintrag? = nil

    /// Gruppen für die List: bei leerer Suche alle Kategorien,
    /// bei aktiver Suche nur Kategorien mit Treffern.
    private var gefilterteGruppen: [(kategorie: GlossarKategorie, eintraege: [GlossarEintrag])] {
        let q = suchtext.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            return NKGlossary.nachKategorie
        }
        let treffer = NKGlossary.suche(q)
        return GlossarKategorie.allCases.compactMap { kat in
            let inKat = treffer.filter { $0.kategorie == kat }
            return inKat.isEmpty ? nil : (kategorie: kat, eintraege: inKat)
        }
    }

    var body: some View {
        List {
            if gefilterteGruppen.isEmpty {
                Section {
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 22))
                            .foregroundStyle(AppTheme.textTertiary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Keine Treffer")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Versuche ein anderes Stichwort.")
                                .font(AppTypography.body)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, AppSpacing.xs)
                }
            } else {
                ForEach(gefilterteGruppen, id: \.kategorie) { gruppe in
                    Section(gruppe.kategorie.rawValue) {
                        ForEach(gruppe.eintraege) { eintrag in
                            Button {
                                ausgewaehlterEintrag = eintrag
                            } label: {
                                HStack {
                                    Text(eintrag.begriff)
                                        .font(.system(size: 14))
                                        .foregroundStyle(AppTheme.textPrimary)
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(AppTheme.textTertiary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.screenBg)
        .searchable(text: $suchtext, prompt: "Begriff suchen")
        .navigationTitle("Begriffe nachschlagen")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $ausgewaehlterEintrag) { eintrag in
            NKGlossarSheet(eintrag: eintrag)
        }
    }
}

#Preview {
    NavigationStack { GlossarBrowseView() }
}
