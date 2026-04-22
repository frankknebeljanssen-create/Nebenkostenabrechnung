//
//  PDFVorschauSheet.swift
//  NebenkostenApp — UI/Abrechnungen
//
//  UI-2-Integration fuer den PDF-Export aus der `AbrechnungDetailView`.
//  Bekommt eine `Mieterabrechnung` plus den noetigen Kontext
//  (Immobilie, Periode, optionaler Vermieter-User), erzeugt das PDF
//  asynchron per `PDFGenerator`, schreibt es in ein temporaeres File
//  und zeigt die PDFKit-Vorschau mit ShareLink oben rechts.
//
//  Drei Zustaende: `laedt` (ProgressView), `bereit(url)` (Vorschau +
//  Share), `fehler(text)` (Alert-artige Platzhalter-Seite).
//

import SwiftUI

struct PDFVorschauSheet: View {
    let abrechnung: Mieterabrechnung
    let immobilie: Immobilie
    let periode: Abrechnungsperiode
    let user: AppUser?

    @Environment(\.dismiss) private var dismiss
    @State private var zustand: Zustand = .laedt

    enum Zustand {
        case laedt
        case bereit(URL)
        case fehler(String)
    }

    var body: some View {
        NavigationStack {
            inhalt
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DesignTokens.bgApp)
                .navigationTitle("PDF-Vorschau")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Schließen") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        if case .bereit(let url) = zustand {
                            ShareLink(item: url) {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                    }
                }
        }
        .task { await generiere() }
    }

    @ViewBuilder
    private var inhalt: some View {
        switch zustand {
        case .laedt:
            ladeIndikator
        case .bereit(let url):
            PDFVorschauView(url: url)
                .ignoresSafeArea(edges: .bottom)
        case .fehler(let text):
            fehlerAnsicht(text)
        }
    }

    private var ladeIndikator: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("PDF wird erzeugt …")
                .appFont(AppFont.Basis.body())
                .foregroundStyle(DesignTokens.textSecondary)
        }
    }

    private func fehlerAnsicht(_ text: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(DesignTokens.textSecondary)
            Text("PDF-Fehler")
                .appFont(AppFont.Basis.bodySemi())
            Text(text)
                .appFont(AppFont.Basis.body())
                .foregroundStyle(DesignTokens.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    // MARK: - Generierung

    @MainActor
    private func generiere() async {
        // Wenn schon bereit, nicht neu rendern (Sheet kann gelegentlich
        // seine `.task` mehrfach ausfuehren).
        if case .bereit = zustand { return }

        let kontext = PDFAbrechnungsKontext.baue(
            abrechnung: abrechnung,
            immobilie: immobilie,
            user: user,
            periode: periode
        )
        let dateiname = PDFAbrechnungsKontext.vorschlagDateiname(
            abrechnung: abrechnung,
            periode: periode
        )
        do {
            let data = try await PDFGenerator.generiereAbrechnungsPDF(
                context: kontext
            )
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(dateiname)
            try data.write(to: url, options: .atomic)
            zustand = .bereit(url)
        } catch {
            zustand = .fehler(error.localizedDescription)
        }
    }
}
