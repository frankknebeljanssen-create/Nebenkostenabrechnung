import SwiftUI
import SwiftData
import UIKit

struct EckdatenQuickView: View {
    var pruefungsAuftrag: PruefungsAuftrag? = nil

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Mietobjekt.erstelltAm, order: .reverse)
    private var mietobjekte: [Mietobjekt]

    // Mode A — neuer User
    @State private var adresse = ""
    @State private var flaecheQm: Decimal? = nil
    @State private var personenzahl = 1

    @State private var adresseHasError = false
    @State private var flaecheHasError = false

    // Force Mode A obwohl bereits Mietobjekt existiert (über "Andere Wohnung?")
    @State private var forceNeueWohnung = false

    // v4-19 Fix 2: Optionaler OCR-Review-Sheet
    @State private var zeigeOCRReview = false

    // Navigation zum (Platzhalter-)Analyse-Screen
    @State private var navigiereZurAnalyse: Mietobjekt? = nil

    private var bestehendesObjekt: Mietobjekt? {
        forceNeueWohnung ? nil : mietobjekte.first
    }

    var body: some View {
        Group {
            if let obj = bestehendesObjekt {
                modeBView(mietobjekt: obj)
            } else {
                modeAView
            }
        }
        .navigationTitle("Eckdaten")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $navigiereZurAnalyse) { obj in
            AnalyseView(auftrag: pruefungsAuftrag ?? makeFallbackAuftrag(mietobjekt: obj))
        }
        // v4-19 Fix 2: optionaler OCR-Review-Sheet
        .sheet(isPresented: $zeigeOCRReview) {
            if let auftrag = pruefungsAuftrag {
                NavigationStack {
                    OCRReviewView(auftrag: auftrag)
                }
            }
        }
    }

    // MARK: - OCR-Review-Trigger

    /// Card mit Link zum OCR-Review-Sheet. Erscheint nur, wenn der
    /// `pruefungsAuftrag` einen OCR-Text trägt — bei Mode-B (bestehende
    /// Wohnung ohne Capture-Flow) gibt es nichts zu prüfen.
    @ViewBuilder
    private var ocrReviewLink: some View {
        if let auftrag = pruefungsAuftrag,
           !auftrag.ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Button {
                zeigeOCRReview = true
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.accent)
                    Text("Erkannten Text prüfen")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.accent)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.accent.opacity(0.6))
                }
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                        .stroke(AppTheme.border, lineWidth: 0.5)
                )
            }
            .accessibilityLabel("Erkannten Text der Abrechnung prüfen")
        }
    }

    // MARK: - Mode A: Neuer User

    private var modeAView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Fast geschafft!")
                        .font(.system(size: 24, weight: .semibold))
                    Text("Noch ein paar Angaben zu deiner Wohnung.")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ocrReviewLink

                NKTextField(
                    label: "Adresse",
                    placeholder: "Musterstr. 12, 12345 Berlin",
                    text: $adresse,
                    helperText: "Straße und Hausnummer, PLZ und Ort",
                    textContentType: .fullStreetAddress,
                    isRequired: true,
                    hasError: adresseHasError,
                    errorText: "Bitte gib deine Adresse an."
                )

                // v4-19 Fix 6d: Wohnfläche jetzt optional — leer lassen
                // erlaubt, aber ein dezenter Warnhinweis erscheint.
                NKDecimalField(
                    label: "Wohnfläche",
                    unit: "m²",
                    placeholder: "68,5",
                    value: $flaecheQm,
                    helperText: "Steht im Mietvertrag. Optional — ohne Wohnfläche können flächenbezogene Kosten nicht geprüft werden.",
                    isRequired: false,
                    hasError: false,
                    errorText: ""
                )

                if (flaecheQm ?? 0) <= 0 {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.warning)
                        Text("Ohne Wohnfläche können flächenbezogene Kosten nicht geprüft werden.")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Personen im Haushalt")
                        .font(.system(size: 15, weight: .semibold))
                    NKPersonenStepper(value: $personenzahl)
                }

                NKInfoBox(text: "Das brauchen wir, um deinen Anteil zu berechnen.")

                NKBigButton(title: "Prüfung starten", icon: "checkmark", style: .success) {
                    starteMitNeuerWohnung()
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Mode B: Bestehender User

    private func modeBView(mietobjekt: Mietobjekt) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Ist das deine Wohnung?")
                .font(.system(size: 24, weight: .semibold))
                .padding(.top, 8)

            ocrReviewLink

            BestehendeWohnungCard(mietobjekt: mietobjekt)

            NKBigButton(title: "Ja, Prüfung starten", icon: "checkmark", style: .success) {
                starteMitBestehender(mietobjekt)
            }

            NKTextButton(title: "Andere Wohnung? →") {
                withAnimation { forceNeueWohnung = true }
            }

            Spacer()
        }
        .padding(20)
    }

    // MARK: - Actions

    private func starteMitBestehender(_ mietobjekt: Mietobjekt) {
        pruefungsAuftrag?.mietobjekt = mietobjekt
        NKHaptic.success()
        navigiereZurAnalyse = mietobjekt
    }

    private func starteMitNeuerWohnung() {
        let trimmedAdresse = adresse.trimmingCharacters(in: .whitespacesAndNewlines)
        adresseHasError = trimmedAdresse.isEmpty
        // v4-19 Fix 6d: Wohnfläche ist optional. Kein Validation-Error
        // mehr — bei fehlender Fläche speichern wir 0; Calculator und
        // Plausibilitäts-Checks springen flächenabhängige Posten dann
        // per `if let`-Guards sauber drüber weg.
        flaecheHasError = false

        guard !adresseHasError else {
            NKHaptic.error()
            return
        }

        let flaeche = flaecheQm ?? 0
        let neu = Mietobjekt(
            adresse: trimmedAdresse,
            flaecheQm: flaeche,
            personenzahl: personenzahl
        )
        modelContext.insert(neu)

        pruefungsAuftrag?.mietobjekt = neu
        NKHaptic.success()
        navigiereZurAnalyse = neu
    }

    private func makeFallbackAuftrag(mietobjekt: Mietobjekt) -> PruefungsAuftrag {
        let auftrag = PruefungsAuftrag()
        auftrag.mietobjekt = mietobjekt
        return auftrag
    }
}

// MARK: - Bestehende-Wohnung-Karte

private struct BestehendeWohnungCard: View {
    let mietobjekt: Mietobjekt

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(mietobjekt.adresse)
                .font(.system(size: 18, weight: .semibold))

            if let bez = mietobjekt.bezeichnung, !bez.isEmpty {
                Text(bez)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }

            Text("\(formatFlaeche(mietobjekt.flaecheQm)) m² · \(mietobjekt.personenzahl) \(mietobjekt.personenzahl == 1 ? "Person" : "Personen")")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.gray.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: NKDesign.cornerRadius))
    }

    private func formatFlaeche(_ wert: Decimal) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 2
        nf.locale = Locale(identifier: "de_DE")
        return nf.string(from: wert as NSDecimalNumber) ?? "—"
    }
}

#Preview {
    NavigationStack { EckdatenQuickView() }
        .modelContainer(for: [Mietobjekt.self, GespeicherteAbrechnung.self], inMemory: true)
}
