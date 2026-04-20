//
//  DokumentScannerView.swift
//  NebenkostenApp — UI/Scan
//
//  SwiftUI-Wrapper um VisionKit's VNDocumentCameraViewController.
//  Apple macht Kantenerkennung und Perspektivkorrektur automatisch —
//  wir reichen die Multi-Page-Scans als UIImage-Array nach oben.
//

import SwiftUI
import VisionKit

struct DokumentScannerView: UIViewControllerRepresentable {
    typealias FertigHandler = ([UIImage]) -> Void
    typealias AbbruchHandler = () -> Void
    typealias FehlerHandler = (Error) -> Void

    let onFertig: FertigHandler
    let onAbbruch: AbbruchHandler
    let onFehler: FehlerHandler

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(
        _ uiViewController: VNDocumentCameraViewController,
        context: Context
    ) {}

    func makeCoordinator() -> Koordinator {
        Koordinator(onFertig: onFertig, onAbbruch: onAbbruch, onFehler: onFehler)
    }

    // MARK: - Coordinator

    @MainActor
    final class Koordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onFertig: FertigHandler
        let onAbbruch: AbbruchHandler
        let onFehler: FehlerHandler

        init(
            onFertig: @escaping FertigHandler,
            onAbbruch: @escaping AbbruchHandler,
            onFehler: @escaping FehlerHandler
        ) {
            self.onFertig = onFertig
            self.onAbbruch = onAbbruch
            self.onFehler = onFehler
        }

        nonisolated func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            var bilder: [UIImage] = []
            for i in 0..<scan.pageCount {
                bilder.append(scan.imageOfPage(at: i))
            }
            let finale = bilder
            Task { @MainActor in
                self.onFertig(finale)
            }
        }

        nonisolated func documentCameraViewControllerDidCancel(
            _ controller: VNDocumentCameraViewController
        ) {
            Task { @MainActor in
                self.onAbbruch()
            }
        }

        nonisolated func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            let fehler = error
            Task { @MainActor in
                self.onFehler(fehler)
            }
        }
    }
}

// MARK: - Verfügbarkeits-Check

extension DokumentScannerView {
    /// Dokument-Scanner ist auf Simulator und alten Geräten ohne
    /// brauchbare Kamera nicht verfügbar. Sollte vor dem Präsentieren
    /// geprüft werden.
    @MainActor
    static var istVerfuegbar: Bool {
        VNDocumentCameraViewController.isSupported
    }
}
