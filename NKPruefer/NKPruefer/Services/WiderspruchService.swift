import Foundation

struct WiderspruchService {

    enum WiderspruchError: LocalizedError {
        case decodingFailed(String)

        var errorDescription: String? {
            switch self {
            case .decodingFailed(let msg):
                return "Widerspruch konnte nicht erstellt werden: \(msg)"
            }
        }
    }

    // MARK: - Public Entry

    static func generiere(
        bericht: Pruefbericht,
        mietobjekt: Mietobjekt,
        mieterName: String,
        mieterAdresse: String,
        mieterEmail: String
    ) async throws -> WiderspruchOutput {
        // Nur Findings mit konfidenz != .unsicher → "bestätigt"
        let bestaetigt = bericht.findings.filter { $0.konfidenz != .unsicher }

        // Frist: 14 Tage ab heute (für Forderungssatz im Brieftext und PDF)
        let frist = Calendar.current.date(byAdding: .day, value: 14, to: Date())!
        let fristText = frist.formatted(.dateTime.day().month(.wide).year())

        // Forderungs-Summe (alle bestätigten Differenzen > 0)
        let summe = bestaetigt
            .filter { $0.differenz > 0 }
            .reduce(Decimal(0)) { $0 + $1.differenz }
        let summeNF = NumberFormatter()
        summeNF.numberStyle = .decimal
        summeNF.minimumFractionDigits = 2
        summeNF.maximumFractionDigits = 2
        summeNF.locale = Locale(identifier: "de_DE")
        let summeStr = summeNF.string(from: summe as NSDecimalNumber) ?? "0,00"

        let forderungsSatz = """
        Ich fordere Sie auf, den Betrag von \(summeStr) Euro bis zum \(fristText) zu erstatten bzw. in der nächsten Abrechnung zu berücksichtigen.
        """

        // Email + WhatsApp parallel generieren — Forderungssatz wird dem
        // Berichterstatter als Pflicht-Baustein mitgegeben.
        async let emailResult = generiereEmail(
            findings: bestaetigt,
            bericht: bericht,
            mietobjekt: mietobjekt,
            mieterName: mieterName,
            mieterAdresse: mieterAdresse,
            mieterEmail: mieterEmail,
            forderungsSatz: forderungsSatz,
            fristText: fristText
        )
        async let whatsappResult = generiereWhatsApp(
            findings: bestaetigt,
            bericht: bericht,
            mietobjekt: mietobjekt,
            mieterName: mieterName
        )

        var email = try await emailResult
        let whatsapp = try await whatsappResult

        // Sicherheits-Netz: falls der LLM den Forderungssatz nicht
        // wörtlich übernommen hat, fügen wir ihn deterministisch vor
        // dem Schlussgruß ein.
        email = mitForderungsSatz(email, satz: forderungsSatz)

        let df = DateFormatter()
        df.dateFormat = "dd.MM.yyyy"
        df.locale = Locale(identifier: "de_DE")

        let pdfDaten = PDFDaten(
            absenderName: mieterName,
            absenderAdresse: mieterAdresse.isEmpty ? mietobjekt.adresse : mieterAdresse,
            empfaengerName: mietobjekt.vermieterName ?? "",
            empfaengerAdresse: mietobjekt.vermieterAdresse ?? "",
            datum: df.string(from: Date()),
            betreff: email.betreff,
            brieftext: email.brieftext,
            frist: fristText
        )

        return WiderspruchOutput(
            email: email,
            whatsapp: whatsapp,
            pdfDaten: pdfDaten
        )
    }

    // MARK: - Deterministisches Einfügen der Pflicht-Bausteine

    /// Pflicht-Baustein: Belegeinsichtsrecht nach § 259 BGB. Wird IMMER mit
    /// in den Widerspruchs-Brief eingesetzt (v4-15) — das ist ein starker
    /// Hebel den Mietervereine empfehlen.
    private static let belegeinsichtSatz = """
    Darüber hinaus mache ich von meinem Recht auf Belegeinsicht gemäß § 259 BGB Gebrauch und bitte um Einsichtnahme in die der Abrechnung zugrunde liegenden Belege und Rechnungen. Bitte teilen Sie mir einen Termin zur Belegeinsicht mit.
    """

