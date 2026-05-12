import SwiftUI

struct NKPrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(AppTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.buttonRadius))
        }
    }
}

struct NKSecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(AppTheme.accent)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                    .stroke(AppTheme.border, lineWidth: 0.5)
            )
        }
    }
}

struct NKCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(AppSpacing.cardPadding)
            .background(AppTheme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                    .stroke(AppTheme.border, lineWidth: 0.5)
            )
    }
}

struct NKFeaturedCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(AppSpacing.cardPadding)
            .background(AppTheme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                    .stroke(AppTheme.accent, lineWidth: 1.5)
            )
    }
}

struct NKSecurityStrip: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "shield.checkered")
                .foregroundStyle(AppTheme.success)
                .font(.system(size: 14))
            Text(text)
                .font(AppTypography.hint)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
        .padding(.horizontal, AppSpacing.lg)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.sm))
    }
}

struct NKSectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(AppTheme.textTertiary)
            .padding(.top, AppSpacing.xl)
    }
}

struct NKBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
}
