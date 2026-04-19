//
//  OnboardingStep.swift
//  NebenkostenApp — UI/Onboarding
//

import Foundation

enum OnboardingStep: Int, CaseIterable, Sendable {
    case willkommen
    case datenschutz
    case avv
    case userStammdaten
    case fertig

    var vorherige: OnboardingStep? { Self(rawValue: rawValue - 1) }
    var naechste:  OnboardingStep? { Self(rawValue: rawValue + 1) }

    var fortschritt: Double {
        guard OnboardingStep.allCases.count > 1 else { return 1 }
        return Double(rawValue) / Double(OnboardingStep.allCases.count - 1)
    }
}
