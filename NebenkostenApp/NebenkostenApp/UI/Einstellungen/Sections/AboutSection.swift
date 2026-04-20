//
//  AboutSection.swift
//  NebenkostenApp — UI/Einstellungen/Sections
//

import SwiftUI

struct AboutSection: View {
    var body: some View {
        Section {
            LabeledContent("Version") { Text(versionString) }
            LabeledContent("Build")   { Text(buildString) }

            Link(destination: URL(string: "https://example.com/datenschutz")!) {
                Label("Datenschutzerklärung", systemImage: "lock.shield")
            }
            Link(destination: URL(string: "https://example.com/impressum")!) {
                Label("Impressum", systemImage: "info.circle")
            }
        } header: {
            Text("Über die App")
        } footer: {
            Text("NebenkostenApp — Phase 0 MVP. Entwicklung mit Claude 4.7 (Opus).")
        }
    }

    private var versionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildString: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}
