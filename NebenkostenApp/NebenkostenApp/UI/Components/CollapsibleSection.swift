//
//  CollapsibleSection.swift
//  NebenkostenApp — UI/Components
//
//  Standard-Pattern für lange Listen: Card mit Tap-Header, der
//  Inhalt ein-/ausklappt. Der Zustand persistiert optional in
//  UserDefaults per `persistKey`, damit die App über Neustarts
//  hinweg die User-Präferenz hält (z.B. "Heizung default offen,
//  Reinigung hatte ich zugemacht").
//
//  Header-Layout:
//    [Chevron] [Titel] ····· [Summary]  [Count]
//                                       micro darunter
//
//  Animation: easeOut 0.2 s, asymmetric — Einblenden mit Slide-
//  Down + Fade, Ausblenden nur Fade.
//

import SwiftUI

struct CollapsibleSection<Content: View>: View {
    let titel: String
    let summary: String?
    let count: Int?
    let persistKey: String?
    let defaultOffen: Bool
    @ViewBuilder let content: () -> Content

    @State private var lokalOffen: Bool

    init(
        titel: String,
        summary: String? = nil,
        count: Int? = nil,
        persistKey: String? = nil,
        defaultOffen: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.titel = titel
        self.summary = summary
        self.count = count
        self.persistKey = persistKey
        self.defaultOffen = defaultOffen
        let initial: Bool
        if let k = persistKey, UserDefaults.standard.object(forKey: k) != nil {
            initial = UserDefaults.standard.bool(forKey: k)
        } else {
            initial = defaultOffen
        }
        _lokalOffen = State(initialValue: initial)
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                toggle()
            } label: {
                headerRow
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if lokalOffen {
                DividerLine()
                content()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.bgSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DesignTokens.separator, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(.easeOut(duration: 0.2), value: lokalOffen)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignTokens.textTertiary)
                .rotationEffect(.degrees(lokalOffen ? 90 : 0))
            VStack(alignment: .leading, spacing: 2) {
                Text(titel)
                    .appFont(AppFont.bodySemi())
                    .foregroundStyle(DesignTokens.text)
                if let count {
                    Text(countText(count))
                        .appFont(AppFont.caption())
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            }
            Spacer(minLength: 8)
            if let summary {
                Text(summary)
                    .appFont(AppFont.monoBody())
                    .foregroundStyle(DesignTokens.text)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func countText(_ n: Int) -> String {
        switch n {
        case 1: return "1 Eintrag"
        default: return "\(n) Einträge"
        }
    }

    // MARK: - Toggle

    private func toggle() {
        lokalOffen.toggle()
        if let k = persistKey {
            UserDefaults.standard.set(lokalOffen, forKey: k)
        }
    }
}
