//
//  CollapsibleSection.swift
//  NebenkostenApp — UI/Components
//
//  Standard-Pattern für lange Listen nach UI-Fix-2a.
//
//  Layout-Prinzip (aus meters-bills.jsx BillsScreen):
//    - Header ist ein eigenständiger Button auf dem App-
//      Background (bgApp). KEIN Card-Container, kein Rahmen.
//    - Card erscheint NUR wenn `istOffen` — sie umschließt
//      ausschließlich den Content (die Rows).
//    - Collapsed = Header bleibt, Card komplett weg.
//
//  Header-Layout:
//    [Chevron] TITEL (uppercase)       Summary (mono)
//       12pt   12pt/600 tracking 0.6   17pt/600
//
//  Card-Styling: bgSurface + 0.5pt separator-Border (Overlay) +
//  clipShape RoundedRectangle(14). Kein inneres Padding — die
//  Rows bringen ihr eigenes Padding mit.
//

import SwiftUI

struct CollapsibleSection<Content: View>: View {
    let titel: String
    let summary: String?
    let persistKey: String?
    let defaultOffen: Bool
    /// Optional externer Status. Wenn gesetzt, überschreibt er den
    /// lokalen @State — die Parent-View steuert den Open-State,
    /// z.B. um via Router ein Sprungziel zu öffnen.
    let istOffenExtern: Bool?
    /// Callback bei Toggle-Tap. Muss gesetzt werden, wenn
    /// `istOffenExtern` verwendet wird, sonst geht der Tap ins
    /// Leere. Ohne Binding wird der interne State gekippt.
    let onToggle: ((Bool) -> Void)?
    @ViewBuilder let content: () -> Content

    @State private var lokalOffen: Bool

    init(
        titel: String,
        summary: String? = nil,
        count: Int? = nil,
        persistKey: String? = nil,
        defaultOffen: Bool = false,
        istOffenExtern: Bool? = nil,
        onToggle: ((Bool) -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.titel = titel
        // count wird im neuen Layout (UI-Fix-2a) nicht mehr
        // gerendert — die Row-Anzahl zeigt sich in der Card.
        // Der Init-Parameter bleibt erhalten für Kompatibilität.
        _ = count
        self.summary = summary
        self.persistKey = persistKey
        self.defaultOffen = defaultOffen
        self.istOffenExtern = istOffenExtern
        self.onToggle = onToggle
        let initial: Bool
        if let k = persistKey, UserDefaults.standard.object(forKey: k) != nil {
            initial = UserDefaults.standard.bool(forKey: k)
        } else {
            initial = defaultOffen
        }
        _lokalOffen = State(initialValue: initial)
        self.content = content
    }

    /// Effektiver Open-Status: externer Override (wenn vorhanden)
    /// schlägt internen State.
    private var effektivOffen: Bool {
        istOffenExtern ?? lokalOffen
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerButton
            if effektivOffen {
                card
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
        .animation(.easeOut(duration: 0.2), value: effektivOffen)
    }

    // MARK: - Header-Button (auf bgApp, kein Card)

    private var headerButton: some View {
        Button {
            toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: effektivOffen ? "chevron.down" : "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignTokens.textTertiary)
                Text(titel)
                    .appFont(AppFont.uppercaseLabel())
                    .foregroundStyle(DesignTokens.textSecondary)
                Spacer(minLength: 8)
                if let summary {
                    Text(summary)
                        .appFont(AppFont.monoBetrag17())
                        .foregroundStyle(DesignTokens.text)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Card (nur wenn offen)

    private var card: some View {
        VStack(spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.bgSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DesignTokens.separator, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Toggle

    private func toggle() {
        let neu = !effektivOffen
        if let cb = onToggle {
            cb(neu)
        } else {
            lokalOffen = neu
        }
        // persistKey schreibt unabhängig vom Modus, damit Defaults
        // beim nächsten App-Start konsistent bleiben.
        if let k = persistKey {
            UserDefaults.standard.set(neu, forKey: k)
        }
    }
}
