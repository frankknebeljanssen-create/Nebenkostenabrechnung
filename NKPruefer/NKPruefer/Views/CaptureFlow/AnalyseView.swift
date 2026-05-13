import SwiftUI
import SwiftData

/// Live-Pipeline-Status während der KI-Prüfung.
///
/// **UI-vs.-Pipeline-Mapping:**
/// Die interne `OrchestrationService.Phase` hat 9 Cases (ohne `.fertig`).
/// Für den User aggregieren wir auf 7 lesbare UI-Phasen — pro UI-Phase
/// können mehrere interne Phasen zugehören (z. B. Phase 4 deckt
/// die Code-Legal-DB-Prüfung `.recht` und den LLM-Juristen `.jurist`
/// gemeinsam ab).
struct AnalyseView: View {
    let auftrag: PruefungsAuftrag

    @EnvironmentObject var userProfile: UserProfile
    @EnvironmentObject var privacyConsent: PrivacyConsent
    @Environment(\.modelContext) private var modelContext

    @State private var orchestration = OrchestrationService()
    @State private var navigiereZuBericht = false
    @State private var fertigerBericht: Pruefbericht? = nil
    @State private var zeigeConsent = false
    @State private var datenGeprueft = false

    // MARK: - UI-Phasen-Mapping

    private struct UIPhase {
        let label: String
        let icon: String
        let phasen: [OrchestrationService.Phase]
    }

    /// Die 7 für den User sichtbaren Phasen.
    /// Hinweis: Die User-spezifizierten Case-Namen (.validator, .v1v2,
    /// .calculator, .challenger, .berichterstatter, .quality) existieren
    /// im Enum nicht — die echten Cases heißen anders, decken aber
    /// inhaltlich dasselbe ab.
    private let uiPhasen: [UIPhase] = [
        UIPhase(label: "Abrechnung lesen",
                icon: "doc.text.viewfinder",
                phasen: [.parser]),
        UIPhase(label: "Gegenprüfung",
                icon: "checkmark.shield",
                phasen: [.validierung]),
        UIPhase(label: "Zahlen prüfen",
                icon: "function",
                phasen: [.rechner]),
        UIPhase(label: "Rechtliche Bewertung",
                icon: "scale.3d",
                phasen: [.recht, .jurist]),
        UIPhase(label: "Ergebnisse hinterfragen",
                icon: "bubble.left.and.bubble.right",
                phasen: [.debatte]),
        UIPhase(label: "Bericht erstellen",
                icon: "doc.richtext",
                phasen: [.bericht, .review]),
        UIPhase(label: "Abschlusskontrolle",
                icon: "seal",
                phasen: [.audit])
    ]

    private var laeuft: Bool { orchestration.status == .running }

