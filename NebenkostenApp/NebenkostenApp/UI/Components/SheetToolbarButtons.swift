//
//  SheetToolbarButtons.swift
//  NebenkostenApp — UI/Components
//
//  Einheitliches Kontrast-Regime fuer Sheet-Toolbar-Buttons.
//  Regel (Task-Brief, Device-Review):
//    - Abbrechen / Cancel: `textSecondary` — kein Custom-Tint,
//      kein Accent-Blau. Liest sich auf Form-Background (system-
//      GroupedBackground) und bgSheet (bgApp) gleichermassen gut.
//    - Primaere Aktion (Speichern, Fertig, Uebernehmen): weisser
//      Text auf Accent-Hintergrund (#3A5578). `.buttonStyle
//      (.borderedProminent)` + expliziter `.tint(accent)` +
//      `.foregroundStyle(.white)` — keine Regression, egal
//      welches Container-Scheme.
//
//  Bewusst kein eigener `ButtonStyle`-Typ, damit man die Buttons
//  weiterhin trivial in `ToolbarItem` packen und das `disabled`-
//  State setzen kann. Zwei View-Builder reichen.
//

import SwiftUI

enum SheetToolbar {

    /// Abbrechen-Button mit garantiertem Kontrast. Default-Titel
    /// „Abbrechen", ueberschreibbar fuer Spezialfaelle („Schliessen").
    /// `.fixedSize` verhindert Truncation durch enge Toolbar-
    /// Container.
    @MainActor @ViewBuilder
    static func abbrechen(
        titel: String = "Abbrechen",
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(titel)
                .appFont(AppFont.bodyMedium())
                .foregroundStyle(DesignTokens.textSecondary)
                .fixedSize(horizontal: true, vertical: false)
        }
        .accessibilityLabel(titel)
    }

    /// Primaere Aktion (Speichern, Fertig, Uebernehmen). Weiss auf
    /// Accent-Pill. `istAktiv == false` rendert die Pill in dezentem
    /// Grau, damit klar ist, warum der Button nicht tappt — das
    /// system-default „graue Schrift" auf Accent-Tint waere sonst
    /// wieder der naechste Kontrast-Bug.
    ///
    /// Horizontal-Padding 16 pt + `.fixedSize(horizontal:)` sichern,
    /// dass der Text auch in engen Toolbars nicht als „Speic…"
    /// abgeschnitten wird.
    @MainActor @ViewBuilder
    static func primaer(
        titel: String,
        istAktiv: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(titel)
                .appFont(AppFont.bodySemi())
                .foregroundStyle(istAktiv ? Color.white : DesignTokens.textTertiary)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(
                        istAktiv
                            ? DesignTokens.accent
                            : DesignTokens.bgAppCompact
                    )
                )
        }
        .buttonStyle(.plain)
        .disabled(!istAktiv)
        .accessibilityLabel(titel)
    }
}
