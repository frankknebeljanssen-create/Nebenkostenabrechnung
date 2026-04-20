//
//  FontProbeView.swift
//  NebenkostenApp — UI/Debug
//
//  Kontroll-View für das erste Laden der IBM Plex Fonts ins Bundle.
//  Zeigt alle sechs Schnitte (Sans + Mono, Regular/Medium/SemiBold)
//  mit Beispiel-Glyphen, Umlauten und einem €-Betrag — damit bei
//  fehlenden TTFs sofort sichtbar ist, dass der System-Fallback
//  greift.
//

import SwiftUI

struct FontProbeView: View {
    private let beispielText = "Die schnelle Füchsin – 1.234,56 €"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                sektion("IBM Plex Sans (Body)", familie: "IBMPlexSans")
                sektion("IBM Plex Mono (Zahlen & Messwerte)", familie: "IBMPlexMono")
                hinweis
            }
            .padding(20)
        }
        .navigationTitle("Font-Probe")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sektion(_ titel: String, familie: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(titel)
                .font(.headline)

            zeile("Regular 400", fontName: "\(familie)-Regular")
            zeile("Medium 500",  fontName: "\(familie)-Medium")
            zeile("SemiBold 600", fontName: "\(familie)-SemiBold")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func zeile(_ label: String, fontName: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(beispielText)
                .font(.custom(fontName, size: 22))
        }
    }

    private var hinweis: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hinweis")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Falls alle Zeilen gleich aussehen (System-Fallback), laden die TTFs aus Resources/Fonts/ nicht. Build-Phase »Copy Bundle Resources« prüfen und UIAppFonts in Info.plist verifizieren.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    NavigationStack { FontProbeView() }
}