    private var fortschritt: Double {
        guard orchestration.gesamtSchritte > 0 else { return 0 }
        return Double(orchestration.abgeschlosseneSchritte) / Double(orchestration.gesamtSchritte)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                kopfBlock
                phasenBlock
                if laeuft {
                    restzeitHinweis
                }
                NKSecurityStrip(text: securityText)

                if orchestration.status == .failed,
                   let fehler = orchestration.fehlerMeldung {
                    fehlerAnsicht(text: fehler)
                }
            }
            .padding(AppSpacing.contentPadding)
        }
        .background(AppTheme.screenBg.ignoresSafeArea())
        .navigationTitle("Analyse")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(laeuft)
        .interactiveDismissDisabled(laeuft)
        .navigationDestination(isPresented: $navigiereZuBericht) {
            if let fertigerBericht, let mietobjekt = auftrag.mietobjekt {
                BerichtView(bericht: fertigerBericht, mietobjekt: mietobjekt)
            } else {
                EmptyView()
            }
        }
        .sheet(isPresented: $zeigeConsent) {
            PrivacyConsentView {
                Task { await starteAnalyseInternal() }
            }
        }
        .task {
            guard !datenGeprueft else { return }
            datenGeprueft = true
            await starteAnalyse()
        }
        .onChange(of: orchestration.status) { _, neu in
            if neu == .finished, let bericht = orchestration.bericht {
                fertigerBericht = bericht
                speicherePruefbericht(bericht)
                persistiereAuditEntries()
                navigiereZuBericht = true
            }
        }
    }

    // MARK: - Kopf-Block (ProgressBar + aktuelle Phase + Hinweis)

    private var kopfBlock: some View {
        NKCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                ProgressView(value: fortschritt)
                    .tint(AppTheme.accent)
                    .padding(.bottom, AppSpacing.xs)

                Text(aktuellePhaseLabel)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Dauert ca. 30–60 Sekunden")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Zeitschätzung (v4-15)

    /// Grobe Restzeit-Heuristik basierend auf der aktuellen Orchestrierungs-
    /// Phase. Bewusst Spannen statt sekundengenau — der User soll wissen
    /// „dauert noch ein bisschen" / „gleich fertig", nicht „54 Sekunden".
    private var geschaetzteRestzeit: String {
        guard let phase = orchestration.aktuellePhase else {
            return "Noch ca. 3 Minuten"
        }
        switch phase {
        case .parser:          return "Noch ca. 3 Minuten"
        case .validierung:     return "Noch ca. 2–3 Minuten"
        case .rechner:         return "Noch ca. 2 Minuten"
        case .recht:           return "Noch ca. 2 Minuten"
        case .jurist:          return "Noch ca. 1–2 Minuten"
        case .debatte:         return "Noch ca. 1 Minute"
        case .bericht:         return "Fast fertig …"
        case .review:          return "Fast fertig …"
        case .audit:           return "Gleich geschafft …"
        case .fertig:          return "Fertig"
        }
    }

    private var restzeitHinweis: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
            Text(geschaetzteRestzeit)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Geschätzte Restzeit: \(geschaetzteRestzeit)")
    }

    // MARK: - Phasen-Block (7 UI-Phasen)

    private var phasenBlock: some View {
        VStack(spacing: 0) {
            ForEach(uiPhasen.indices, id: \.self) { idx in
                phaseZeile(idx)
                if idx < uiPhasen.count - 1 {
                    Divider()
                        .padding(.leading, 56)
                }
            }
        }
        .background(AppTheme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(AppTheme.border, lineWidth: 0.5)
        )
    }

    private func phaseZeile(_ idx: Int) -> some View {
        let ui = uiPhasen[idx]
        let status = phaseStatus(idx)

        return HStack(spacing: AppSpacing.md) {
            Image(systemName: ui.icon)
                .font(.system(size: 18))
                .foregroundStyle(iconFarbe(status))
                .frame(width: 28, height: 28)

            Text(ui.label)
                .font(.system(size: 14))
                .foregroundStyle(textFarbe(status))

            Spacer(minLength: 0)

            statusBadge(status)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(ui.label): \(statusLabel(status))")
    }

    @ViewBuilder
    private func statusBadge(_ status: UIPhaseStatus) -> some View {
        switch status {
        case .erledigt:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.success)
                .imageScale(.large)
        case .aktiv:
            ProgressView()
                .controlSize(.small)
        case .wartend:
            Image(systemName: "circle")
                .foregroundStyle(AppTheme.textTertiary)
                .imageScale(.large)
        }
    }

    private enum UIPhaseStatus { case erledigt, aktiv, wartend }

    private func phaseStatus(_ idx: Int) -> UIPhaseStatus {
        let ui = uiPhasen[idx]
        let alleCases = OrchestrationService.Phase.allCases
        let allDone = ui.phasen.allSatisfy { phase in
            (alleCases.firstIndex(of: phase) ?? Int.max) < orchestration.abgeschlosseneSchritte
        }
        if allDone { return .erledigt }
        if let cur = orchestration.aktuellePhase, ui.phasen.contains(cur) {
            return .aktiv
        }
        return .wartend
    }

    private func iconFarbe(_ status: UIPhaseStatus) -> Color {
        switch status {
        case .erledigt: return AppTheme.success
        case .aktiv:    return AppTheme.accent
        case .wartend:  return AppTheme.textTertiary
        }
    }

    private func textFarbe(_ status: UIPhaseStatus) -> Color {
        status == .wartend ? AppTheme.textSecondary : AppTheme.textPrimary
    }

    private func statusLabel(_ status: UIPhaseStatus) -> String {
        switch status {
        case .erledigt: return "fertig"
        case .aktiv:    return "läuft"
        case .wartend:  return "wartet"
        }
    }

    private var aktuellePhaseLabel: String {
        switch orchestration.status {
        case .running:
            guard let current = orchestration.aktuellePhase else { return "Wird gestartet …" }
            return uiPhasen.first { $0.phasen.contains(current) }?.label ?? "Wird abgeschlossen …"
        case .finished: return "Fertig"
        case .failed:   return "Es gab ein Problem"
        case .idle:     return "Wird vorbereitet …"
        }
    }

    // MARK: - Security Strip (zeigt Anonymisierungs-Stats wenn vorhanden)

    private var securityText: String {
        let validatorEntry = orchestration.auditEntries.first { $0.agent == "Validator" }
        let namen = validatorEntry?.statsNamen ?? 0
        let ibans = validatorEntry?.statsIBANs ?? 0

        if namen > 0 || ibans > 0 {
            return "Anonymisiert · \(namen) Namen, \(ibans) IBANs ersetzt"
        }
        return "Anonymisiert · Daten werden geschützt gesendet"
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
                    Task {
                        orchestration.zurueckSetzen()
                        await starteAnalyse()
                    }
                }
            }
        }
    }

    // MARK: - Pre-Flight Checks (API-Key + DSGVO-Consent)

    private func starteAnalyse() async {
        guard auftrag.mietobjekt != nil else {
            orchestration.fehlerMeldung = "Es ist keine Wohnung ausgewählt."
            orchestration.status = .failed
            return
        }

        guard KeychainService.hasAPIKey else {
            orchestration.fehlerMeldung = "Kein Zugangsschlüssel. Bitte unter Mehr → Zugangsschlüssel eingeben."
            orchestration.status = .failed
            return
        }

        guard privacyConsent.hatZugestimmt else {
            zeigeConsent = true
            return
        }

        await starteAnalyseInternal()
    }

    private func starteAnalyseInternal() async {
        guard let mietobjekt = auftrag.mietobjekt else { return }
        await orchestration.starte(
            ocrText: auftrag.ocrText,
            mietobjekt: mietobjekt,
            mieterName: userProfile.vollerName,
            mieterAdresse: userProfile.volleAdresse
        )
    }

    // MARK: - Persistenz

    private func speicherePruefbericht(_ bericht: Pruefbericht) {
        guard let mietobjekt = auftrag.mietobjekt else { return }

        let gespeichert = GespeicherteAbrechnung(
            id: bericht.abrechnungId,
            zeitraumVon: bericht.abrechnung.meta.zeitraum.von,
            zeitraumBis: bericht.abrechnung.meta.zeitraum.bis,
            pruefDatum: bericht.pruefDatum,
            status: "geprueft",
            ersparnis: bericht.ersparnisGesamt
        )
        gespeichert.speichereBericht(bericht)

        if let bild = auftrag.originalBild {
            gespeichert.originalBildData = bild.jpegData(compressionQuality: 0.5)
        }

        modelContext.insert(gespeichert)
        mietobjekt.abrechnungen.append(gespeichert)
    }

    private func persistiereAuditEntries() {
        for entry in orchestration.auditEntries {
            modelContext.insert(entry)
        }
    }
}

#Preview {
    NavigationStack { AnalyseView(auftrag: PruefungsAuftrag()) }
        .environmentObject(UserProfile())
        .environmentObject(PrivacyConsent())
}
