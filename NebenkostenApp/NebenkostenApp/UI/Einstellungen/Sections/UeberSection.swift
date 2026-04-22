//
//  UeberSection.swift
//  NebenkostenApp — UI/Einstellungen/Sections
//
//  Meta-Info über die App: Version, Build, Bundle-ID, Gerät, plus
//  „Feedback senden". Der Feedback-Button oeffnet MFMailCompose mit
//  vorgegebenem Empfaenger + Diagnose-Footer (Version, Build, Device).
//  Wenn iOS keinen Mail-Account eingerichtet hat (Simulator ohne
//  Konfiguration oder frisches Geraet), faellt er auf eine
//  `mailto:`-URL zurueck — iOS uebergibt das an die Default-Mail-App.
//

import SwiftUI
import UIKit

struct UeberSection: View {
    /// Platzhalter — vor Launch auf echte Supporter-Adresse aendern.
    /// Der mailto-Fallback nutzt denselben Wert.
    static let feedbackEmail = "feedback@nebenkosten.app"

    @State private var zeigeMailComposer = false
    @State private var mailInhalt = MailInhalt()

    var body: some View {
        Section {
            zeile("Version", wert: version)
            zeile("Build", wert: build)
            zeile("Bundle-ID", wert: bundleId, mono: true)
            zeile("Gerät", wert: geraet, mono: true)
            Button {
                starteFeedbackMail()
            } label: {
                HStack {
                    Text("Feedback senden")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "envelope")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Über die App")
        } footer: {
            Text("Empfänger: \(Self.feedbackEmail)")
                .appFont(AppFont.smallCaption())
                .foregroundStyle(DesignTokens.textTertiary)
        }
        .sheet(isPresented: $zeigeMailComposer) {
            MailComposer(inhalt: mailInhalt)
                .ignoresSafeArea()
        }
    }

    // MARK: - Feedback-Trigger

    /// Wenn ein Mail-Account da ist, oeffnet den MFMailCompose-Sheet
    /// mit Diagnose-Info. Ohne Account: `mailto:`-URL an die Default-
    /// Mail-App. Fallback-URL enthaelt denselben Text — der User
    /// weiss also in beiden Wegen, welche Info er absendet.
    private func starteFeedbackMail() {
        let inhalt = baueFeedbackInhalt()
        if MailComposer.kannMailSenden {
            mailInhalt = inhalt
            zeigeMailComposer = true
        } else if let url = MailToFallback.url(fuer: inhalt) {
            UIApplication.shared.open(url)
        }
    }

    private func baueFeedbackInhalt() -> MailInhalt {
        let diagnose = """


        ——————————————
        App-Version: \(version) (\(build))
        Bundle: \(bundleId)
        Gerät: \(geraet)
        """
        return MailInhalt(
            empfaenger: [Self.feedbackEmail],
            betreff: "Feedback zur Nebenkosten-App",
            nachricht: "Mein Feedback:\n\n" + diagnose
        )
    }

    // MARK: - Info-Zeile

    private func zeile(_ label: String, wert: String, mono: Bool = false) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.primary)
            Spacer()
            Text(wert)
                .appFont(mono ? AppFont.monoCaption() : AppFont.body())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
        }
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    private var bundleId: String {
        Bundle.main.bundleIdentifier ?? "—"
    }

    private var geraet: String {
        let dev = UIDevice.current
        return "\(dev.model) · iOS \(dev.systemVersion)"
    }
}
