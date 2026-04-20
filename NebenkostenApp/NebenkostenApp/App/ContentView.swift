//
//  ContentView.swift
//  NebenkostenApp — App
//
//  Gate-View: ohne AppUser → Onboarding, sonst die Root-TabView.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var users: [AppUser]

    var body: some View {
        if users.isEmpty {
            OnboardingFlow()
        } else {
            // Neue App-Shell (Task UI-0). Phase-0-RootTabView bleibt
            // über das EinstellungenSheet → Debug-Zugriff erreichbar.
            AppShell()
        }
    }
}

#Preview {
    ContentView()
}
