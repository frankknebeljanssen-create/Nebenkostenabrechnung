//
//  AbrechnungsMailSheet.swift
//  NebenkostenApp — UI/Abrechnungen
//
//  Erzeugt die Abrechnung asynchron als PDF, baut daraus einen
//  `MailInhalt` mit Anlage + vorgegebenem Empfaenger-/Betreff-Text
//  und uebergibt ihn an `MailComposer`. Der User sieht nur die
//  bereits vorausgefuellte Compose-Maske und schickt sie ab.
//
//  Gleiches Zustandsmodell wie `PDFVorschauSheet`: `.laedt` zeigt
//  einen Spinner, `.bereit(MailInhalt)` rendert den Composer,
//  `.fehler(text)` einen Hinweis mit OK-Button.
//

import SwiftUI
import MessageUI

struct AbrechnungsMailSheet: View {
    let abrechnung: Mieterabrechnung
    let immobilie: Immobilie
    let periode: Abrechnungsperiode
    let user: AppUser?

    @Environment(\.dismiss) private var dismiss
    @State private var zustand: Zustand = .laedt

    enum Zustand {
        case laedt
        case bereit(MailInhalt)
        case fehler(String)
    }

    var body: some View {
        switch zustand {
        case .laedt:
            NavigationStack {
                ladeIndikator
                    .navigationTitle("Abrechnung per Mail")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Abbrechen") { dismiss() }
                        }
                    }
            }
            .task { await generiere() }

        case .bereit(let inhalt):
            // MailComposer uebernimmt die ganze Sheet-Flaeche. Der
            // Coordinator schliesst bei .sent/.saved/.cancelled den
            // Composer; wir schliessen das umschliessende Sheet
            // anschliessend auch, damit der User direkt zurueck in
            // der Detail-Ansicht landet.
            MailComposer(inhalt: inhalt) { _, _ in
                dismiss()
            }
            .ignoresSafeArea()

        case .fehler(let text):
            NavigationStack {
                fehlerAnsicht(text)
                    .navigationTitle("Mail-Fehler")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Schließen") { dismiss() }
                        }
                    }
            }
        }
    }

    private var ladeIndikator: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("PDF wird für den Versand erzeugt …")
                .appFont(AppFont.Basis.body())
                .foregroundStyle(DesignTokens.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func fehlerAnsicht(_ text: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(DesignTokens.textSecondary)
            Text(text)
                .appFont(AppFont.Basis.body())
                .foregroundStyle(DesignTokens.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Generierung

    @MainActor
    private func generiere() async {
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
            let anlage = MailAnlage(
                data: data,
                mimeType: "application/pdf",
                dateiname: dateiname
            )
            zustand = .bereit(baueMailInhalt(anlage: anlage))
        } catch {
            zustand = .fehler(error.localizedDescription)
        }
    }

    private func baueMailInhalt(anlage: MailAnlage) -> MailInhalt {
        let empfaenger = abrechnung.mieterEmail
            .trimmingCharacters(in: .whitespaces)
        let zeitraum = Formatting.periode(periode.von, periode.bis)
        let betreff = "Nebenkostenabrechnung \(zeitraum)"
        let anrede = abrechnung.mieterName.isEmpty
            ? "Sehr geehrte Damen und Herren,"
            : "Sehr geehrte/r \(abrechnung.mieterName),"
        let absender = user?.name ?? ""
        let absenderZeile = absender.isEmpty ? "" : "\n\nMit freundlichen Grüßen\n\(absender)"
        let nachricht = """
        \(anrede)

        anbei erhalten Sie Ihre Nebenkostenabrechnung für den Zeitraum \(zeitraum).
        Bitte prüfen Sie das beigefügte PDF.\(absenderZeile)
        """
        return MailInhalt(
            empfaenger: empfaenger.isEmpty ? [] : [empfaenger],
            betreff: betreff,
            nachricht: nachricht,
            anlagen: [anlage]
        )
    }
}
