import SwiftUI
import SwiftData

/// v4-Ergebnis-Ansicht.
///
/// Aufbau (von oben nach unten):
///  1. Vertrauenswert-Header (großer Prozentwert in Ampel-Farbe + Anonymisierungs-Badge)
///  2. „X Ergebnisse gefunden" + Hinweis „Tippe für Details"
///  3. Liste aufklappbarer Ergebnis-Karten (ErgebnisCard mit DisclosureGroup)
///  4. Aktions-Buttons (Widerspruch erstellen + WhatsApp/PDF teilen)
///  5. Footer (Disclaimer + Anonymisierungs-Strip)
///
/// Wir holen die Anonymisierungs-Stats per @Query aus den persistierten
/// APIAuditEntries — dort hat der Validator-Eintrag die Replace-Counts.
struct BerichtView: View {
    let bericht: Pruefbericht
    let mietobjekt: Mietobjekt

    /// Audit-Entries der letzten Stunde — wir suchen daraus den frischesten
    /// Validator-Eintrag, um die Anonymisierungs-Stats anzuzeigen.
    @Query(sort: \APIAuditEntry.zeitpunkt, order: .reverse)
    private var auditEntries: [APIAuditEntry]

    // MARK: - Abgeleitete Werte

    /// Aggregierter Vertrauenswert über alle Ergebnisse (0…100).
    /// Fällt auf `nil` zurück, wenn keine TrustScores vorliegen.
    private var vertrauenswertProzent: Int? {
        let scores = bericht.trustScores.values
        guard !scores.isEmpty else { return nil }
        let summe = scores.reduce(0) { $0 + $1.prozent }
        return Int((Double(summe) / Double(scores.count)).rounded())
    }

    private var vertrauenswertFarbe: Color {
        guard let p = vertrauenswertProzent else { return AppTheme.textTertiary }
        switch p {
        case 80...:   return AppTheme.success
        case 60..<80: return AppTheme.warning
        default:      return AppTheme.error
        }
    }

    private var sortierteFindings: [Finding] {
        bericht.findings.sorted { lhs, rhs in
            sortValue(lhs.schwere) < sortValue(rhs.schwere)
        }
    }

    private var hatHandlungsbedarf: Bool {
        bericht.findings.contains { $0.differenz > 0 }
    }

    /// Anonymisierungs-Stats aus dem zuletzt persistierten Validator-Eintrag.
    private var anonymisierungsBadgeText: String {
        let validator = auditEntries.first { $0.agent == "Validator" }
        let namen = validator?.statsNamen ?? 0
        let ibans = validator?.statsIBANs ?? 0
        if namen > 0 || ibans > 0 {
            return "Anonymisiert · \(namen) Namen, \(ibans) IBANs"
        }
        return "Anonymisiert verarbeitet"
    }

