//
//  SplashView.swift
//  NebenkostenApp — UI/Shell
//
//  Eine Sekunde sichtbarer App-Einstieg: App-Icon zentriert,
//  darunter Credits + Version/Build (aus Bundle.infoDictionary).
//  `ContentView` rendert die SplashView während der ersten ~1 s
//  und wechselt dann zu `AppShell` (bzw. `OnboardingFlow`).
//
//  Keine User-Interaktion nötig — der Wechsel erfolgt rein
//  zeitgesteuert. Design bewusst schlicht, heller Hintergrund,
//  kein Icon-Overlay oder Animation.
//

import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            DesignTokens.bgApp.ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()
                appIcon
                Text("Nebenkosten­abrechnung")
                    .appFont(AppFont.Basis.displayTitle())
                    .foregroundStyle(DesignTokens.text)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Spacer()
                footer
            }
        }
    }

    // MARK: - App-Icon (mittig)

    private var appIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(DesignTokens.accent)
                .frame(width: 112, height: 112)
                .shadow(
                    color: DesignTokens.accent.opacity(0.25),
                    radius: 14, x: 0, y: 6
                )
            Image(systemName: "house.fill")
                .font(.system(size: 52, weight: .medium))
                .foregroundStyle(DesignTokens.accentText)
        }
    }

    // MARK: - Footer: Credits + Version + Build

    private var footer: some View {
        VStack(spacing: 4) {
            Text("Ein Werkzeug für private Vermieter.")
                .appFont(AppFont.Basis.smallCaption())
                .foregroundStyle(DesignTokens.textTertiary)
            Text(versionZeile)
                .appFont(AppFont.Basis.monoMicro())
                .foregroundStyle(DesignTokens.textQuaternary)
        }
        .padding(.bottom, 28)
    }

    private var versionZeile: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build   = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "Version \(version) · Build \(build)"
    }
}
