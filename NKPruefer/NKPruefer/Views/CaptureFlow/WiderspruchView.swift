import SwiftUI
import UIKit
import MessageUI

/// v4-Widerspruchs-Ansicht.
///
/// Aufbau:
///  1. Info-Box „Empfohlen: Per Einschreiben mit Rückschein versenden"
///  2. Widerspruchs-Brieftext in scrollbarer NKCard
///  3. „Text bearbeiten"-Button → Sheet mit TextEditor
///  4. Versand-Optionen:
///       • PDF herunterladen (NKPrimaryButton)
///       • Per Email senden  (NKSecondaryButton)
///       • Separator
///       • WhatsApp öffnen   (NKSecondaryButton)
///  5. Disclaimer
///
/// WICHTIG: Die WhatsApp-Sharing-Funktion `sendeWhatsApp(...)` enthält
/// einen Clipboard-Schutz (30s-Timer, willResignActive-Observer,
/// Identity-Checks, 35s-Cleanup). Diese letzten ~15 Zeilen MÜSSEN
/// unverändert erhalten bleiben.
struct WiderspruchView: View {
    let bericht: Pruefbericht
    let mietobjekt: Mietobjekt

    @EnvironmentObject var userProfile: UserProfile

    // Generierungs-State
    @State private var widerspruchOutput: WiderspruchOutput? = nil
    @State private var laeuft = false
    @State private var fehler: String? = nil
    @State private var datenGeprueft = false
    @State private var zeigeVermieterSheet = false

    // Edit-State
    /// Der aktuell angezeigte und editierbare Brief-Text. Wird beim
    /// Eintreffen des LLM-Outputs auf `email.brieftext` initialisiert
    /// und für alle Versand-Aktionen (PDF, Email) verwendet.
    @State private var bearbeiteterText: String = ""
    @State private var zeigeEditor: Bool = false

