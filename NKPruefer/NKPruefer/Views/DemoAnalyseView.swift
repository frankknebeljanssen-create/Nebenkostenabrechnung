import SwiftUI
import SwiftData

/// v4-21: Animierte Fake-Analyse für den Demo-Flow.
///
/// Zeigt die gleiche 7-Phasen-Optik wie die echte `AnalyseView`,
/// aber ohne API-Calls. Phasen ticken alle ~3,5 Sekunden weiter.
/// Nach allen Phasen automatischer Push zum `BerichtView(isDemo: true)`.
struct DemoAnalyseView: View {
    @State private var aktuellePhaseIndex: Int = 0
    @State private var fertig: Bool = false
    @State private var navigiereZuBericht: Bool = false

    private let phasen: [(icon: String, label: String)] = [
        ("doc.viewfinder", "Abrechnung lesen"),
        ("checkmark.shield", "Gegenprüfung"),
        ("function", "Zahlen prüfen"),
        ("scale.3d", "Rechtliche Bewertung"),
        ("bubble.left.and.bubble.right", "Qualitätsprüfung"),
        ("doc.richtext", "Bericht erstellen"),
        ("seal", "Abschlusskontrolle")
    ]

    private let phasenDelay: Double = 3.5

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xxl) {
                demoBanner
                kopfBlock
                phasenBlock
                NKSecurityStrip(text: "Anonymisiert · Daten werden geschützt gesendet")
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.vertical, AppSpacing.lg)
        }
        .background(AppTheme.screenBg.ignoresSafeArea())
        .navigationTitle("Demo-Analyse")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(!fertig)
        .interactiveDismissDisabled(!fertig)
        .navigationDestination(isPresented: $navigiereZuBericht) {
            BerichtView(
                bericht: DemoData.erstellePruefbericht(),
                mietobjekt: DemoData.mietobjekt(),
                isDemo: true
            )
        }
        .onAppear { starteAnimation() }
    }

    // MARK: - Demo-Banner

    private var demoBanner: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.accent)
            Text("Demo-Modus — Beispieldaten")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.accent)
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.accent.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
    }

    // MARK: - Kopf

    private var kopfBlock: some View {
        NKCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                ProgressView(value: fortschritt)
                    .tint(AppTheme.accent)
                    .padding(.bottom, AppSpacing.xs)

                Text(aktuellesPhasenLabel)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(fertig ? "Prüfung abgeschlossen" : "Dauert ca. 25 Sekunden")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var fortschritt: Double {
        guard !phasen.isEmpty else { return 0 }
        let done = fertig ? phasen.count : aktuellePhaseIndex
        return Double(done) / Double(phasen.count)
    }

    private var aktuellesPhasenLabel: String {
        if fertig { return "Fertig" }
        if aktuellePhaseIndex < phasen.count {
            return phasen[aktuellePhaseIndex].label
        }
        return "Wird gestartet …"
    }

    // MARK: - Phasen-Liste

    private var phasenBlock: some View {
        VStack(spacing: 0) {
            ForEach(phasen.indices, id: \.self) { idx in
                phaseZeile(idx)
                if idx < phasen.count - 1 {
                    Divider().padding(.leading, 56)
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
        let p = phasen[idx]
        let status = phaseStatus(idx)

        return HStack(spacing: AppSpacing.md) {
            Image(systemName: p.icon)
                .font(.system(size: 18))
                .foregroundStyle(iconFarbe(status))
                .frame(width: 28, height: 28)

            Text(p.label)
                .font(.system(size: 14, weight: status == .aktiv ? .semibold : .regular))
                .foregroundStyle(textFarbe(status))

            Spacer(minLength: 0)

            statusBadge(status)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.md)
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
                .tint(Color.orange)
        case .wartend:
            Image(systemName: "circle")
                .foregroundStyle(AppTheme.textTertiary)
                .imageScale(.large)
        }
    }

    private enum UIPhaseStatus { case erledigt, aktiv, wartend }

    private func phaseStatus(_ idx: Int) -> UIPhaseStatus {
        if fertig || idx < aktuellePhaseIndex { return .erledigt }
        if idx == aktuellePhaseIndex { return .aktiv }
        return .wartend
    }

    private func iconFarbe(_ s: UIPhaseStatus) -> Color {
        switch s {
        case .erledigt: return AppTheme.success
        case .aktiv:    return AppTheme.accent
        case .wartend:  return AppTheme.textTertiary
        }
    }

    private func textFarbe(_ s: UIPhaseStatus) -> Color {
        s == .wartend ? AppTheme.textSecondary : AppTheme.textPrimary
    }

    // MARK: - Animation

    private func starteAnimation() {
        for i in 0..<phasen.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * phasenDelay) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    aktuellePhaseIndex = i
                }
            }
        }
        // Nach allen Phasen: kurze Pause, dann fertig + Navigation
        let total = Double(phasen.count) * phasenDelay + 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + total) {
            withAnimation { fertig = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                navigiereZuBericht = true
            }
        }
    }
}

#Preview {
    NavigationStack { DemoAnalyseView() }
        .modelContainer(for: [Mietobjekt.self, GespeicherteAbrechnung.self, APIAuditEntry.self], inMemory: true)
}
