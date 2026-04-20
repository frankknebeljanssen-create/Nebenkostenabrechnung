//
//  PIISchwaerzung.swift
//  NebenkostenApp — Services
//
//  Platzhalter — die echte Schwärzungs-Logik (Adressen, Telefon,
//  E-Mail, IBAN, Namen aus Store) kommt in Task 1.2-C5.
//  Dieser Stub reicht den Text unverändert durch.
//

import Foundation

/// Kontext-Daten für die Schwärzung: Mieter- und Vermieter-Namen
/// aus dem laufenden Daten-Store, damit Eigennamen spezifisch
/// geschwärzt werden können. In C3 leer.
struct PIIKontext: Sendable {
    var mieterNamen: [String] = []
    var vermieterName: String?

    static let leer = PIIKontext()
}

enum PIISchwaerzung {
    /// Platzhalter: Text unverändert durchreichen.
    static func apply(text: String, kontext: PIIKontext = .leer) -> String {
        text
    }
}
