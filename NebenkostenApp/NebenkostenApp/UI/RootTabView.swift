//
//  RootTabView.swift
//  NebenkostenApp — UI
//
//  Root-Tab-Bar mit den vier Hauptbereichen der App.
//  Inhalte sind Platzhalter (Task 0.10) und werden in Folge-Tasks
//  mit echten Views gefüllt.
//

import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            ObjektTabRoot()
                .tabItem { Label("Objekt", systemImage: "house") }

            DokumenteTabRoot()
                .tabItem { Label("Dokumente", systemImage: "doc.text") }

            AbrechnungenTabRoot()
                .tabItem { Label("Abrechnungen", systemImage: "doc.text.magnifyingglass") }

            EinstellungenTabRoot()
                .tabItem { Label("Einstellungen", systemImage: "gearshape") }
        }
    }
}

#Preview {
    RootTabView()
}
