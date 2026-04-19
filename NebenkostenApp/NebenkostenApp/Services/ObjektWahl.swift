//
//  ObjektWahl.swift
//  NebenkostenApp — Services
//
//  Merkt sich, welches Objekt gerade "aktiv" ist — pro Gerät in
//  UserDefaults. CloudKit-Sync ist hier bewusst NICHT aktiv: jedes
//  Gerät kann seinen eigenen Standard-Tab haben.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class ObjektWahl {

    private let schluessel = "aktivesObjektID"

    /// `nil` = noch nicht gewählt (UI nimmt dann das erste Objekt aus der DB).
    private(set) var aktiveID: UUID?

    init() {
        if let raw = UserDefaults.standard.string(forKey: schluessel) {
            aktiveID = UUID(uuidString: raw)
        }
    }

    func setze(_ id: UUID) {
        aktiveID = id
        UserDefaults.standard.set(id.uuidString, forKey: schluessel)
    }

    /// Wählt ein Fallback-Objekt aus, wenn die bisher gemerkte ID nicht mehr
    /// existiert (z.B. gelöscht oder auf diesem Gerät noch nicht geseedet).
    func bereinigeFallsUngueltig(verfuegbareIDs: Set<UUID>) {
        if let id = aktiveID, !verfuegbareIDs.contains(id) {
            aktiveID = nil
            UserDefaults.standard.removeObject(forKey: schluessel)
        }
    }
}
