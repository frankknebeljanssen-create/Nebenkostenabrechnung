import SwiftUI
import SwiftData

struct MietobjektListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Mietobjekt.erstelltAm, order: .reverse)
    private var mietobjekte: [Mietobjekt]

    @State private var zeigeNeuesSheet = false
    @State private var loeschKandidat: Mietobjekt? = nil

    var body: some View {
        NavigationStack {
            Group {
                if mietobjekte.isEmpty {
                    leererZustand
                } else {
                    liste
                }
            }
            .navigationTitle("Meine Wohnungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !mietobjekte.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            zeigeNeuesSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .imageScale(.large)
                        }
                        .accessibilityLabel("Wohnung hinzufügen")
                    }
                }
            }
            .sheet(isPresented: $zeigeNeuesSheet) {
                MietobjektEditView()
            }
            .alert(
                "Wirklich löschen?",
                isPresented: Binding(
                    get: { loeschKandidat != nil },
                    set: { if !$0 { loeschKandidat = nil } }
                ),
                presenting: loeschKandidat
            ) { objekt in
                Button("Löschen", role: .destructive) {
                    loescheObjekt(objekt)
                }
                Button("Abbrechen", role: .cancel) {
                    loeschKandidat = nil
                }
            } message: { _ in
                Text("Alle Abrechnungen dieser Wohnung werden ebenfalls gelöscht.")
            }
        }
    }

    // MARK: - States

    private var leererZustand: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "house.fill")
                .font(.system(size: 72))
                .foregroundStyle(NKDesign.accentColor)
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text("Noch keine Wohnung angelegt")
                    .font(NKDesign.headlineFont)
                    .multilineTextAlignment(.center)
                Text("Leg los — es dauert nur eine Minute!")
                    .font(NKDesign.bodyFont)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            NKBigButton(title: "Erste Wohnung anlegen", icon: "plus") {
                zeigeNeuesSheet = true
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private var liste: some View {
        List {
            ForEach(mietobjekte) { objekt in
                NavigationLink {
                    MietobjektDetailPlaceholderView(mietobjekt: objekt)
                } label: {
                    MietobjektCard(mietobjekt: objekt)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        loeschKandidat = objekt
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Actions

    private func loescheObjekt(_ objekt: Mietobjekt) {
        modelContext.delete(objekt)
        loeschKandidat = nil
    }
}

// MARK: - Card

private struct MietobjektCard: View {
    let mietobjekt: Mietobjekt

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(mietobjekt.adresse)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)

            if let bez = mietobjekt.bezeichnung, !bez.isEmpty {
                Text(bez)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Label(flaecheText, systemImage: "ruler")
                Label(abrechnungenText, systemImage: "doc.text")
            }
            .font(.system(size: 13))
            .foregroundStyle(.secondary)

            if let ersparnis = mietobjekt.letzteErsparnis, ersparnis > 0 {
                Label("Letzte Ersparnis: \(Self.geld(ersparnis))", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NKDesign.successColor)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var flaecheText: String {
        "\(Self.flaeche(mietobjekt.flaecheQm)) m²"
    }

    private var abrechnungenText: String {
        let n = mietobjekt.abrechnungen.count
        return n == 1 ? "1 Abrechnung" : "\(n) Abrechnungen"
    }

    private static func flaeche(_ wert: Decimal) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 2
        nf.locale = Locale(identifier: "de_DE")
        return nf.string(from: wert as NSDecimalNumber) ?? "—"
    }

    private static func geld(_ wert: Decimal) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = "EUR"
        nf.locale = Locale(identifier: "de_DE")
        return nf.string(from: wert as NSDecimalNumber) ?? "—"
    }
}

// MARK: - Placeholder Detail

private struct MietobjektDetailPlaceholderView: View {
    let mietobjekt: Mietobjekt
    @State private var zeigeBearbeiten = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "house")
                .font(.system(size: 48))
                .foregroundStyle(NKDesign.accentColor)
            Text(mietobjekt.adresse)
                .font(NKDesign.headlineFont)
                .multilineTextAlignment(.center)
            if let bez = mietobjekt.bezeichnung, !bez.isEmpty {
                Text(bez)
                    .font(NKDesign.bodyFont)
                    .foregroundStyle(.secondary)
            }
            Text("Detailansicht folgt in einem späteren Schritt.")
                .font(NKDesign.captionFont)
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Wohnung")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Bearbeiten") { zeigeBearbeiten = true }
            }
        }
        .sheet(isPresented: $zeigeBearbeiten) {
            MietobjektEditView(bestehendesObjekt: mietobjekt)
        }
    }
}

#Preview {
    MietobjektListView()
        .modelContainer(for: [Mietobjekt.self, GespeicherteAbrechnung.self], inMemory: true)
}
