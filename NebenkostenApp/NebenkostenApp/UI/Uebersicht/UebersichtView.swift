//
//  UebersichtView.swift
//  NebenkostenApp — UI/Uebersicht
//
//  Einstiegs-Tab der App. Nach dem Home-Refactor ist die View ein
//  dünner Wrapper um die neue `HomeView` — Context-First-Layout
//  mit Objekt-Card, Einheit-Card, Status-Card + Empty-State.
//
//  Die alte Scope-Router-Logik (`.objekt` → UebersichtObjektView,
//  `.einheit` → UebersichtEinheitView) ist entfallen: HomeView
//  zeigt BEIDE Kontexte zeitgleich. Die beiden alten Views
//  bleiben im Repo (ungenutzt), können für Folge-Tasks als
//  Vorlage dienen.
//

import SwiftUI

struct UebersichtView: View {
    var body: some View {
        HomeView()
    }
}
