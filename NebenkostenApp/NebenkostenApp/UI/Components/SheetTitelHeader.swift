//
//  SheetTitelHeader.swift
//  NebenkostenApp — UI/Components
//
//  Gemeinsame Titel-Zeile fuer alle Edit-Sheets. Problem vorher:
//  In der System-Navigationbar hatten „Abbrechen" (links) und
//  „Speichern" (rechts) gleichzeitig Platz — der Titel in der
//  Mitte wurde abgeschnitten ("Wohneinheit bearbe…").
//
//  Loesung (Option A aus dem Device-Feedback): NavigationTitle
//  leer lassen, Titel in den Content ziehen. Der `.sheetTitelHeader
//  ("…")`-Modifier haengt oben eine linksbuendige, grosse Titel-
//  Zeile an den Content an und setzt gleichzeitig
//  `navigationTitle("")` + inline-Display-Mode. Die Toolbar-
//  Buttons (Abbrechen / Speichern) haben dann die volle
//  System-NavBar-Breite zur Verfuegung.
//

import SwiftUI

struct SheetTitelHeader: ViewModifier {
    let titel: String

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(titel)
                    .appFont(AppFont.Basis.displayTitle())
                    .foregroundStyle(DesignTokens.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 6)

            content
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension View {
    /// Ersetzt den abgeschnittenen System-NavigationTitle in
    /// Edit-Sheets durch einen linksbuendigen Content-Titel. Nutzung:
    ///
    /// ```swift
    /// NavigationStack {
    ///     Form { … }
    ///         .sheetTitelHeader("Objekt bearbeiten")
    ///         .toolbar { … }
    /// }
    /// ```
    ///
    /// Die Toolbar-Buttons (Abbrechen / Speichern) bleiben in der
    /// System-NavBar unveraendert — sie haben jetzt mehr Platz.
    func sheetTitelHeader(_ titel: String) -> some View {
        modifier(SheetTitelHeader(titel: titel))
    }
}
