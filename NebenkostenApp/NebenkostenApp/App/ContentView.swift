//
//  ContentView.swift
//  NebenkostenApp — App
//
//  Zweistufiger Einstieg:
//    1. ~1 s `SplashView` (Icon + Version/Build).
//    2. Gate-Logik: ohne AppUser → Onboarding, sonst AppShell.
//
//  Der Splash ist rein zeitgesteuert und nicht interaktiv — der
//  Wechsel passiert via `.task` + `try await Task.sleep(...)`.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var users: [AppUser]
    @State private var splashVorbei = false

    var body: some View {
        ZStack {
            if splashVorbei {
                hauptinhalt
                    .transition(.opacity)
            } else {
                SplashView()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: splashVorbei)
        .task {
            // Kurzer Splash, dann Übergang zum Hauptinhalt. Bei
            // erneutem Re-Render (z.B. Scene-Rejoin) bleibt der
            // Wert `true` — kein doppelter Splash.
            guard !splashVorbei else { return }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            splashVorbei = true
        }
    }

    @ViewBuilder
    private var hauptinhalt: some View {
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
