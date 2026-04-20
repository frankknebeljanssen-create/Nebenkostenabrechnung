//
//  CompletionRing.swift
//  NebenkostenApp — UI/Objekt/Components
//
//  Vollständigkeits-Balken: dreifarbiger Stack (grün erledigt /
//  orange in Arbeit / grau offen) mit Live-Counts und Klartext-
//  Bereitschaftsaussage. Ursprünglich als 180×180-Ring gebaut,
//  seit v0.22 als schlanker Querbalken, seit v1.0 dreifarbig.
//

import SwiftUI

struct CompletionBalken: View {
    let erledigt: Int
    let inArbeit: Int
    let offen: Int
    let headerText: String
    let fussText: String
    let bereit: Bool

    private var total: Int { erledigt + inArbeit + offen }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if bereit {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.callout)
                }
                Text(headerText)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(bereit ? .green : .primary)
                Spacer()
            }

            GeometryReader { proxy in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: proxy.size.width * anteil(erledigt))
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: proxy.size.width * anteil(inArbeit))
                    Rectangle()
                        .fill(Color.gray.opacity(0.22))
                        .frame(width: proxy.size.width * anteil(offen))
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .animation(.easeInOut(duration: 0.3), value: erledigt + inArbeit + offen)
            }
            .frame(height: 16)

            Text(fussText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(erledigt) erledigt, \(inArbeit) in Arbeit, \(offen) offen. \(fussText)"
        )
    }

    private func anteil(_ n: Int) -> CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(n) / CGFloat(total)
    }
}

#Preview {
    VStack(spacing: 20) {
        CompletionBalken(
            erledigt: 23, inArbeit: 3, offen: 15,
            headerText: "23 von 41 Einträgen vollständig, 3 in Arbeit, 15 offen",
            fussText: "Abrechnung kann noch nicht erstellt werden. 18 Einträge fehlen noch.",
            bereit: false
        )
        CompletionBalken(
            erledigt: 41, inArbeit: 0, offen: 0,
            headerText: "Alle 41 Einträge vollständig",
            fussText: "Bereit zur Abrechnung.",
            bereit: true
        )
    }
    .padding()
}
