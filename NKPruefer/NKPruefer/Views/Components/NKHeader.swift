import SwiftUI

struct NKHeader: View {
    let title: String
    var showBack: Bool = false
    var showInfo: Bool = false
    var onInfo: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {
            if showBack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(AppTheme.accent)
                        .frame(minWidth: 24, minHeight: 24)
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
            }

            Spacer()

            if showInfo {
                Button {
                    onInfo?()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.accent)
                        .frame(minWidth: 24, minHeight: 24)
                }
                .accessibilityLabel("Info")
            }
        }
        .padding(.horizontal, AppSpacing.contentPadding)
        .padding(.vertical, AppSpacing.sm)
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