    private static func mitForderungsSatz(_ email: EmailOutput, satz: String) -> EmailOutput {
        func ergaenze(_ text: String) -> String {
            var ergebnis = text

            // 1) Forderungssatz: nur wenn nicht schon enthalten.
            let normalized = ergebnis.replacingOccurrences(of: "\n", with: " ")
            if !normalized.contains("zu erstatten bzw. in der nächsten Abrechnung") {
                if let range = ergebnis.range(of: "Mit freundlichen Grüßen") {
                    ergebnis = ergebnis.replacingCharacters(
                        in: range.lowerBound..<range.lowerBound,
                        with: satz + "\n\n"
                    )
                } else {
                    ergebnis = ergebnis + "\n\n" + satz
                }
            }

            // 2) Belegeinsicht-Satz (§ 259 BGB) — Pflicht-Baustein v4-15.
            //    Idempotenter Check, dann VOR dem Schlussgruß einfügen.
            let normalized2 = ergebnis.replacingOccurrences(of: "\n", with: " ")
            if !normalized2.contains("§ 259 BGB")
                && !normalized2.contains("Belegeinsicht") {
                if let range = ergebnis.range(of: "Mit freundlichen Grüßen") {
                    ergebnis = ergebnis.replacingCharacters(
                        in: range.lowerBound..<range.lowerBound,
                        with: belegeinsichtSatz + "\n\n"
                    )
                } else {
                    ergebnis = ergebnis + "\n\n" + belegeinsichtSatz
                }
            }

            return ergebnis
        }
        return EmailOutput(
            betreff: email.betreff,
            brieftext: ergaenze(email.brieftext),
            emailBody: ergaenze(email.emailBody)
        )
    }

    // MARK: - Email Generator

    private static func generiereEmail(
        findings: [Finding],
        bericht: Pruefbericht,
        mietobjekt: Mietobjekt,
        mieterName: String,
        mieterAdresse: String,
        mieterEmail: String,
        forderungsSatz: String,
        fristText: String
    ) async throws -> EmailOutput {
        let systemPrompt = """
        Du bist ein verständlicher Erklärer für Nebenkostenthemen.
        Du schreibst formelle, aber verständliche Briefe für Mieter.

        REGELN:
        - Formeller Brief (Sie-Form an den Vermieter)
        - Absender und Empfänger im Briefkopf-Format
        - Datum rechtsbündig
        - Betreffzeile
        - Nenne zu JEDEM Fehler: konkreten Betrag und Rechtsgrundlage
        - Fordere eine korrigierte Abrechnung
        - Setze eine Frist von 14 Tagen ab Briefdatum (Frist-Datum wird im
          User-Prompt mitgegeben — verwende es WÖRTLICH)
        - Baue den vorgegebenen FORDERUNGSSATZ WÖRTLICH ein (vor dem Schlussgruß)
        - Erwähne, dass bei Nichtreaktion rechtliche Beratung eingeholt wird
        - Höflich aber bestimmt
        - "Sehr geehrte Damen und Herren" als Anrede
        - "Mit freundlichen Grüßen" + Mieter-Name am Ende

        AUSGABE-FORMAT (JSON):
        {
          "betreff": "Widerspruch gegen Nebenkostenabrechnung ...",
          "brieftext": "Vollständiger Brieftext mit Absender, Empfänger, Datum...",
          "email_body": "Nur der Briefinhalt ohne Briefkopf-Formatierung"
        }
        """

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let findingsData = (try? encoder.encode(findings)) ?? Data()
        let findingsStr = String(data: findingsData, encoding: .utf8) ?? "[]"

        let ersparnis = findings
            .filter { $0.differenz > 0 }
            .reduce(Decimal(0)) { $0 + $1.differenz }

        let df = DateFormatter()
        df.dateFormat = "dd.MM.yyyy"
        df.locale = Locale(identifier: "de_DE")

        let zeitraumStr = "\(df.string(from: bericht.abrechnung.meta.zeitraum.von)) – \(df.string(from: bericht.abrechnung.meta.zeitraum.bis))"

        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = "EUR"
        nf.locale = Locale(identifier: "de_DE")
        let ersparnisStr = nf.string(from: ersparnis as NSDecimalNumber) ?? "0 €"
        let nachzahlungStr: String
        if let betrag = bericht.abrechnung.meta.nachzahlungOderGuthaben {
            nachzahlungStr = nf.string(from: betrag as NSDecimalNumber) ?? "0 €"
        } else {
            nachzahlungStr = "(nicht ausgewiesen)"
        }

        let flaecheNF = NumberFormatter()
        flaecheNF.numberStyle = .decimal
        flaecheNF.maximumFractionDigits = 2
        flaecheNF.locale = Locale(identifier: "de_DE")
        let flaecheStr = flaecheNF.string(from: mietobjekt.flaecheQm as NSDecimalNumber) ?? "—"

        let userMessage = """
        Erstelle ein Widerspruchsschreiben.

        VERMIETER: \(mietobjekt.vermieterName ?? "Unbekannt"), \(mietobjekt.vermieterAdresse ?? "")
        MIETER: \(mieterName.isEmpty ? "Unbekannt" : mieterName)
        MIETER-ADRESSE: \(mieterAdresse.isEmpty ? mietobjekt.adresse : mieterAdresse)
        MIETER-EMAIL: \(mieterEmail)
        DATUM: \(df.string(from: Date()))
        FRIST: \(fristText)

        MIETOBJEKT:
        - Adresse: \(mietobjekt.adresse)
        - Wohnfläche: \(flaecheStr) m²
        - Abrechnungszeitraum: \(zeitraumStr)
        - Nachzahlung laut Abrechnung: \(nachzahlungStr)

        FEHLER (nur bestätigte):
        \(findingsStr)

        GESAMTERSPARNIS: \(ersparnisStr)

        PFLICHT-BAUSTEIN — übernimm diesen Satz WÖRTLICH in den Brief
        (direkt vor dem Schlussgruß „Mit freundlichen Grüßen"):
        \(forderungsSatz)

        Antworte NUR mit dem JSON.
        """

        let responseText = try await AgentService.call(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            maxTokens: 3000
        )

        let cleaned = responseText
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw WiderspruchError.decodingFailed("Antwort des Berichterstatters konnte nicht gelesen werden.")
        }

