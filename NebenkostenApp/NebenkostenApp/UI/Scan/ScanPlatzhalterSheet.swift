//
//  ScanPlatzhalterSheet.swift
//  NebenkostenApp — UI/Scan
//
//  Generisches „folgt in naechstem Task"-Sheet. Wird vom Universeller-
//  Analyse-Routing verwendet, solange die Ziel-UIs (Mietvertrag-
//  Scan-Sheet, Mieterhoehungs-Sheet) noch nicht gebaut sind. Der
//  Screen zeigt dem User den erkannten Typ + die vom Klassifikator
//  gelieferten Felder und signalisiert transparent, dass die
//  eigentliche Bearbeitungs-UI folgt.
//
//  Das Dokument selbst ist bereits abgelegt (via `DokumentAblage
//  Service`) — der User verliert also nichts, der Placeholder
//  ersetzt nur den Bearbeitungs-Schritt.
//

import SwiftUI

struct ScanPlatzhalterSheet: View {
    let typ: Dokumenttyp
    let felder: [String: String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    kopfBlock
                    if !felder.isEmpty {
                        felderListe
                    }
                    hinweis
                }
                .padding(16)
            }
            .background(DesignTokens.bgAppCompact)
            .sheetTitelHeader("Typ erkannt")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetToolbar.abbrechen(titel: "Schließen") { dismiss() }
                }
            }
        }
    }

    private var kopfBlock: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(DesignTokens.statusOk)
            VStack(alignment: .leading, spacing: 2) {
                Text(typ.anzeigeName)
                    .appFont(AppFont.Basis.bodySemi())
                    .foregroundStyle(DesignTokens.text)
                Text("Dokument wurde gespeichert")
                    .appFont(AppFont.Basis.caption())
                    .foregroundStyle(DesignTokens.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(DesignTokens.statusOkSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var felderListe: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Erkannte Felder")
                .appFont(AppFont.Basis.kicker())
                .foregroundStyle(DesignTokens.textSecondary)
            VStack(spacing: 0) {
                ForEach(felder.keys.sorted(), id: \.self) { key in
                    HStack(alignment: .firstTextBaseline) {
                        Text(key)
                            .appFont(AppFont.Basis.caption())
                            .foregroundStyle(DesignTokens.textSecondary)
                        Spacer(minLength: 8)
                        Text(felder[key] ?? "—")
                            .appFont(AppFont.Basis.body())
                            .foregroundStyle(DesignTokens.text)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    DividerLine()
                }
            }
            .background(DesignTokens.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var hinweis: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(DesignTokens.textSecondary)
            Text("Die Bearbeitungs-Oberfläche für \(typ.anzeigeName) folgt in einem nächsten Task. Das Dokument ist bereits unter \u{201E}Belege\u{201C} archiviert.")
                .appFont(AppFont.Basis.caption())
                .foregroundStyle(DesignTokens.textSecondary)
                .multilineTextAlignment(.leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.bgSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(DesignTokens.separator, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
