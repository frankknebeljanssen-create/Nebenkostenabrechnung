//
//  OnboardingFlow.swift
//  NebenkostenApp — UI/Onboarding
//
//  Dispatcher-View: zeigt je nach controller.schritt einen der fünf
//  Onboarding-Screens. State-basiertes Switching (statt
//  NavigationStack-Push-Pop), Back-Buttons sind in den Screens selbst.
//

import SwiftUI
import SwiftData

struct OnboardingFlow: View {
    @Environment(\.modelContext) private var modelContext
    @State private var controller = OnboardingController()

    var body: some View {
        NavigationStack {
            inhalt
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: controller.schritt)
                .safeAreaInset(edge: .top) {
                    fortschrittsleiste
                }
        }
    }

    @ViewBuilder
    private var inhalt: some View {
        switch controller.schritt {
        case .willkommen:
            WillkommenView(controller: controller)
        case .datenschutz:
            DatenschutzView(controller: controller)
        case .avv:
            AvvView(controller: controller)
        case .userStammdaten:
            UserStammdatenView(controller: controller)
        case .fertig:
            FertigView(controller: controller, abschluss: {
                controller.anlegen(in: modelContext)
            })
        }
    }

    private var fortschrittsleiste: some View {
        ProgressView(value: controller.schritt.fortschritt)
            .tint(.accentColor)
            .padding(.horizontal)
            .padding(.top, 8)
            .background(.bar)
    }
}
