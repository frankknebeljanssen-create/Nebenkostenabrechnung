//
//  ZifferScannerView.swift
//  NebenkostenApp — UI/Scan
//
//  VisionKit-Wrapper fuer die Zaehlerstand-Erfassung per Kamera.
//  Startet einen `DataScannerViewController` im Text-Modus
//  (`.text`) mit Live-Hervorhebung — der User tippt auf die
//  erkannten Ziffern am Zaehler, der transcript-String wird per
//  Callback nach oben gereicht und der Scanner schliesst sich.
//
//  Simulator-Verhalten: `DataScannerViewController` ist nur auf
//  echten Geraeten verfuegbar. Call-Sites pruefen
//  `ZifferScannerView.istVerfuegbar` vor dem Praesentieren.
//

import SwiftUI
import VisionKit

struct ZifferScannerView: UIViewControllerRepresentable {
    /// Wird mit dem erkannten Rohtext aufgerufen (z.B. "12345,678").
    /// Der Aufrufer entscheidet, ob er weiter parst — wir reichen
    /// nur den transcript-String durch.
    let onErkannt: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    /// `true`, wenn das Geraet den DataScanner ueberhaupt unterstuetzt
    /// UND die Verfuegbarkeit aktuell gegeben ist (Kamera-Permission
    /// vorhanden, kein Hardware-Konflikt). Simulator: false.
    static var istVerfuegbar: Bool {
        DataScannerViewController.isSupported
            && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text(languages: ["de-DE"])],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(
        _ uiViewController: DataScannerViewController,
        context: Context
    ) {
        // stateless — nichts zu synchronisieren
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onErkannt: onErkannt, dismiss: dismiss)
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onErkannt: (String) -> Void
        let dismiss: DismissAction

        init(onErkannt: @escaping (String) -> Void, dismiss: DismissAction) {
            self.onErkannt = onErkannt
            self.dismiss = dismiss
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didTapOn item: RecognizedItem
        ) {
            if case .text(let text) = item {
                onErkannt(text.transcript)
                dismiss()
            }
        }
    }
}
