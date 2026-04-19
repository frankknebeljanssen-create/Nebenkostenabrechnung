//
//  KostenartenListenZiel.swift
//  NebenkostenApp — UI/Kostenart
//
//  Navigation-Destination-Wrapper (Immobilie als Hashable via PersistentModel).
//  Explizit getrennt von direkter Immobilie.self-Destination, damit spätere
//  Routes (Mieter, Rechnungen) unterscheidbar bleiben.
//

import Foundation

struct KostenartenListenZiel: Hashable {
    let immobilie: Immobilie
}
