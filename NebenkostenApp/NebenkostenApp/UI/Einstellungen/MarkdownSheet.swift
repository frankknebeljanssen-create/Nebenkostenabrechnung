//
//  MarkdownSheet.swift
//  NebenkostenApp — UI/Einstellungen
//
//  Sheet, das den Inhalt einer Markdown-Datei aus Resources/Legal/
//  rendert. Nutzt `AttributedString(markdown:)` mit markdownParsing-
//  Option fullDocument + interpretedSyntax: .inlineOnlyPreservingWhitespace.
//
//  Fallback: wenn die Datei nicht gefunden wird, Hinweis-Text.
//

import SwiftUI

struct MarkdownSheet: View {
    let titel: String
    let dateiname: String   // z.B. "datenschutz"

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let text = rendereMarkdown() {
                        Text(text)
                            .textSelection(.enabled)
                            .appFont(AppFont.body())
                            .foregroundStyle(DesignTokens.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Text nicht verfügbar")
                                .appFont(AppFont.bodySemi())
                                .foregroundStyle(DesignTokens.text)
                            Text("Der Inhalt »\(dateiname).md« konnte nicht aus dem App-Bundle geladen werden.")
                                .appFont(AppFont.caption())
                                .foregroundStyle(DesignTokens.textSecondary)
                        }
                    }
                }
                .padding(20)
            }
            .background(DesignTokens.bgApp)
            .navigationTitle(titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private func rendereMarkdown() -> AttributedString? {
        guard let url = Bundle.main.url(forResource: dateiname, withExtension: "md"),
              let raw = try? String(contentsOf: url, encoding: .utf8)
        else { return nil }

        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .full
        return try? AttributedString(markdown: raw, options: options)
    }
}
