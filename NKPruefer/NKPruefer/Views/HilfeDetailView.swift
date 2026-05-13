import SwiftUI

/// Detail-Ansicht für einen lokalen Hilfe-Artikel.
/// Rendert die HilfeBlock-Cases:
///   • `.text`       → 14 pt Fließtext
///   • `.schritt`    → NKBadge mit Nummer + Text in einer Reihe
///   • `.farbBlock`  → 3 pt-Left-Border-Card mit Titel (bold) + Text
///   • `.hinweis`    → NKCard mit info.circle-Icon
struct HilfeDetailView: View {
    let artikel: HilfeArtikel

    var body: some View {
        VStack(spacing: 0) {
            NKHeader(title: artikel.titel, showBack: true)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    ForEach(Array(artikel.inhalt.enumerated()), id: \.offset) { _, block in
                        blockView(block)
                    }
                }
                .padding(AppSpacing.contentPadding)
            }
        }
        .background(AppTheme.screenBg.ignoresSafeArea())
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Block-Renderer

    @ViewBuilder
    private func blockView(_ block: HilfeBlock) -> some View {
        switch block {
        case .text(let s):
            textBlock(s)
        case .schritt(let nr, let s):
            schrittBlock(nummer: nr, text: s)
        case .farbBlock(let farbe, let titel, let text):
            farbBlockView(farbe: farbe, titel: titel, text: text)
        case .hinweis(let s):
            hinweisBlock(s)
        }
    }

    private func textBlock(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 14))
            .foregroundStyle(AppTheme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func schrittBlock(nummer: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            NKBadge(text: "\(nummer)", color: AppTheme.accent)
                .accessibilityHidden(true)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Schritt \(nummer): \(text)")
    }

    private func farbBlockView(farbe: Color, titel: String, text: String) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(farbe)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(titel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(text)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppTheme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardRadius)
                .stroke(AppTheme.border, lineWidth: 0.5)
        )
    }

    private func hinweisBlock(_ s: String) -> some View {
        NKCard {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                Image(systemName: "info.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 22)
                Text(s)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    NavigationStack {
        HilfeDetailView(artikel: HilfeKatalog.alle.first!)
    }
}
