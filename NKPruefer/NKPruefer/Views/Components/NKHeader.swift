import SwiftUI

struct NKHeader: View {
    let title: String
    var showBack: Bool = false
    var showInfo: Bool = false
    var onInfo: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            if showBack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Zurück")
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("NK-Prüfer")
                    .font(AppTypography.appIdentifier)
                    .foregroundStyle(AppTheme.textTertiary)
                Text(title)
                    .font(AppTypography.screenHeadline)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: AppSpacing.sm)

            if showInfo {
                Button {
                    onInfo?()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 17))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Info")
            }
        }
        .padding(.horizontal, AppSpacing.contentPadding)
        // Vertikales Padding bewusst klein, da die Buttons schon 44pt sind —
        // Header-Gesamthöhe damit ~48pt, kompakt aber barrierefrei.
        .padding(.vertical, 2)
    }
}

#Preview {
    VStack(spacing: 0) {
        NKHeader(title: "Start")
        Divider()
        NKHeader(title: "Prüfung vom 12.05.2026", showBack: true)
        Divider()
        NKHeader(title: "Datenschutz", showBack: true, showInfo: true) {
            print("Info getippt")
        }
    }
}
