//
//  PrintService.swift
//  NebenkostenApp — Services
//
//  Duenner Wrapper um `UIPrintInteractionController`. Rendert die
//  Abrechnung als PDF und praesentiert das System-Druck-Sheet. Kein
//  SwiftUI-Sheet — UIKit praesentiert den Dialog selbst ueber das
//  aktive Window, wir rufen ihn aus einem Button-Handler auf.
//

import Foundation
import UIKit

@MainActor
enum PrintService {

    enum PrintFehler: Error, LocalizedError {
        case nichtVerfuegbar
        case generierung(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .nichtVerfuegbar:
                return "Drucken ist auf diesem Gerät nicht verfügbar."
            case .generierung(let u):
                return "PDF-Erzeugung fehlgeschlagen: \(u.localizedDescription)"
            }
        }
    }

    /// Wahr, wenn iOS ueberhaupt drucken kann. Simulator: false.
    /// Einige iPads/iPhones mit restriktiven Unternehmens-Profilen
    /// koennen false liefern — der Call-Site disabled dann den Button.
    static var kannDrucken: Bool {
        UIPrintInteractionController.isPrintingAvailable
    }

    /// Generiert die Abrechnung als PDF und oeffnet das System-
    /// Druck-Sheet. Wirft `PrintFehler.generierung` wenn der PDF-
    /// Renderer scheitert; `PrintFehler.nichtVerfuegbar` wenn das
    /// Geraet nicht drucken kann. Das Sheet laeuft system-modal —
    /// der Funktionsaufruf kehrt nach dem present() zurueck; wer
    /// auf das User-Ergebnis reagieren will, kann das Completion-
    /// Handler-Pattern nachziehen.
    static func druckeAbrechnung(
        abrechnung: Mieterabrechnung,
        immobilie: Immobilie,
        periode: Abrechnungsperiode,
        user: AppUser?
    ) async throws {
        guard kannDrucken else {
            throw PrintFehler.nichtVerfuegbar
        }
        let kontext = PDFAbrechnungsKontext.baue(
            abrechnung: abrechnung,
            immobilie: immobilie,
            user: user,
            periode: periode
        )
        let dateiname = PDFAbrechnungsKontext.vorschlagDateiname(
            abrechnung: abrechnung,
            periode: periode
        )
        let data: Data
        do {
            data = try await PDFGenerator.generiereAbrechnungsPDF(
                context: kontext
            )
        } catch {
            throw PrintFehler.generierung(underlying: error)
        }

        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.jobName = dateiname
        info.outputType = .general
        info.orientation = .portrait
        controller.printInfo = info
        controller.printingItem = data
        controller.present(animated: true)
    }
}
