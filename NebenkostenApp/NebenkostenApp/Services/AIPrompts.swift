//
//  AIPrompts.swift
//  NebenkostenApp — Services
//
//  Typ-spezifische Prompts für die AI-Extraktion. Platzhalter-
//  Implementation — wird in Task 1.2-C4 mit den vier dedizierten
//  Prompts (Gas, Wasser, Bescheid, Handwerkerbeleg) + Fallback
//  befüllt.
//

import Foundation

enum AIPrompts {
    /// Wählt den Prompt für einen Dokumenttyp. Platzhalter bis C4.
    static func fuer(typ: Dokumenttyp) -> String {
        "[Prompt-Stub für \(typ.rawValue)]"
    }
}
