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
            RootTabView()
        }
    }
}

#Preview {
    ContentView()
}
