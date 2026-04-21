//
//  NaechsterSchrittCard.swift
//  NebenkostenApp — UI/Home
//
//  Eigene Card unter der Status-Card. Zwei Zustaende:
//
//  1. Completion < 100 %  → Liste aller unvollstaendigen Punkte
//     (offen + teilweise, jeder mit Sprungziel). Jede Zeile ist
//     tappbar und ruft `onSprung` mit ihrem Sprungziel — der
//     AppShellRouter entscheidet, welcher Tab / Sheet geoeffnet
//     wird.
//
//  2. Completion == 100 % → prominenter CTA-Button
//     „Abrechnungsdokumente erstellen" (Accent #3A5578, weisse
//     Schrift) — ruft `onFinalAktion`, HomeView wechselt auf den
//     Abrechnungen-Tab.
//
//  Keine Anforderungen → Card rendert ein EmptyView (defensiv:
//  etwa waehrend Store-Load).
//

import SwiftUI

struct NaechsterSchrittCard: View {
    let anforderungen: [AnforderungMitStatus]
    let onSprung: (Sprungziel) -> Void
    let onFinalAktion: () -> Void
    /// Farbiger Balken links — synchron zu HomeStatusCard und
    /// WohneinheitCard.
    let balkenFarbe: Color

    var body: some View {
        if !anforderungen.isEmpty {
            Card(tiefe: .erhoben, balkenFarbe: balkenFarbe) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Nächste Schritte")
                        .appFont(Self.kickerStyle)
                        .foregroundStyle(DesignTokens.textTertiary)
                    if unvollstaendig.isEmpty {
                        ctaButton
                    } else {
                        liste
                    }
                }
            }
        }
    }

    /// 14 pt / 600 / tracking 0.6 UPPER — identisch zu
    /// `HomeStatusCard.kickerStyle`, damit beide Home-Cards den
    /// gleichen Kicker-Look tragen.
    private static let kickerStyle = AppFontStyle(
        font: AppFont.plexSans(.semibold, 14),
        tracking: 0.6,
        uppercase: true
    )

    // MARK: - CTA (100 %)

    private var ctaButton: some View {
        Button(action: onFinalAktion) {
            HStack(spacing: 10) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text("Abrechnungsdokumente erstellen")
                    .appFont(AppFont.bodySemi())
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 4)
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(DesignTokens.accent)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Abrechnungsdokumente erstellen")
    }

    // MARK: - Liste (unter 100 %)

    private var liste: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(unvollstaendig.enumerated()), id: \.element.id) { idx, anf in
                if idx > 0 {
                    DividerLine()
                }
                if let ziel = anf.sprungZiel {
                    Button { onSprung(ziel) } label: {
                        zeile(anf)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func zeile(_ anf: AnforderungMitStatus) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName(for: anf.status))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(farbe(for: anf.status))
                .frame(width: 16, alignment: .center)
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: 2) {
                Text(anf.anforderung.titel)
                    .appFont(AppFont.bodyMedium())
                    .foregroundStyle(DesignTokens.text)
                    .multilineTextAlignment(.leading)
                if let hinweis = anf.hinweis, !hinweis.isEmpty {
                    Text(hinweis)
                        .appFont(AppFont.caption())
                        .foregroundStyle(DesignTokens.textSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(DesignTokens.textTertiary)
                .padding(.top, 5)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - Ableitungen

    /// Alle nicht erfuellten Anforderungen mit einem Sprungziel —
    /// die Liste zeigt nur, was der User tatsaechlich adressieren
    /// kann.
    private var unvollstaendig: [AnforderungMitStatus] {
        anforderungen.filter {
            $0.sprungZiel != nil
                && $0.status != .erfuellt
                && $0.status != .nichtErwartet
        }
    }

    private func iconName(for status: AnforderungsStatus) -> String {
        switch status {
        case .teilweise: return "circle.lefthalf.filled"
        case .offen:     return "circle"
        default:         return "circle"
        }
    }

    private func farbe(for status: AnforderungsStatus) -> Color {
        switch status {
        case .teilweise: return DesignTokens.statusWarn
        case .offen:     return DesignTokens.statusError
        default:         return DesignTokens.textSecondary
        }
    }
}
