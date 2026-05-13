import SwiftUI

/// v4-Hilfe-Tab.
///
/// Aufbau:
///  • NKHeader „Hilfe"
///  • Suchfeld (debounced, 300 ms)
///  • Artikel-Liste, gruppiert nach Sektion
///
/// Alle Inhalte werden lokal aus `HilfeKatalog` gezogen — kein
/// Netzwerk-Request. Die Suche prüft case-insensitive über Titel
/// und Keywords.
struct HilfeView: View {
    @State private var suchText: String = ""
    /// Der tatsächlich für das Filtern verwendete Text — wird mit 300 ms
    /// Debounce aus `suchText` übernommen, damit jeder Tastendruck nicht
    /// sofort die Liste neu aufbaut.
    @State private var debouncedSuchText: String = ""

    /// Eindeutige Task-Identity für den letzten Debounce-Lauf — wird beim
    /// erneuten Tippen neu vergeben, sodass der vorhergehende Task per
    /// `Task.checkCancellation` rausfliegt.
    @State private var debounceTaskID: UUID = UUID()

    var body: some View {
        VStack(spacing: 0) {
            NKHeader(title: "Hilfe")
            Divider()

            VStack(spacing: 0) {
                searchField
                    .padding(.horizontal, AppSpacing.contentPadding)
                    .padding(.vertical, AppSpacing.sm)

                artikelListe
            }
        }
        .background(AppTheme.screenBg.ignoresSafeArea())
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: suchText) { _, _ in
            entprelle()
        }
    }

    // MARK: - Suchfeld

    private var searchField: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.textSecondary)
            TextField("Hilfe durchsuchen", text: $suchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !suchText.isEmpty {
                Button {
                    suchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .accessibilityLabel("Suche leeren")
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 10)
        .background(AppTheme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                .stroke(AppTheme.border, lineWidth: 0.5)
        )
    }

    // MARK: - Artikel-Liste

    private var artikelListe: some View {
        List {
            ForEach(HilfeKatalog.sektionen, id: \.self) { section in
                let artikelInSektion = gefilterte.filter { $0.section == section }
                if !artikelInSektion.isEmpty {
                    Section {
                        ForEach(artikelInSektion) { artikel in
                            NavigationLink {
                                HilfeDetailView(artikel: artikel)
                            } label: {
                                Text(artikel.titel)
                                    .font(.system(size: 15))
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                        }
                    } header: {
                        Text(section)
                    }
                }
            }

            if gefilterte.isEmpty {
                Section {
                    leereSuche
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.screenBg)
    }

    private var leereSuche: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22))
                .foregroundStyle(AppTheme.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Keine Treffer")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Versuche ein anderes Stichwort.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(.vertical, AppSpacing.xs)
    }

    // MARK: - Filter-Logik

    private var gefilterte: [HilfeArtikel] {
        let q = debouncedSuchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return HilfeKatalog.alle }
        return HilfeKatalog.alle.filter { $0.passtZu(suchText: q) }
    }

    // MARK: - Debounce

    private func entprelle() {
        let id = UUID()
        debounceTaskID = id
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000) // 300 ms
            // Wenn zwischenzeitlich ein neuer Tipper gekommen ist,
            // hat sich `debounceTaskID` geändert — Update verwerfen.
            guard debounceTaskID == id else { return }
            debouncedSuchText = suchText
        }
    }
}

#Preview {
    NavigationStack { HilfeView() }
}