    // Versand-State
    @State private var zeigeMailCompose = false
    @State private var zeigeShareSheet = false
    @State private var sharePDFURL: URL? = nil
    @State private var kopiertToast = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    if let output = widerspruchOutput {
                        ergebnisAnsicht(output: output)
                    } else if let fehler {
                        fehlerAnsicht(text: fehler)
                    } else if laeuft {
                        ladeAnsicht
                    } else {
                        Color.clear.frame(height: 8)
                    }
                }
                .padding(.horizontal, AppSpacing.contentPadding)
                .padding(.vertical, AppSpacing.md)
            }

            if kopiertToast {
                kopiertToastView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, AppSpacing.xxl)
            }
        }
        .background(AppTheme.screenBg.ignoresSafeArea())
        .navigationTitle("Widerspruch")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(laeuft)
        .interactiveDismissDisabled(laeuft)
        .task {
            guard !datenGeprueft else { return }
            datenGeprueft = true
            if mietobjekt.kannWiderspruchErstellen {
                await starteGenerierung()
            } else {
                zeigeVermieterSheet = true
            }
        }
        .sheet(isPresented: $zeigeVermieterSheet) {
            VermieterDatenSheet(mietobjekt: mietobjekt) {
                Task { await starteGenerierung() }
            }
        }
        .sheet(isPresented: $zeigeEditor) {
            editorSheet
        }
        .sheet(isPresented: $zeigeMailCompose) {
            if let output = widerspruchOutput {
                MailComposeView(
                    recipients: [mietobjekt.vermieterEmail].compactMap { $0 },
                    subject: output.email.betreff,
                    body: bearbeiteterText,
                    attachment: pdfAttachment(for: output)
                ) { _, _ in
                    zeigeMailCompose = false
                }
                .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $zeigeShareSheet) {
            if let url = sharePDFURL {
                ShareSheet(activityItems: [url])
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: - Lade-Ansicht

    private var ladeAnsicht: some View {
        NKCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Dein Widerspruch wird erstellt …")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, AppSpacing.xs)
            }
        }
    }

    // MARK: - Ergebnis-Ansicht (v4)

    private func ergebnisAnsicht(output: WiderspruchOutput) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            fristCard
            fristErklaerung
            infoBox
            briefKarte
            textBearbeitenButton
            NKDisclaimerStrip()
            versandOptionen(output: output)
            disclaimer
        }
    }

    // v4-15: Erklärung unter der Frist-Card — räumt das Missverständnis aus,
    // dass nach 14 Tagen alles zu spät wäre. Die gesetzliche Frist ist
    // 12 Monate (§ 556 Abs. 3 S. 5 BGB).
    private var fristErklaerung: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: "info.circle")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.top, 2)
            Text("14 Tage sind unsere Empfehlung für eine schnelle Reaktion. Die gesetzliche Frist beträgt 12 Monate ab Zustellung (§ 556 Abs. 3 BGB).")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // 0. Frist-Card (Empfehlung: innerhalb 14 Tagen nach Prüfung handeln)
    //
    // Berechnung: 14 Tage ab `bericht.pruefDatum` (Näherung für das
    // Zustelldatum der Abrechnung). Farb-Codierung:
    //   • >7 Tage Rest: Accent-Blau (entspannt)
    //   • ≤7 Tage:      Warning-Amber (zeitnah handeln)
    //   • ≤3 Tage:      Error-Rot (dringend)

    private var fristCard: some View {
        let frist = Calendar.current.date(byAdding: .day, value: 14, to: bericht.pruefDatum) ?? bericht.pruefDatum
        let restTage = max(0, Calendar.current.dateComponents([.day], from: Date(), to: frist).day ?? 0)
        let farbe: Color = restTage <= 3 ? AppTheme.error
                         : restTage <= 7 ? AppTheme.warning
                         : AppTheme.accent
        let icon = restTage <= 7 ? "clock.badge.exclamationmark" : "clock"
        let datumStr = frist.formatted(.dateTime.day().month(.wide).year())

        return HStack(alignment: .center, spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(farbe)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("Empfohlene Frist")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                Text(restTage > 0 ? "Noch \(restTage) \(restTage == 1 ? "Tag" : "Tage")" : "Frist abgelaufen")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(farbe)
                Text("bis \(datumStr)")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(AppSpacing.md)
        .background(farbe.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(farbe.opacity(0.25), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Empfohlene Frist: Noch \(restTage) Tage, bis \(datumStr)")
    }

    // 1. Info-Box

    private var infoBox: some View {
        NKCard {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                Image(systemName: "info.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 24)
                Text("Empfohlen: Per Einschreiben mit Rückschein versenden")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // 2. Brieftext in scrollbarer Karte

    private var briefKarte: some View {
        NKCard {
            ScrollView {
                Text(bearbeiteterText)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxHeight: 320)
        }
    }

    // 3. „Text bearbeiten"-Button

    private var textBearbeitenButton: some View {
        NKSecondaryButton("Text bearbeiten", icon: "pencil") {
            zeigeEditor = true
        }
    }

    // 3b. Editor-Sheet

    private var editorSheet: some View {
        NavigationStack {
            TextEditor(text: $bearbeiteterText)
                .font(.system(size: 14))
                .padding(AppSpacing.md)
                .background(AppTheme.screenBg.ignoresSafeArea())
                .navigationTitle("Text bearbeiten")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig") {
                            zeigeEditor = false
                        }
                        .fontWeight(.semibold)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") {
                            // Verwirft die Änderungen — Original wiederherstellen.
                            if let originalText = widerspruchOutput?.email.brieftext {
                                bearbeiteterText = originalText
                            }
                            zeigeEditor = false
                        }
                    }
                }
        }
    }

    // 4. Versand-Optionen

    private func versandOptionen(output: WiderspruchOutput) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            // PDF herunterladen
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                NKPrimaryButton("PDF herunterladen", icon: "arrow.down.doc") {
                    teilePDF(output: output)
                }
                hinweisText("Für Einschreiben mit Rückschein")
            }

            // Per Email senden
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                NKSecondaryButton("Per Email senden", icon: "envelope") {
                    emailAktion(output: output)
                }
                hinweisText("Lesebestätigung anfordern")
            }

            // Separator + WhatsApp-Frage
            Divider()
                .padding(.vertical, AppSpacing.xs)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Vermieter zusätzlich per WhatsApp informieren?")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    NKSecondaryButton("WhatsApp öffnen", icon: "message") {
                        sendeWhatsApp(
                            nachricht: output.whatsapp.nachricht,
                            nummer: mietobjekt.vermieterWhatsApp
                        )
                    }
                    hinweisText("Nur als Hinweis, nicht als offizieller Widerspruch")
                }
            }
        }
    }

    private func hinweisText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    // 5. Disclaimer

    private var disclaimer: some View {
        Text("Automatisch erstellt — ersetzt keine Rechtsberatung.")
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, AppSpacing.sm)
    }

    // MARK: - Fehler-Ansicht

    private func fehlerAnsicht(text: String) -> some View {
        NKCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Label(text, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.error)
                    .fixedSize(horizontal: false, vertical: true)

                NKPrimaryButton("Nochmal versuchen", icon: "arrow.clockwise") {
                    Task { await starteGenerierung() }
                }
            }
        }
    }

    // MARK: - Toast (WhatsApp-Clipboard-Kopie)

    private var kopiertToastView: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
            Text("Text kopiert — füge ihn in WhatsApp ein.")
                .font(.system(size: 15, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .background(.black.opacity(0.85))
        .clipShape(Capsule())
    }

    // MARK: - Actions

    private func starteGenerierung() async {
        laeuft = true
        fehler = nil
        widerspruchOutput = nil

        do {
            let result = try await WiderspruchService.generiere(
                bericht: bericht,
                mietobjekt: mietobjekt,
                mieterName: userProfile.vollerName,
                mieterAdresse: userProfile.volleAdresse,
                mieterEmail: userProfile.email
            )
            widerspruchOutput = result
            bearbeiteterText = result.email.brieftext
            NKHaptic.success()
        } catch {
            fehler = error.localizedDescription
            NKHaptic.error()
        }
        laeuft = false
    }

    /// PDF herunterladen → Share-Sheet mit der PDF-Datei (für Einschreiben).
    /// Wir verwenden den ggf. editierten `bearbeiteterText` als Brieftext.
    private func teilePDF(output: WiderspruchOutput) {
        let aktuelleDaten = pdfDatenMitAktuellemText(output: output)
        let dateiname = "Widerspruch_Nebenkosten_\(safeDateiname(for: aktuelleDaten.datum))"
        sharePDFURL = PDFService.writeTempFile(from: aktuelleDaten, fileName: dateiname)
        zeigeShareSheet = sharePDFURL != nil
    }

    private func emailAktion(output: WiderspruchOutput) {
        if MFMailComposeViewController.canSendMail() {
            zeigeMailCompose = true
        } else {
            // Fallback: PDF teilen, wenn keine Email-Konfiguration vorhanden.
            teilePDF(output: output)
        }
    }

    /// WhatsApp-Sharing — entweder direkt per Deep-Link an die hinterlegte
    /// Vermieter-Nummer, oder Fallback per Clipboard.
    ///
    /// WICHTIG: Die letzten ~15 Zeilen dieser Funktion (ab `// Clipboard-Schutz`)
    /// implementieren den Schutz, der das Clipboard nach 30s wieder leert bzw.
    /// sofort beim App-Backgrounding. Diese Logik darf NICHT verändert oder
    /// gekürzt werden.
    private func sendeWhatsApp(nachricht: String, nummer: String?) {
        let kodiert = nachricht.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) ?? ""

        let bereinigteNummer = nummer?
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")

        if let n = bereinigteNummer, !n.isEmpty,
           let url = URL(string: "whatsapp://send?phone=\(n)&text=\(kodiert)"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            UIPasteboard.general.string = nachricht
            NKHaptic.success()
            withAnimation { kopiertToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation { kopiertToast = false }
            }
            // Clipboard-Schutz: Nachricht nach 30s wieder entfernen,
            // falls sie noch genau dieser Text ist.
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                if UIPasteboard.general.string == nachricht {
                    UIPasteboard.general.string = ""
                }
            }
            // Zusätzlich: Sofort clearen wenn die App in den Background geht
            // (z. B. der User wechselt zu WhatsApp und hat den Text dort eingefügt).
            let observer = NotificationCenter.default.addObserver(
                forName: UIApplication.willResignActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                if UIPasteboard.general.string == nachricht {
                    UIPasteboard.general.string = ""
                }
            }
            // Observer nach 35s entfernen (30s Timer + 5s Buffer).
            DispatchQueue.main.asyncAfter(deadline: .now() + 35) {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    // MARK: - Helpers

    /// Erzeugt eine PDFDaten-Kopie mit aktuellem (ggf. editiertem) Brieftext.
    private func pdfDatenMitAktuellemText(output: WiderspruchOutput) -> PDFDaten {
        PDFDaten(
            absenderName: output.pdfDaten.absenderName,
            absenderAdresse: output.pdfDaten.absenderAdresse,
            empfaengerName: output.pdfDaten.empfaengerName,
            empfaengerAdresse: output.pdfDaten.empfaengerAdresse,
            datum: output.pdfDaten.datum,
            betreff: output.pdfDaten.betreff,
            brieftext: bearbeiteterText,
            frist: output.pdfDaten.frist
        )
    }

    private func pdfAttachment(for output: WiderspruchOutput) -> MailComposeView.Attachment? {
        let data = PDFService.generate(from: pdfDatenMitAktuellemText(output: output))
        let dateiname = "Widerspruch_Nebenkosten_\(safeDateiname(for: output.pdfDaten.datum)).pdf"
        return MailComposeView.Attachment(
            data: data,
            mimeType: "application/pdf",
            fileName: dateiname
        )
    }

    private func safeDateiname(for s: String) -> String {
        s.replacingOccurrences(of: ".", with: "-")
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
    }
}

// MARK: - MailComposeView (UIKit-Bridge)

struct MailComposeView: UIViewControllerRepresentable {
    struct Attachment {
        let data: Data
        let mimeType: String
        let fileName: String
    }

    let recipients: [String]?
    let subject: String
    let body: String
    let attachment: Attachment?
    let onResult: (MFMailComposeResult, Error?) -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        if let recipients, !recipients.isEmpty {
            composer.setToRecipients(recipients)
        }
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        if let att = attachment {
            composer.addAttachmentData(att.data, mimeType: att.mimeType, fileName: att.fileName)
        }
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposeView
        init(parent: MailComposeView) { self.parent = parent }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            controller.dismiss(animated: true) {
                self.parent.onResult(result, error)
            }
        }
    }
}

// MARK: - ShareSheet (UIKit-Bridge)

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
