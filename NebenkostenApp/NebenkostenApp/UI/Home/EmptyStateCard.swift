//
//  EmptyStateCard.swift
//  NebenkostenApp — UI/Home
//
//  Wenn keine Immobilie im Store ist, zeigt der HomeScreen statt
//  der Objekt/Einheit-Cards diese EmptyStateCard. Eine große Card
//  mit klarer Erklärung und einer Haupt-Aktion.
//
//  Die Aktion „Erstes Objekt anlegen" öffnet den Objekt-Wizard bzw.
//  Einstellungen → Objekt — die konkrete Anbindung liegt bei der
//  Parent-View.
//

import SwiftUI

struct EmptyStateCard: View {
    /// Primäre Aktion: Objekt anlegen oder auswählen.
    let onPrimaerAktion: () -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "building.2")
                    .font(.system(size: 40, weight: .regular))
                    .foregroundStyle(DesignTokens.accent)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Noch kein Objekt")
                        .appFont(AppFont.Basis.displayTitle())
                        .foregroundStyle(DesignTokens.text)
                    Text("Lege dein erstes Mietobjekt an, um mit einer Nebenkostenabrechnung zu starten. Du kannst später weitere Objekte hinzufügen.")
                        .appFont(AppFont.Rechnungen.subZeile())
                        .foregroundStyle(DesignTokens.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: onPrimaerAktion) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Erstes Objekt anlegen")
                            .appFont(AppFont.Abrechnung.primaerButton())
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundStyle(DesignTokens.accentText)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .background(DesignTokens.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 6)
        }
    }
}
