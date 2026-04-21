//
//  KeyboardFertigToolbar.swift
//  NebenkostenApp — UI/Components
//
//  Einheitlicher Keyboard-Toolbar mit „Fertig"-Button fuer alle
//  Sheets mit numerischer Eingabe (decimalPad / numberPad). Ohne
//  diesen Toolbar hat der User auf der deutschen Tastatur keinen
//  sichtbaren Weg, das Keyboard zu schliessen, ohne „Speichern"
//  zu tippen.
//
//  Anwendung:
//      NavigationStack { Form { ... } }.keyboardFertigButton()
//
//  Der Toolbar wird im `.keyboard`-Placement platziert — iOS
//  zeigt ihn ueber dem aufgeklappten Keyboard unabhaengig davon,
//  in welchem TextField gerade getippt wird.
//

import SwiftUI
import UIKit

private struct KeyboardFertigToolbar: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
                .foregroundStyle(DesignTokens.accent)
                .accessibilityLabel("Tastatur schliessen")
            }
        }
    }
}

extension View {
    /// Haengt einen Keyboard-Toolbar mit „Fertig"-Button an die
    /// View. Auf jedem Sheet mit decimalPad-/numberPad-Eingaben
    /// verwenden.
    func keyboardFertigButton() -> some View {
        modifier(KeyboardFertigToolbar())
    }
}
