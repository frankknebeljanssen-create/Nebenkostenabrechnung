//
//  RechtlichesSection.swift
//  NebenkostenApp — UI/Einstellungen/Sections
//
//  Vier Rows, die jeweils ein Markdown-Sheet aus Resources/Legal/
//  öffnen.
//

import SwiftUI

struct RechtlichesSection: View {

    @State private var aktiv: Eintrag?

    struct Eintrag: Identifiable, Hashable {
        let titel: String
        let dateiname: String
        var id: String { dateiname }
    }

    private let eintraege: [Eintrag] = [
        .init(titel: "Datenschutzerklärung",  dateiname: "datenschutz"),
        .init(titel: "Impressum",              dateiname: "impressum"),
        .init(titel: "Nutzungsbedingungen",    dateiname: "nutzungsbedingungen"),
        .init(titel: "Open-Source-Lizenzen",   dateiname: "lizenzen")
    ]

    var body: some View {
        Section {
            ForEach(eintraege) { e in
                Button {
                    aktiv = e
                } label: {
                    HStack {
                        Text(e.titel)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        } header: {
            Text("Rechtliches")
        } footer: {
            Text("Die Texte sind aktuell Platzhalter und werden vor dem Launch finalisiert.")
                .appFont(AppFont.smallCaption())
                .foregroundStyle(DesignTokens.textTertiary)
        }
        .sheet(item: $aktiv) { e in
            MarkdownSheet(titel: e.titel, dateiname: e.dateiname)
        }
    }
}
