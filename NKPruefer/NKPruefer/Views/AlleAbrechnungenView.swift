import SwiftUI
import SwiftData

struct AlleAbrechnungenView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Mietobjekt.erstelltAm, order: .reverse)
    private var mietobjekte: [Mietobjekt]

    @State private var loeschKandidat: AbrechnungPaar? = nil

    private var paare: [AbrechnungPaar] {
        var liste: [AbrechnungPaar] = []
        for mietobjekt in mietobjekte {
            for abrechnung in mietobjekt.abrechnungen {
                liste.append(AbrechnungPaar(mietobjekt: mietobjekt, abrechnung: abrechnung))
            }
        }
        return liste.sorted { $0.abrechnung.pruefDatum > $1.abrechnung.pruefDatum }
    }

    var body: some View {
        Group {
            if paare.isEmpty {
                leererZustand
            } else {
                liste
            }
        }
        .navigationTitle("Alle Prüfungen")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "Wirklich löschen?",
            isPresented: Binding(
                get: { loeschKandidat != nil },
                set: { if !$0 { loeschKandidat = nil } }
            ),
            presenting: loeschKandidat
        ) { paar in
            Button("Löschen", role: .destructive) {
                loesche(paar)
            }
            Button("Abbrechen", role: .cancel) {
                loeschKandidat = nil
            }
        } message: { _ in
            Text("Diese Prüfung wird endgültig entfernt.")
        }
    }

    // MARK: - Empty State

    private var leererZustand: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(NKDesign.accentColor)

            Text("Noch keine Prüfungen durchgeführt.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            NavigationLink {
                PreCaptureView()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Erste Abrechnung prüfen")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: NKDesign.bigButtonHeight)
                .background(NKDesign.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: NKDesign.cornerRadius))
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: - Liste

    private var liste: some View {
        List {
            ForEach(paare) { paar in
                NavigationLink {
                    PruefberichtDetailView(
                        abrechnung: paar.abrechnung,
                        mietobjekt: paar.mietobjekt
                    )
                } label: {
                    AbrechnungHistorieCard(paar: paar)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        loeschKandidat = paar
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Actions

    private func loesche(_ paar: AbrechnungPaar) {
        if let idx = paar.mietobjekt.abrechnungen.firstIndex(where: { $0.id == paar.abrechnung.id }) {
            paar.mietobjekt.abrechnungen.remove(at: idx)
        }
        modelContext.delete(paar.abrechnung)
        loeschKandidat = nil
    }
}

// MARK: - Pair Wrapper

struct AbrechnungPaar: Identifiable, Hashable {
    let mietobjekt: Mietobjekt
    let abrechnung: GespeicherteAbrechnung

    var id: String { abrechnung.id }

    static func == (lhs: AbrechnungPaar, rhs: AbrechnungPaar) -> Bool {
        lhs.abrechnung.id == rhs.abrechnung.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(abrechnung.id)
    }
}

// MARK: - Historie Card

private struct AbrechnungHistorieCard: View {
    let paar: AbrechnungPaar

    private var abrechnung: GespeicherteAbrechnung { paar.abrechnung }
    private var mietobjekt: Mietobjekt { paar.mietobjekt }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(mietobjekt.adresse)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)

            Text("Geprüft am \(abrechnung.pruefDatumFormatiert)")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                if abrechnung.fehlerAnzahl > 0 {
                    HistorieBadge(
                        text: "\(abrechnung.fehlerAnzahl) \(abrechnung.fehlerAnzahl == 1 ? "Fehler" : "Fehler")",
                        farbe: NKDesign.errorColor
                    )
                }
                if abrechnung.warnungAnzahl > 0 {
                    HistorieBadge(
                        text: "\(abrechnung.warnungAnzahl) \(abrechnung.warnungAnzahl == 1 ? "Warnung" : "Warnungen")",
                        farbe: NKDesign.warningColor
                    )
                }
            }

            if abrechnung.ersparnis > 0 {
                Label("\(formatGeld(abrechnung.ersparnis)) gespart", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(NKDesign.successColor)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

private struct HistorieBadge: View {
    let text: String
    let farbe: Color

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(farbe)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(farbe.opacity(0.15))
            .clipShape(Capsule())
    }
}

#Preview {
    NavigationStack { AlleAbrechnungenView() }
        .modelContainer(for: [Mietobjekt.self, GespeicherteAbrechnung.self], inMemory: true)
}
