import SwiftUI

// MARK: - Buttons
//
// Größen-Spec (v4-11):
//   NKPrimaryButton:   Höhe 50pt, Font 16pt Medium, weiße Schrift auf accent.
//   NKSecondaryButton: Höhe 44pt, Font 15pt Medium, accent-Schrift mit Border.

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
            HStack(spacing: AppSpacing.sm) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
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
            HStack(spacing: AppSpacing.sm) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(AppTheme.accent)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.buttonRadius)
                    .stroke(AppTheme.border, lineWidth: 0.5)
            )
        }
    }
}

// MARK: - Cards

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

// MARK: - Security Strip
//
// Kompakter Streifen unter Content, der zeigt: „Anonymisiert verarbeitet".
// Max-Höhe ≈ 32pt: vertikales Padding bewusst klein, Icon 13pt.

struct NKSecurityStrip: View {
    let text: String

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "shield.checkered")
                .foregroundStyle(AppTheme.success)
                .font(.system(size: 13))
            Text(text)
                .font(AppTypography.hint)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
        .padding(.horizontal, AppSpacing.md)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.sm))
    }
}

// MARK: - Section Label
//
// 13pt Medium, all-caps, tertiary text. Reduzierter Top-Abstand,
// damit Sections nicht doppelt gestackt wirken.

struct NKSectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(AppTheme.textTertiary)
            .padding(.top, AppSpacing.md)
    }
}

// MARK: - Badge

struct NKBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
}
