import SwiftUI
import VisionKit
import UIKit

/// SwiftUI-Bridge zu Apples `VNDocumentCameraViewController`.
///
/// Liefert Multi-Page-Scanning mit:
///   • Automatischer Rand-Erkennung (DIN-A4)
///   • Perspektiv-Korrektur (entzerrtes Bild)
///   • Auto-Auslöser bei stabilem Frame
///   • Seitenweisem Retake / Crop
///
/// Verwendung:
/// ```swift
/// .fullScreenCover(isPresented: $showScanner) {
///     DocumentScannerView { newImages in
///         scannedImages.append(contentsOf: newImages)
///     }
///     .ignoresSafeArea()
/// }
/// ```
///
/// **Wichtig:** Die Callback `onComplete` bekommt die NEU gescannten Bilder
/// als Array. Der Aufrufer entscheidet, ob diese ANGEFÜGT oder ERSETZT
/// werden — wir liefern hier nur die frische Scan-Session.
struct DocumentScannerView: UIViewControllerRepresentable {
    /// Wird mit allen neu gescannten Seiten dieser Session aufgerufen.
    var onComplete: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScannerView

        init(_ parent: DocumentScannerView) {
            self.parent = parent
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for i in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: i))
            }
            controller.dismiss(animated: true) {
                self.parent.onComplete(images)
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            print("DocumentScanner Fehler: \(error.localizedDescription)")
            controller.dismiss(animated: true)
        }
    }
}
