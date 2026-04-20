//
//  PeriodStatsBlock.swift
//  NebenkostenApp — UI/Components
//
//  Zwei Stat-Blöcke nebeneinander mit vertikaler 0.5-pt-Rule
//  zwischen ihnen. Jeder Block hat einen kleinen Label, einen
//  monoStat-Wert und optional eine Detail-Zeile darunter.
//

import SwiftUI

struct StatBlock: View {
    let label: String
    let wert: String
    let detail: String?

    init(label: String, wert: String, detail: String? = nil) {
        self.label = label
        self.wert = wert
        self.detail = detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .appFont(AppFont.smallCaption())
                .foregroundStyle(DesignTokens.textTertiary)
            Text(wert)
                .appFont(AppFont.monoStat())
                .foregroundStyle(DesignTokens.text)
            if let detail {
                Text(detail)
                    .appFont(AppFont.smallCaption())
                    .foregroundStyle(DesignTokens.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PeriodStatsBlock: View {
    let links: StatBlock
    let rechts: StatBlock

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            links
            DividerLine(horizontal: false)
                .frame(maxHeight: .infinity)
            rechts
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