    /// Inhalt für den Teilen-Sheet (WhatsApp / PDF / etc.).
    private var teilenText: String {
        var t = "NK-Prüfer — Prüfbericht\n"
        t += "Wohnung: \(mietobjekt.adresse)\n\n"
        t += bericht.berichtText
        if bericht.ersparnisGesamt > 0 {
            t += "\n\nMögliche Ersparnis: \(formatGeld(bericht.ersparnisGesamt))"
        }
        return t
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                if bericht.findings.isEmpty {
                    // Endpunkt-Hero bei null Befunden — visuell beruhigend.
                    allesInOrdnungHero
                    keineErgebnisseAktionen
                } else {
                    vertrauenswertHeader
                    ergebnisseSection

                    if !bericht.berichtText.isEmpty {
                        berichtTextBlock
                    }

                    // v4-15: „Keine Rechtsberatung"-Hinweis direkt oberhalb der
                    // Aktions-Buttons — der User sieht ihn unmittelbar bevor
                    // er „Widerspruch erstellen" o.ä. tippt.
                    NKDisclaimerStrip()

                    aktionsButtons
                }

                fussNotiz
                NKSecurityStrip(text: "Anonymisiert verarbeitet")
            }
            .padding(.horizontal, AppSpacing.contentPadding)
            .padding(.vertical, AppSpacing.md)
        }
        .background(AppTheme.screenBg.ignoresSafeArea())
        .navigationTitle("Ergebnis")
        .navigationBarTitleDisplayMode(.inline)
        // X-Button statt Zurück-Chevron: BerichtView ist ein Endpunkt im
        // Capture-Flow, kein Zwischen-Screen. Tap auf X reset den
        // gesamten Capture-Stack zurück zur HomeView (über die
        // `.nkResetToHome`-Notification, die ContentView abhört).
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    NotificationCenter.default.post(name: .nkResetToHome, object: nil)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Schließen")
            }
        }
    }

    // MARK: - „Alles in Ordnung"-Endpunkt

    private var allesInOrdnungHero: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.success)
                .accessibilityHidden(true)

            Text("Alles in Ordnung!")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.success)
                .multilineTextAlignment(.center)

            Text("Wir haben keine Fehler in deiner Abrechnung gefunden.")
                .font(AppTypography.body)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Alles in Ordnung. Keine Fehler in der Abrechnung gefunden.")
    }

    private var keineErgebnisseAktionen: some View {
        VStack(spacing: AppSpacing.sm) {
            NavigationLink {
                PreCaptureView()
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "camera.fill")
                    Text("Neue Prüfung")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AppTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
            }
            .accessibilityLabel("Neue Prüfung starten")

            NKSecondaryButton("Schließen", icon: "house") {
                NotificationCenter.default.post(name: .nkResetToHome, object: nil)
            }
        }
    }

    // MARK: - Vertrauenswert-Header

    private var vertrauenswertHeader: some View {
        NKCard {
            HStack(alignment: .center, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(vertrauenswertProzent.map { "\($0) %" } ?? "—")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(vertrauenswertFarbe)
                    Text("Vertrauenswert")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer(minLength: 0)

                NKBadge(text: anonymisierungsBadgeText, color: AppTheme.success)
                    .accessibilityLabel(anonymisierungsBadgeText)
            }
        }
    }

    // MARK: - Ergebnisse-Section
    //
    // Wird ausschließlich gerendert, wenn `findings.nonEmpty` ist —
    // das Switching passiert im Body. Der Empty-Branch ist dort durch
    // `allesInOrdnungHero` ersetzt.

    @ViewBuilder
    private var ergebnisseSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("\(bericht.findings.count) \(bericht.findings.count == 1 ? "Ergebnis" : "Ergebnisse") gefunden")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Tippe für Details")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textTertiary)
        }

        VStack(spacing: AppSpacing.sm) {
            ForEach(sortierteFindings) { finding in
                ErgebnisCard(
                    finding: finding,
                    trustScore: bericht.trustScores[finding.id]
                )
            }
        }
    }

    // MARK: - Bericht-Text-Block

    private var berichtTextBlock: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Bericht")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            NKCard {
                Text(bericht.berichtText)
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Aktions-Buttons (Widerspruch + WhatsApp + PDF)

    private var aktionsButtons: some View {
        VStack(spacing: AppSpacing.sm) {
            if hatHandlungsbedarf {
                NavigationLink {
                    WiderspruchView(bericht: bericht, mietobjekt: mietobjekt)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "envelope")
                        Text("Widerspruch erstellen")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
                }
                .accessibilityLabel("Widerspruch erstellen")
            }

            HStack(spacing: AppSpacing.sm) {
                ShareLink(item: teilenText, subject: Text("Mein Prüfbericht")) {
                    HStack(spacing: 8) {
                        Image(systemName: "message")
                        Text("WhatsApp")
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                            .stroke(AppTheme.border, lineWidth: 0.5)
                    )
                }
                .accessibilityLabel("Per WhatsApp teilen")

                ShareLink(item: teilenText, subject: Text("Mein Prüfbericht (PDF)")) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.richtext")
                        Text("PDF")
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                            .stroke(AppTheme.border, lineWidth: 0.5)
                    )
                }
                .accessibilityLabel("Als PDF teilen")
            }
        }
    }

    // MARK: - Fußnote

    private var fussNotiz: some View {
        Text("Automatisch erstellt — ersetzt keine Rechtsberatung.")
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Helpers

    private func sortValue(_ schwere: Schwere) -> Int {
        switch schwere {
        case .fehler:  return 0
        case .warnung: return 1
        case .info:    return 2
        }
    }
}

// MARK: - ErgebnisCard (aufklappbare v4-Karte)

private struct ErgebnisCard: View {
    let finding: Finding
    let trustScore: TrustScore?

