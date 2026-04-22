//
//  CompletionFarbe.swift
//  NebenkostenApp — Core/Design
//
//  Farbzuordnung fuer Completion-Anzeigen (Home-Ring, Kachelansicht-
//  Mini-Balken, Kachel-Icon). Schwellen aus Stufe-2-Spec vom Home-
//  Screen-Rebuild:
//
//    100     → statusOk   (gruen)
//    80..99  → gelb       (Standard-System-Gelb, kein Token im Handoff)
//    50..79  → statusWarn (orange)
//    0..49   → statusError (rot)
//
//  100 % ist bewusst exakter Vergleich: 99 % darf nicht schon grun
//  werden, damit der "Abrechnung erstellen"-CTA synchron zum
//  Farbwechsel erscheint.
//

import SwiftUI

enum CompletionFarbe {

    static func fuer(prozent: Int) -> Color {
        switch prozent {
        case 100:      return DesignTokens.statusOk
        case 80..<100: return .yellow
        case 50..<80:  return DesignTokens.statusWarn
        default:       return DesignTokens.statusError
        }
    }
}