        let betreff = (json["betreff"] as? String)
            ?? "Widerspruch Nebenkostenabrechnung \(zeitraumStr)"
        let brieftext = (json["brieftext"] as? String) ?? responseText
        let emailBody = (json["email_body"] as? String) ?? brieftext

        return EmailOutput(
            betreff: betreff,
            brieftext: brieftext,
            emailBody: emailBody
        )
    }

    // MARK: - WhatsApp Generator

    private static func generiereWhatsApp(
        findings: [Finding],
        bericht: Pruefbericht,
        mietobjekt: Mietobjekt,
        mieterName: String
    ) async throws -> WhatsAppOutput {
        let systemPrompt = """
        Erstelle eine kurze, sachliche WhatsApp-Nachricht an den Vermieter
        bezüglich fehlerhafter Nebenkostenabrechnung.

        REGELN:
        - Maximal 500 Zeichen
        - Höflich, sachlich, direkt
        - Sie-Form
        - Erwähne die Gesamtdifferenz und den wichtigsten Fehler
        - Kündige an, dass ein ausführliches Schreiben folgt
        - Keine Emojis
        - Keine Rechtsgrundlagen (die kommen im formellen Schreiben)

        AUSGABE:
        Nur die Nachricht, kein JSON. Reiner Text.
        """

        let ersparnis = findings
            .filter { $0.differenz > 0 }
            .reduce(Decimal(0)) { $0 + $1.differenz }

        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = "EUR"
        nf.locale = Locale(identifier: "de_DE")
        let ersparnisStr = nf.string(from: ersparnis as NSDecimalNumber) ?? "0 €"

        let wichtigsterFehler = findings
            .filter { $0.schwere == .fehler }
            .max(by: { $0.differenz < $1.differenz })

        let df = DateFormatter()
        df.dateFormat = "dd.MM.yyyy"
        df.locale = Locale(identifier: "de_DE")
        let zeitraumStr = "\(df.string(from: bericht.abrechnung.meta.zeitraum.von)) – \(df.string(from: bericht.abrechnung.meta.zeitraum.bis))"

        let userMessage = """
        VERMIETER-NAME: \(mietobjekt.vermieterName ?? "Vermieter")
        MIETER-NAME: \(mieterName.isEmpty ? "Mieter" : mieterName)
        WOHNUNG: \(mietobjekt.adresse)
        ZEITRAUM: \(zeitraumStr)

        FEHLER:
        - Anzahl Fehler: \(findings.filter { $0.schwere == .fehler }.count)
        - Gesamtdifferenz: \(ersparnisStr)
        - Wichtigster Fehler: \(wichtigsterFehler?.bezeichnung ?? "Diverse Fehler")

        Erstelle die WhatsApp-Nachricht. Nur den Text, nichts anderes.
        """

        let nachricht = try await AgentService.call(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            maxTokens: 300
        )

        let bereinigt = nachricht.trimmingCharacters(in: .whitespacesAndNewlines)
        let gekuerzt = String(bereinigt.prefix(500))
        return WhatsAppOutput(nachricht: gekuerzt)
    }
}
