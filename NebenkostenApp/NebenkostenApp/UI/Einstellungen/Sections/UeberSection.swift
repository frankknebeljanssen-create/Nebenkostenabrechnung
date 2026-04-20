//
//  UeberSection.swift
//  NebenkostenApp — UI/Einstellungen/Sections
//
//  Meta-Info über die App: Version, Build, Bundle-ID, Gerät.
//  Ersatz für die alte AboutSection — semantisch dasselbe, aber im
//  UI-Fix-2-Design mit Mono-Werten und Device-Zeile.
//

import SwiftUI
import UIKit

struct UeberSection: View {
    var body: some View {
        Section {
            zeile("Version", wert: version)
            zeile("Build", wert: build)
            zeile("Bundle-ID", wert: bundleId, mono: true)
            zeile("Gerät", wert: geraet, mono: true)
            Button {
                // TODO: Mail-Composer mit Platzhalter-Empfänger-Adresse.
            } label: {
                HStack {
                    Text("Feedback senden")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "envelope")
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(true)
        } header: {
            Text("Über die App")
        } footer: {
            Text("Feedback-Integration folgt — bis dahin per App Store Review oder persönlichem E-Mail.")
                .appFont(AppFont.smallCaption())
                .foregroundStyle(DesignTokens.textTertiary)
        }
    }

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
