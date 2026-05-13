import SwiftUI

/// v4-15 — Schmaler Hinweis-Strip „Keine Rechtsberatung".
/// Wird auf BerichtView und WiderspruchView eingebunden, jeweils oberhalb
/// der Versand-/Aktions-Buttons.
struct NKDisclaimerStrip: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.top, 2)
            Text("Keine Rechtsberatung. Im Zweifel wende dich an deinen Mieterverein.")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, AppSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hinweis: Keine Rechtsberatung. Im Zweifel wende dich an deinen Mieterverein.")
    }
}

#Preview {
    NKDisclaimerStrip()
        .padding()
}
