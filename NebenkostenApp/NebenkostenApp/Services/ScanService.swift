//
//  ScanService.swift
//  NebenkostenApp — Services
//
//  Zentraler Einstiegspunkt für die drei Capture-Quellen (Kamera /
//  Mediathek / Datei). Der Service selbst hat keine Speicher-Logik —
//  die bleibt beim DokumentAblageService. ScanService liefert nur
//  fertige SwiftUI-Wrapper-Views bzw. Modifier.
//
//  Design-Entscheidung: Factory-Pattern statt eine dicke Klasse. Die
//  drei Capture-Mechanismen haben unterschiedliche Integration-
//  Modelle (ViewController-Wrapper, PhotosPicker-View,
//  fileImporter-Modifier), und ein einheitliches
//  "gibt eine View zurück" würde die Typen unnötig uniformieren.
//

import SwiftUI
import UIKit

@MainActor
enum ScanService {

    /// VNDocumentCameraViewController-Wrapper für den Kamera-Scan.
    /// Multi-Page ist standardmäßig möglich.
    static func kameraScanner(
        onFertig: @escaping ([UIImage]) -> Void,
        onAbbruch: @escaping () -> Void = {},
        onFehler: @escaping (Error) -> Void = { _ in }
    ) -> DokumentScannerView {
        DokumentScannerView(
            onFertig: onFertig,
            onAbbruch: onAbbruch,
            onFehler: onFehler
        )
    }

    /// PhotosPicker als Button mit beliebigem Label. Liefert bis zu
    /// `maxAuswahl` Bilder als UIImage-Array.
    static func mediathekButton<Label: View>(
        maxAuswahl: Int = 10,
        onFertig: @escaping ([UIImage]) -> Void,
        onFehler: @escaping (Error) -> Void = { _ in },
        @ViewBuilder label: @escaping () -> Label
    ) -> GalerieImportButton<Label> {
        GalerieImportButton(
            maxAuswahl: maxAuswahl,
            onFertig: onFertig,
            onFehler: onFehler,
            label: label
        )
    }

    /// Statische Prüfung, ob der Apple-Dokument-Scanner auf diesem
    /// Gerät verfügbar ist (Simulator hat keinen).
    static var istKameraVerfuegbar: Bool {
        DokumentScannerView.istVerfuegbar
    }
}

// MARK: - View-Modifier für Datei-Import

extension View {
    /// ScanService-Entry-Point für Datei-Import (PDF / Bilder).
    /// Interner Wrapper um `.fileImporter` — identisch zur bisherigen
    /// `.dateiImport(…)`-API, aber hier unter dem ScanService-Namen
    /// einsortiert, damit alle Entry-Points nebeneinander auffindbar
    /// sind.
    func scanDateiImporter(
        isPresented: Binding<Bool>,
        onFertig: @escaping (DateiImportErgebnis) -> Void,
        onFehler: @escaping (Error) -> Void = { _ in }
    ) -> some View {
        self.dateiImport(
            isPresented: isPresented,
            onFertig: onFertig,
            onFehler: onFehler
        )
    }
}
