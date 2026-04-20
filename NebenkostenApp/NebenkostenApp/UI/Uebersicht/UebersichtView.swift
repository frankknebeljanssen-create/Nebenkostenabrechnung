//
//  UebersichtView.swift
//  NebenkostenApp — UI/Uebersicht
//
//  Router zwischen Objekt- und Einheit-Scope-Ansicht. Keine eigene
//  Logik — delegiert je nach ScopeManager.current.
//

import SwiftUI

struct UebersichtView: View {
    @Environment(ScopeManager.self) private var scope

    var body: some View {
        switch scope.current {
        case .objekt:
            UebersichtObjektView()
        case .einheit(let id):
            UebersichtEinheitView(einheitId: id)
        }
    }
}
