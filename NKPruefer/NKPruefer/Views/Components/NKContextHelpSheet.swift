import SwiftUI

/// Wiederverwendbare Kontext-Hilfe als kompaktes Bottom-Sheet.
///
/// Nutzung:
/// ```swift
/// @State private var zeigeHilfe = false
/// // ...
/// Button("Was bedeutet das?") { zeigeHilfe = true }
///     .sheet(isPresented: $zeigeHilfe) {
///         NKContextHelpSheet(
///             titel: "Vertrauenswert",
///             text: "Der Vertrauenswert zeigt …"
///         )
///         .presentationDetents([.medium])
///     }
/// ```
struct NKContextHelpSheet: View {
    let titel: String
    let text: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            handleBar
                .padding(.top, AppSpacing.sm)

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text(titel)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView {
                    Text(text)
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, AppSpacing.contentPadding)
            .padding(.top, AppSpacing.md)

            Spacer(minLength: 0)

            NKPrimaryButton("Verstanden", icon: "checkmark") {
                dismiss()
            }
            .padding(.horizontal, AppSpacing.contentPadding)
            .padding(.bottom, AppSpacing.lg)
        }
        .background(AppTheme.screenBg.ignoresSafeArea())
    }

    private var handleBar: some View {
        Capsule()
            .fill(AppTheme.border)
            .frame(width: 36, height: 5)
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            NKContextHelpSheet(
                titel: "Vertrauenswert",
                text: "Der Vertrauenswert zeigt, wie sicher ein Ergebnis ist — auf einer Skala von 0 bis 100 %. Er setzt sich aus fünf Validierungs-Schichten zusammen."
            )
            .presentationDetents([.medium])
        }
}