    @State private var aufgeklappt = false

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(akzentFarbe)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                kopfZeile
                kurzbeschreibung
                if trustScore != nil {
                    trustBalken
                }
                DisclosureGroup(isExpanded: $aufgeklappt) {
                    detailBlock
                        .padding(.top, AppSpacing.sm)
                } label: {
                    Text("Was bedeutet das?")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.accent)
                }
                .tint(AppTheme.accent)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppTheme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(AppTheme.border, lineWidth: 0.5)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(finding.bezeichnung), \(betragText)")
        .accessibilityHint("Tippe für Details")
    }

    // MARK: - Sub-Views

    private var kopfZeile: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Text(finding.bezeichnung)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !betragText.isEmpty {
                NKBadge(text: betragText, color: akzentFarbe)
            }
        }
    }

    private var kurzbeschreibung: some View {
        Text(finding.beschreibung)
            .font(.system(size: 13))
            .foregroundStyle(AppTheme.textSecondary)
            .lineLimit(aufgeklappt ? nil : 2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var trustBalken: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppTheme.border)
                Capsule()
                    .fill(trustFarbe)
                    .frame(width: geo.size.width * trustAnteil)
            }
        }
        .frame(height: 6)
        .accessibilityLabel("Vertrauenswert \(trustScore?.prozent ?? 0) Prozent")
    }

    @ViewBuilder
    private var detailBlock: some View {
        let hasAny =
            (finding.erklaerung?.isEmpty == false) ||
            (finding.rechtsgrundlage?.isEmpty == false) ||
            (finding.handlungsempfehlung?.isEmpty == false)

        if hasAny {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                if let erkl = finding.erklaerung, !erkl.isEmpty {
                    detailZeile(label: "Erklärung", text: erkl)
                }
                if let rg = finding.rechtsgrundlage, !rg.isEmpty {
                    detailZeile(label: "Rechtsgrundlage", text: rg, monospaced: true)
                }
                if let tip = finding.handlungsempfehlung, !tip.isEmpty {
                    detailZeile(label: "Empfehlung", text: tip)
                }
            }
        } else {
            Text("Keine Details verfügbar.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textTertiary)
        }
    }

    private func detailZeile(label: String, text: String, monospaced: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.textTertiary)
            Text(text)
                .font(.system(size: 13, weight: .regular, design: monospaced ? .monospaced : .default))
                .foregroundStyle(AppTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Style-Helpers

    /// 3px-Linke-Border-Farbe: rot bei Fehler, amber bei Warnung,
    /// grau (Border) bei reiner Info.
    private var akzentFarbe: Color {
        switch finding.schwere {
        case .fehler:  return AppTheme.error
        case .warnung: return AppTheme.warning
        case .info:    return AppTheme.border
        }
    }

    private var trustFarbe: Color {
        guard let p = trustScore?.prozent else { return AppTheme.textTertiary }
        switch p {
        case 80...:   return AppTheme.success
        case 60..<80: return AppTheme.warning
        default:      return AppTheme.error
        }
    }

    private var trustAnteil: CGFloat {
        guard let p = trustScore?.prozent else { return 0 }
        return CGFloat(max(0, min(100, p))) / 100.0
    }

    /// Kurzform für die Betrag-NKBadge — leer wenn Differenz 0 ist.
    private var betragText: String {
        guard finding.differenz != 0 else { return "" }
        return formatGeldKompakt(abs(finding.differenz))
    }

    private func formatGeldKompakt(_ wert: Decimal) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = "EUR"
        nf.maximumFractionDigits = (wert == wert.rounded(0)) ? 0 : 2
        nf.locale = Locale(identifier: "de_DE")
        return nf.string(from: wert as NSDecimalNumber) ?? "—"
    }
}

private extension Decimal {
    func rounded(_ scale: Int) -> Decimal {
        var src = self
        var dst = Decimal()
        NSDecimalRound(&dst, &src, scale, .plain)
        return dst
    }
}

// MARK: - Preview

#Preview {
    let bericht = Pruefbericht(
        abrechnungId: "NK-2026-PREV",
        pruefDatum: Date(),
        abrechnung: Abrechnung(
            meta: AbrechnungMeta(
                vermieter: ParsedVermieter(name: "Demo", adresse: "Demo-Adresse"),
                objekt: ParsedObjekt(adresse: "Demo", gesamtflaecheQm: 1000, anzahlEinheiten: 18, baujahr: nil),
                zeitraum: Zeitraum(von: .now, bis: .now),
                mieterEinheit: MieterEinheit(bezeichnung: nil, flaecheQm: 68, personen: 2),
                vorauszahlungenGesamt: 0,
                nachzahlungOderGuthaben: 0,
                typ: .nachzahlung
            ),
            kostenpositionen: [],
            summeAnteile: 0,
            confidenceGesamt: .high,
            warnungen: []
        ),
        findings: [],
        berichtText: "Hier steht der Bericht.",
        ersparnisGesamt: 0
    )
    let demoMietobjekt = Mietobjekt(adresse: "Demo-Adresse", flaecheQm: 68, personenzahl: 2)
    return NavigationStack { BerichtView(bericht: bericht, mietobjekt: demoMietobjekt) }
        .modelContainer(for: [Mietobjekt.self, GespeicherteAbrechnung.self, APIAuditEntry.self], inMemory: true)
}
